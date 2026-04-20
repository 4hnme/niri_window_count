# niri_window_count

A simple window count indicator for the [niri](https://github.com/niri-wm/niri) scrollable tiling compositor.

It tracks how many windows you have open on your current workspace and shows your current position among them.

### Build

You'll need the [Odin](https://odin-lang.org/) compiler to build this.

```bash
odin build .
```

### Usage

It reads from the niri IPC socket and prints the relevant information to stdout. You can use this in your status bar of choice. Here's a sample [Waybar](https://github.com/Alexays/Waybar) widget:

```json
"custom/niri-window-count": {
  "exec": "path/to/niri_window_count",
  "format": "{text}"
}
```


### Formatting

You can customize the output format by passing defines during build:

- `OVERVIEW_FMT`: Shown when niri overview is open.
- `SIMPLE_FMT`: Shown when there is only one window.
- `FULL_FMT`: Shown when there are multiple windows (current/total).

Example:

```bash
odin build . -define:SIMPLE_FMT="[ %d ]"
```
