const std = @import("std");

pub const Direction = enum {
    ltr,
    rtl,
};

pub const Glyph = struct {
    id: u32,
    advance: f32,
};

pub const Run = struct {
    text: []const u8,
    direction: Direction,
    glyph_start: usize,
    glyph_count: usize,
};

pub const ShapedText = struct {
    runs: std.ArrayList(Run) = .empty,
    glyphs: std.ArrayList(Glyph) = .empty,

    pub fn deinit(self: *ShapedText, allocator: std.mem.Allocator) void {
        self.runs.deinit(allocator);
        self.glyphs.deinit(allocator);
    }
};

pub const TextEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TextEngine {
        return .{ .allocator = allocator };
    }

    pub fn shape(self: *TextEngine, text: []const u8) !ShapedText {
        var shaped = ShapedText{};
        const direction = inferDirection(text);
        const glyph_start = shaped.glyphs.items.len;
        for (text) |byte| {
            if (byte < 32) continue;
            try shaped.glyphs.append(self.allocator, .{
                .id = @as(u32, byte),
                .advance = 8,
            });
        }
        try shaped.runs.append(self.allocator, .{
            .text = text,
            .direction = direction,
            .glyph_start = glyph_start,
            .glyph_count = shaped.glyphs.items.len - glyph_start,
        });
        return shaped;
    }
};

pub fn inferDirection(text: []const u8) Direction {
    // This is intentionally conservative as a bootstrap before full bidi support.
    for (text) |byte| {
        if (byte >= 0xD6 and byte <= 0xDB) return .rtl;
    }
    return .ltr;
}

test "infer direction defaults to ltr" {
    try std.testing.expectEqual(Direction.ltr, inferDirection("hello"));
}
