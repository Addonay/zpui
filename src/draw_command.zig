const geometry = @import("geometry.zig");

pub const FillRect = struct {
    rect: geometry.Rect,
    color: geometry.Color,
    radius: f32 = 0,
};

pub const TextRun = struct {
    rect: geometry.Rect,
    text: []const u8,
    color: geometry.Color,
};

pub const ClipRect = struct {
    rect: geometry.Rect,
};

pub const DrawCommand = union(enum) {
    fill_rect: FillRect,
    text: TextRun,
    push_clip: ClipRect,
    pop_clip: void,
};
