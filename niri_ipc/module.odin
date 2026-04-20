package niri_ipc

import "core:encoding/json"
import "core:strings"
import "base:intrinsics"

Layout :: struct {
    pos_in_scrolling_layout: [2]int,
    tile_size: [2]f32,
    window_size: [2]int,
    // tile_pos_in_workspace_view: bool, // <- i don't really know the type of this thing. we could look up `niri-ipc` source code, but you can't pay me enough to read rust source code.
    window_offset_in_tile: [2]f32,
}

Timestamp :: struct {
    secs: int,
    nanos: int,
}

Window :: struct {
    id: int,
    title: string,
    app_id: string,
    pid: int,
    workspace_id: int,
    is_focused: bool,
    is_floating: bool,
    is_urgent: bool,
    layout: Layout,
    focus_timestamp: Timestamp,
}

WindowOpenedOrChanged :: struct {
    window: Window,
}

WindowClosed :: struct {
    id: int,
}

WindowFocusChanged :: struct {
    id: int,
}

// switch workspace
WorkspaceActivated :: struct {
    id: int,
    focused: bool,
}

OverviewOpenedOrClosed :: struct {
    is_open: bool,
}

// not a whole struct, just the data we might need.
Workspace :: struct {
    id: int,
    is_active: bool,
    is_focused: bool,
    active_window_id: int,
}

WorkspacesChanged :: struct {
    workspaces: [dynamic]Workspace,
}

LayoutChange :: [2]union{int, Layout}

WindowLayoutsChanged :: struct {
    changes: [dynamic]LayoutChange
}

WindowsChanged :: struct {
    windows: Windows
}

Windows :: [dynamic]Window

FocusedWindow :: struct {
    window: Window,
}

Msg :: union {
    OverviewOpenedOrClosed,
    WindowOpenedOrChanged,
    WindowFocusChanged,
    WorkspaceActivated,
    WorkspacesChanged,
    WindowLayoutsChanged,
    WindowClosed,
    FocusedWindow,
    // NOTE: there two are not really necessary for my use case, but i'll leave them here nontheless.
    // they are responses, which means they are wrapped inside `"Ok"` object. maybe write a special wrapper for them?
    Windows,
    WindowsChanged,
}

// NOTE: it may be that we could get rid of the switch statement here if we could add json attributes to union members.
// since then, the only way to distinguish them that I found is to manually dispatch them and create anonymous object wrappers before unmarshaling.
parse_event :: proc(msg: string) -> (result: Msg, ok: bool) {
    trimmed := strings.trim(msg, "{\n \":")
    // such a hackjob. needed for those two responses that i don't really need in my program, but i'll leave it here just in case.
    if strings.starts_with(trimmed, "Ok") {
        trimmed = trimmed[2:]
    }
    trimmed = strings.trim(trimmed, "{\n \":")

    switch true {
    case strings.starts_with(trimmed, "OverviewOpenedOrClosed"):
        obj: struct {
            data: OverviewOpenedOrClosed `json:"OverviewOpenedOrClosed"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WindowOpenedOrChanged"):
        obj: struct {
            data: WindowOpenedOrChanged `json:"WindowOpenedOrChanged"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WindowFocusChanged"):
        obj: struct {
            data: WindowFocusChanged `json:"WindowFocusChanged"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WorkspaceActivated"):
        obj: struct {
            data: WorkspaceActivated `json:"WorkspaceActivated"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WorkspacesChanged"):
        obj: struct {
            data: WorkspacesChanged `json:"WorkspacesChanged"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WindowsChanged"):
        obj: struct {
            data: WindowsChanged `json:"WindowsChanged"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WindowLayoutsChanged"):
        obj: struct {
            data: WindowLayoutsChanged `json:"WindowLayoutsChanged"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "WindowClosed"):
        obj: struct {
            data: WindowClosed `json:"WindowClosed"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.data, true

    case strings.starts_with(trimmed, "FocusedWindow"):
        obj: struct {
            ok: struct {
                data: FocusedWindow `json:"FocusedWindow"`
            } `json:"Ok"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.ok.data, true

    case strings.starts_with(trimmed, "Windows"):
        obj: struct {
            ok: struct {
                data: Windows `json:"Windows"`
            } `json:"Ok"`
        }
        err := json.unmarshal(transmute([]u8)msg, &obj)
        if err != nil do return nil, false
        return obj.ok.data, true

    case:
        return nil, false
    }
}
