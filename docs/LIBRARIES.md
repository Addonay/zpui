# Library Survey

`zpui` should stay std-first wherever Zig's standard library is enough:

- allocators
- containers
- threading
- build graph wiring
- typed application/entity infrastructure

When `std` is not enough, the current recommendation is to prefer small,
replaceable backend dependencies instead of handing framework ownership away.

## Adopted Now

The repo now pins the native binding stack that best matches GPUI's direction:

- `zig-wayland` for native Linux Wayland work
- `zigwin32` for native Win32 and DirectX-side bindings
- `zig-objc` for Cocoa/AppKit/Metal-side bindings
- `vulkan-zig` plus `Vulkan-Headers` for the Vulkan renderer path

Current role of the shared core:
- test-only platform support while native backends are still being wired
- retained app/runtime/layout/render architecture work
- std-first text measurement bootstrap for tests and early porting slices

Current gap:
- there is not yet a pinned de facto Zig-native X11 package in this repo, so X11 still needs either generated bindings or direct system bindings when that backend is ported

## Likely Next External Dependencies

### HarfBuzz

Use when:
- `zpui` needs real text shaping behind `PlatformTextSystem`
- complex scripts, ligatures, bidi, and proper glyph clustering matter

Why:
- `std` does not provide shaping
- this is the standard serious answer for native UI text shaping

Official reference:
- https://harfbuzz.github.io/

### FreeType

Use when:
- `zpui` needs glyph rasterization and font metrics beyond the std-first bootstrap text engine

Why:
- `std` does not provide font loading or glyph rasterization

Official reference:
- https://freetype.org/

### Fontconfig

Use when:
- Linux font discovery and fallback become necessary

Why:
- useful for desktop-native font lookup on Linux
- may stay platform-specific instead of entering the shared core

Official reference:
- https://www.freedesktop.org/wiki/Software/fontconfig/

## Zig-Native Ecosystem Candidates

These are not committed dependencies yet. They are candidates if the std-only
or direct-C-interop approach becomes too costly.

### mach

Potential role:
- graphics/windowing ecosystem pieces

Caution:
- powerful, but adopting it too early would blur whether `zpui` owns the stack
  or is being shaped by another ecosystem's architecture

Official reference:
- https://machengine.org/

### zig-wayland

Potential role:
- native Linux backend work once the platform contract is stable enough to justify a real backend

Official reference:
- https://github.com/ifreund/zig-wayland

### vulkan-zig

Potential role:
- lower-level GPU backend if `zpui` chooses to own a Vulkan renderer directly

Official reference:
- https://github.com/Snektron/vulkan-zig

## Current Recommendation

1. Keep core framework code std-first.
2. Port native Wayland/Win32/Cocoa backends on top of the pinned bindings instead of adding GLFW or SDL.
3. Use HarfBuzz + FreeType when the text system graduates from bootstrap mode.
4. Evaluate X11 binding options once the Linux backend split is clearer.
5. Evaluate native backend libraries only after the `zpui` platform API is wider
   and more stable than it is today.
