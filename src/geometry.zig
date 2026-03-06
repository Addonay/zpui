const std = @import("std");

pub const Axis = enum {
    row,
    column,
};

pub const Align = enum {
    start,
    center,
    end,
    stretch,
};

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
};

pub const Size = struct {
    width: f32 = 0,
    height: f32 = 0,
};

pub const Point = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub const Rect = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn contains(self: Rect, point: Point) bool {
        return point.x >= self.x and
            point.y >= self.y and
            point.x <= self.x + self.width and
            point.y <= self.y + self.height;
    }
};

pub const EdgeInsets = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(value: f32) EdgeInsets {
        return .{
            .top = value,
            .right = value,
            .bottom = value,
            .left = value,
        };
    }

    pub fn axis(horizontal_value: f32, vertical_value: f32) EdgeInsets {
        return .{
            .top = vertical_value,
            .right = horizontal_value,
            .bottom = vertical_value,
            .left = horizontal_value,
        };
    }

    pub fn horizontal(self: EdgeInsets) f32 {
        return self.left + self.right;
    }

    pub fn vertical(self: EdgeInsets) f32 {
        return self.top + self.bottom;
    }
};

test "rect contains point" {
    const rect = Rect{ .x = 5, .y = 5, .width = 10, .height = 4 };
    try std.testing.expect(rect.contains(.{ .x = 10, .y = 6 }));
    try std.testing.expect(!rect.contains(.{ .x = 3, .y = 6 }));
}
