# GPUI Porting Plan

`zpui` is intended to become a GPUI-style native application framework for Zig.

The goal is not a line-by-line translation of Rust GPUI internals. The goal is to
port the architecture:

- retained application and view model
- typed entity ownership
- explicit platform abstraction
- strong text pipeline
- GPU-first rendering
- test-only platform support

## Current Mapping

GPUI `Application` / `App`
- `zpui` now has `app.Application` and `app.App` as the start of the higher-level application layer.
- `zpui` now also exposes `Window` and a minimal typed `AppContext(T)` helper to start closing the gap with GPUI's context-driven model.

GPUI entity map / reservations
- `zpui` now has typed `Entity`, `Reservation`, and `EntityStore`.

GPUI platform abstraction
- `zpui` now has the start of a wider platform contract.
- The current backend surface owns event polling, present, window opening/closing, clipboard text, cursor style, and text-system access.
- The only in-tree implementation right now is a test platform, matching GPUI's approach to fake platform support.
- The repo now pins GPUI-style native binding dependencies instead of planning around SDL or GLFW.
- The platform API still needs to grow into displays, IME, menus, timers, and richer window semantics.

GPUI text system
- `zpui` now has a formal `PlatformTextSystem` plus a std-first bootstrap implementation.
- It can shape and measure text conservatively for tests and early porting work.
- It still does not have shaping, font fallback, glyph rasterization, wrapping, or IME-aware text input.

GPUI scene and renderer
- `zpui` already has a retained node graph, layout engine, and draw-command generation.
- It still needs a real GPU renderer and stronger paint/scene abstractions.

## Completed In This Slice

- added typed entity storage with reservations
- added an application/window state layer
- added runtime tracking for quit and resize events
- widened the platform contract to include windows, clipboard, cursor style, and text-system access
- added a formal text-system boundary with a noop/bootstrap implementation
- added a minimal typed app-context surface on top of the entity store
- removed the SDL bootstrap path from the package surface to keep the port std-first
- pinned native platform and renderer bindings for Wayland, Win32, Cocoa/Metal, and Vulkan work

## Near-Term Port Order

1. Move from "single runtime graph" toward window-scoped retained state.
2. Split renderer responsibilities into scene building and GPU submission.
3. Replace bootstrap text measurement with a proper shaping and glyph pipeline.
4. Grow the platform API into displays, timers, IME, menus, and richer window semantics.
5. Add real native platform backends on top of those bindings, starting with Linux Wayland/X11.

## Non-Goals Right Now

- perfect parity with every GPUI subsystem
- multi-backend native windowing from day one
- immediate adoption of external Zig libraries where `std` is sufficient

## Design Rule

Own the `zpui` API and architecture first. External libraries can be used as
backend implementations, not as the public identity of the framework.
