# zpui

A Zig UI toolkit.

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
