const types = @import("types.zig");

pub const LayoutBox = struct {
    rect: types.Rect = .{},
    content_size: types.Size = .{},
};
