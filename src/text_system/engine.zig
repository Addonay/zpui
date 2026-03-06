const std = @import("std");
const geometry = @import("../geometry.zig");

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
        return self.shapeSized(text, 14);
    }

    pub fn shapeSized(self: *TextEngine, text_bytes: []const u8, font_size: f32) !ShapedText {
        var shaped = ShapedText{};
        const direction = inferDirection(text_bytes);
        const glyph_start = shaped.glyphs.items.len;
        const advance = glyphAdvanceForFontSize(font_size);
        const view = std.unicode.Utf8View.initUnchecked(text_bytes);
        var iter = view.iterator();
        while (iter.nextCodepoint()) |cp| {
            if (cp < 32) continue;
            try shaped.glyphs.append(self.allocator, .{
                .id = @as(u32, cp),
                .advance = advance,
            });
        }
        try shaped.runs.append(self.allocator, .{
            .text = text_bytes,
            .direction = direction,
            .glyph_start = glyph_start,
            .glyph_count = shaped.glyphs.items.len - glyph_start,
        });
        return shaped;
    }
};

pub fn glyphCount(text_bytes: []const u8) usize {
    var count: usize = 0;
    const view = std.unicode.Utf8View.initUnchecked(text_bytes);
    var iter = view.iterator();
    while (iter.nextCodepoint()) |cp| {
        if (cp >= 32) count += 1;
    }
    return count;
}

pub fn glyphAdvanceForFontSize(font_size: f32) f32 {
    return 8 * (font_size / 14);
}

pub fn lineHeightForFontSize(font_size: f32) f32 {
    return font_size * 1.25;
}

pub fn measureText(text: []const u8, font_size: f32) geometry.Size {
    return .{
        .width = @as(f32, @floatFromInt(glyphCount(text))) * glyphAdvanceForFontSize(font_size),
        .height = lineHeightForFontSize(font_size),
    };
}

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

test "measure text scales with font size" {
    const measured = measureText("hello", 21);
    try std.testing.expectEqual(@as(f32, 60), measured.width);
    try std.testing.expectEqual(@as(f32, 26.25), measured.height);
}
