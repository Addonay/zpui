const core = @import("../core/mod.zig");

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
    key_code: u16,
    action: KeyAction,
};

pub const Event = union(enum) {
    pointer_move: PointerEvent,
    pointer_down: PointerEvent,
    pointer_up: PointerEvent,
    key: KeyEvent,
    window_resized: core.Size,
};
