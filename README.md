# zpui

A Zig UI toolkit.

## Status

`zpui` is being pushed back toward GPUI's native-platform model:

- `testing.TestPlatform` for deterministic tests only.
- no GLFW or SDL wrapper is planned for the real platform path.
- native bindings are now pinned for the next backend slice:
  `zig-wayland`, `zigwin32` (vendored), `zig-objc`, `vulkan-zig`, and `Vulkan-Headers`.

It also now has the first GPUI-style application port slice:

- `Application`, `App`, and `Window` on the public surface
- typed entity storage
- typed `AppContext(T)` helpers for entity-backed code
- application bootstrap state
- runtime quit/window-state capture
- platform hooks for windows, clipboard, cursor style, and text-system access
- a std-first bootstrap `PlatformTextSystem`

## Install

Use `zig fetch` against a release tag tarball:

```bash
zig fetch --save https://github.com/Addonay/zpui/archive/refs/tags/v0.1.0.tar.gz
```

## Use in `build.zig`

```zig
const dep = b.dependency("zpui", .{
    .target = target,
    .optimize = optimize,
});

const zpui_mod = dep.module("zpui");
```

## Use in source

```zig
const zpui = @import("zpui");
```

## Run

Current runtime status:

```bash
zig build run
```

This currently exits with `error.NativePlatformNotImplemented` until a real native backend lands.

## Docs

- [Porting Plan](docs/PORTING.md)
- [Library Survey](docs/LIBRARIES.md)

## Current Architecture Direction

`zpui` is being shaped as a retained, GPUI-style framework for Zig:

- `Application` and `App` now mirror the GPUI split more closely
- `Window` and `AppContext(T)` are the first higher-level app/view-side primitives
- the internal app runtime still drives the frame loop under that higher-level app state
- `platform.Platform` is the start of the real platform contract
- `testing.TestPlatform` is test support, not a production backend
- `text_system.PlatformTextSystem` is the first text boundary that platform implementations can replace
- the next real platform step is native Wayland/X11, Win32, and Cocoa/Metal backends, not a wrapper library
