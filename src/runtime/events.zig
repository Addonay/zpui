const core = @import("../core/mod.zig");
const platform = @import("../platform/mod.zig");

pub const MouseButton = enum(u8) {
    left,
    right,
    middle,
};

pub const KeyAction = enum(u8) {
    down,
    up,
};

pub const PointerEvent = struct {
    position: core.Point,
    button: ?MouseButton = null,
};

pub const KeyEvent = struct {
    key_code: u32,
    action: KeyAction,
};

pub const WindowResized = struct {
    window: platform.WindowHandle,
    size: core.Size,
};

pub const Event = union(enum) {
    quit_requested: void,
    pointer_move: PointerEvent,
    pointer_down: PointerEvent,
    pointer_up: PointerEvent,
    key: KeyEvent,
    window_resized: WindowResized,
};
