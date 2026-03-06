const geometry = @import("geometry.zig");

pub const LayoutBox = struct {
    rect: geometry.Rect = .{},
    content_size: geometry.Size = .{},
};
