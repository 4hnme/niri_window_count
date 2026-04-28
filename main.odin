package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"
import niri "niri_ipc"

// TODO: make them more easily customizable?
OVERVIEW_FMT :: #config(OVERVIEW_FMT, "[ OwO ]")
SIMPLE_FMT   :: #config(SIMPLE_FMT, "[  %d  ]")
FULL_FMT     :: #config(FULL_FMT, "[% 2d/%- 2d]")

// NOTE: do we really need `workspace_id` and `focused_window_id`?
State :: struct {
    sb: strings.Builder,
    stream_sock: posix.FD,
    overview: bool,
    workspace_id: int,
    workspaces: [dynamic]niri.Workspace,
    focused_window_id: int,
    windows: [dynamic]niri.Window,
    last_current: int,
    last_on_current_workspace: int,
}

update_state :: proc(s: ^State, msg: ^niri.Msg) {
    switch data in msg {
    case niri.OverviewOpenedOrClosed:
        s.overview = data.is_open

    case niri.WorkspaceActivated:
        s.workspace_id = data.id

    case niri.WindowFocusChanged:
        s.focused_window_id = data.id

    case niri.WindowClosed:
        id := data.id
        for &window, i in s.windows {
            if window.id == id {
                unordered_remove(&s.windows, i)
                break
            }
        }

    case niri.WindowOpenedOrChanged:
        new_window := data.window
        if new_window.is_focused {
            s.focused_window_id = new_window.id
        }
        found := false
        for &window in s.windows {
            if window.id == new_window.id {
                window = new_window
                found = true
                break
            }
        }
        if !found do append(&s.windows, new_window)

    case niri.WindowsChanged:
        clear(&s.windows)
        for window in data.windows {
            append(&s.windows, window)
        }
        delete(data.windows)

    case niri.WindowLayoutsChanged:
        for change in data.changes {
            id := change[0].(int)
            layout := change[1].(niri.Layout)
            for &window in s.windows {
                if window.id == id {
                    window.layout = layout
                }
            }
        }
        delete(data.changes)

    case niri.WorkspacesChanged:
        clear(&s.workspaces)
        for workspace in data.workspaces {
            if workspace.is_active {
                s.workspace_id = workspace.id
                s.focused_window_id = workspace.active_window_id
            }
            append(&s.workspaces, workspace)
        }
        delete(data.workspaces)

    case niri.FocusedWindow, niri.Windows:
        // don't do anything here, these types are for requests only.
    }

    if s.overview {
        // NOTE: most of the time, the count on the overview is borked. "maybe" i could figure out how to properly handle this,
        // buuut i don't spend even a percent of my time using niri in overview, so this doesn't bother me at all.
        fmt.println(OVERVIEW_FMT)
    } else {
        focused: niri.Window
        on_current_workspace := 0
        for w in s.windows {
            if w.workspace_id == s.workspace_id {
                on_current_workspace += 1
            }
            if w.id == s.focused_window_id {
                focused = w
            }
        }
        // NOTE: maybe handle floating windows seperately? like excluding them from total count, or add another optional info: `[ 1/3 ] (2)` or `[ 1/3+2 ]`
        if on_current_workspace == 1 || on_current_workspace == 0 || focused.is_floating {
            fmt.printfln(SIMPLE_FMT, on_current_workspace)
        } else if focused.workspace_id == s.workspace_id {
            current := focused.layout.pos_in_scrolling_layout.x + \
                       focused.layout.pos_in_scrolling_layout.y - 1
            // if current != s.last_current || on_current_workspace != s.last_on_current_workspace {
                fmt.printfln(FULL_FMT, current, on_current_workspace)
            // }
            s.last_current = current
            s.last_on_current_workspace = on_current_workspace
        }
        // else we don't print anything as the state is not set correctly (i.e. active workspace is updated, but focused window is not).
        // this happens because we process events sequentially with no option do this in bulk.
    }

}

create_socket :: proc() -> posix.FD {
    socket_path := os.get_env("NIRI_SOCKET", context.allocator)

    sockfd := posix.socket(.UNIX, .STREAM)

    addr: posix.sockaddr_un
    copy(addr.sun_path[:], socket_path[:])
    addr.sun_family = .UNIX

    err := posix.connect(sockfd, (^posix.sockaddr)(&addr), size_of(addr))
    if err != .OK {
        fmt.eprintln("connect error")
        os.exit(1)
    }

    return sockfd
}

state_init :: proc() -> State {
    state: State
    state.sb = strings.builder_make()

    state.stream_sock = create_socket()
    fmt.sbprintf(&state.sb, "\"%s\"\n", "EventStream")
    posix.write(state.stream_sock, raw_data(state.sb.buf), len(state.sb.buf))

    return state
}

// will this even get called? lmao
state_destroy :: proc(s: ^State) {
    strings.builder_destroy(&s.sb)
    posix.close(s.stream_sock)
}

// the only function used to test parsing. i probably need to create a full set of tests, but i can't be bothered to do so
// main :: proc() {
//     data, _ := os.read_entire_file(
//         "./sample_responses/window_layouts_changed.json",
//         context.allocator)
//     str := string(data)

//     obj, pok := niri.parse_event(str)
//     fmt.println(obj, pok)
// }

main :: proc() {
    state := state_init()
    defer state_destroy(&state)

    for {
        strings.builder_reset(&state.sb)
        byte: u8
        for byte != '\n' {
            posix.recv(state.stream_sock, &byte, 1, posix.Msg_Flags{})
            strings.write_byte(&state.sb, byte)
        }
        str := string(state.sb.buf[:])
        event, pok := niri.parse_event(str)

        if pok {
            if event == nil {
                fmt.eprintfln("Something went wrong, couldn't parse:\n\t%v\nObject is nil, but the error is %v\n", str, pok)
            }
            update_state(&state, &event)
        }
    }
}
