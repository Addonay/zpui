const core = @import("../core/mod.zig");

pub const FillRect = struct {
    rect: core.Rect,
    color: core.Color,
    radius: f32 = 0,
};

pub const TextRun = struct {
    rect: core.Rect,
    text: []const u8,
    color: core.Color,
};

pub const ClipRect = struct {
    rect: core.Rect,
};

pub const DrawCommand = union(enum) {
    fill_rect: FillRect,
    text: TextRun,
    push_clip: ClipRect,
    pop_clip: void,
};
