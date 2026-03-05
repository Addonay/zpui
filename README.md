# zpui

A Zig UI toolkit.

## Status

`zpui` is std-first again:

- `Platform.initHeadless()` for headless tests, bootstrap frames, and command generation.
- no in-tree native windowing dependency is required right now.

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

Headless bootstrap:

```bash
zig build run
```

## Docs

- [Porting Plan](docs/PORTING.md)
- [Library Survey](docs/LIBRARIES.md)

## Current Architecture Direction

`zpui` is being shaped as a retained, GPUI-style framework for Zig:

- `Application` and `App` now mirror the GPUI split more closely
- `Window` and `AppContext(T)` are the first higher-level app/view-side primitives
- `RuntimeApp` still drives the frame loop under that higher-level app state
- `platform.Platform` is the start of the real platform contract
- `text.PlatformTextSystem` is the first text boundary that platform implementations can replace
