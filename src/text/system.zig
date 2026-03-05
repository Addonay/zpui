const std = @import("std");
const core = @import("../core/mod.zig");
const engine = @import("engine.zig");

pub const Direction = engine.Direction;
pub const Glyph = engine.Glyph;
pub const Run = engine.Run;
pub const ShapedText = engine.ShapedText;

pub const FontWeight = enum(u16) {
    thin = 100,
    light = 300,
    regular = 400,
    medium = 500,
    semibold = 600,
    bold = 700,
};

pub const FontStyle = enum {
    normal,
    italic,
};

pub const FontDescriptor = struct {
    family: []const u8 = "system-ui",
    size: f32 = 14,
    weight: FontWeight = .regular,
    style: FontStyle = .normal,
};

pub const ShapeOptions = struct {
    font: FontDescriptor = .{},
    max_width: ?f32 = null,
};

pub const Metrics = struct {
    size: core.Size,
    ascent: f32,
    descent: f32,
    line_gap: f32 = 0,
    glyph_count: usize,

    pub fn lineHeight(self: Metrics) f32 {
        return self.size.height;
    }
};

pub const ShapeFn = *const fn (
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    text: []const u8,
    options: ShapeOptions,
) anyerror!ShapedText;

pub const MeasureFn = *const fn (
    ctx: *anyopaque,
    text: []const u8,
    options: ShapeOptions,
) anyerror!Metrics;

pub const LineHeightFn = *const fn (
    ctx: *anyopaque,
    font: FontDescriptor,
) anyerror!f32;

pub const FontFamilyAvailableFn = *const fn (
    ctx: *anyopaque,
    family: []const u8,
) bool;

pub const PlatformTextSystem = struct {
    ctx: *anyopaque,
    shape_fn: ShapeFn,
    measure_fn: MeasureFn,
    line_height_fn: LineHeightFn,
    font_family_available_fn: FontFamilyAvailableFn,

    pub fn shape(
        self: PlatformTextSystem,
        allocator: std.mem.Allocator,
        text_value: []const u8,
        options: ShapeOptions,
    ) !ShapedText {
        return self.shape_fn(self.ctx, allocator, text_value, options);
    }

    pub fn measure(
        self: PlatformTextSystem,
        text_value: []const u8,
        options: ShapeOptions,
    ) !Metrics {
        return self.measure_fn(self.ctx, text_value, options);
    }

    pub fn lineHeight(
        self: PlatformTextSystem,
        font: FontDescriptor,
    ) !f32 {
        return self.line_height_fn(self.ctx, font);
    }

    pub fn fontFamilyAvailable(
        self: PlatformTextSystem,
        family: []const u8,
    ) bool {
        return self.font_family_available_fn(self.ctx, family);
    }

    pub fn initNoop() PlatformTextSystem {
        return .{
            .ctx = &noop_text_system_state,
            .shape_fn = noopShape,
            .measure_fn = noopMeasure,
            .line_height_fn = noopLineHeight,
            .font_family_available_fn = noopFontFamilyAvailable,
        };
    }
};

pub const TextSystem = struct {
    allocator: std.mem.Allocator,
    platform_text_system: PlatformTextSystem,

    pub fn init(
        allocator: std.mem.Allocator,
        platform_text_system: PlatformTextSystem,
    ) TextSystem {
        return .{
            .allocator = allocator,
            .platform_text_system = platform_text_system,
        };
    }

    pub fn shape(
        self: *TextSystem,
        text_value: []const u8,
        options: ShapeOptions,
    ) !ShapedText {
        return self.platform_text_system.shape(self.allocator, text_value, options);
    }

    pub fn measure(
        self: *TextSystem,
        text_value: []const u8,
        options: ShapeOptions,
    ) !Metrics {
        return self.platform_text_system.measure(text_value, options);
    }

    pub fn lineHeight(
        self: *TextSystem,
        font: FontDescriptor,
    ) !f32 {
        return self.platform_text_system.lineHeight(font);
    }

    pub fn fontFamilyAvailable(
        self: *TextSystem,
        family: []const u8,
    ) bool {
        return self.platform_text_system.fontFamilyAvailable(family);
    }
};

const NoopTextSystemState = struct {};
var noop_text_system_state = NoopTextSystemState{};

fn noopShape(
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
    text_value: []const u8,
    options: ShapeOptions,
) !ShapedText {
    _ = ctx;
    var shaping = engine.TextEngine.init(allocator);
    return shaping.shapeSized(text_value, options.font.size);
}

fn noopMeasure(
    ctx: *anyopaque,
    text_value: []const u8,
    options: ShapeOptions,
) !Metrics {
    _ = ctx;
    const measured = engine.measureText(text_value, options.font.size);
    return .{
        .size = measured,
        .ascent = options.font.size * 0.8,
        .descent = options.font.size * 0.2,
        .glyph_count = engine.glyphCount(text_value),
    };
}

fn noopLineHeight(ctx: *anyopaque, font: FontDescriptor) !f32 {
    _ = ctx;
    return engine.lineHeightForFontSize(font.size);
}

fn noopFontFamilyAvailable(ctx: *anyopaque, family: []const u8) bool {
    _ = ctx;
    return std.mem.eql(u8, family, "system-ui") or
        std.mem.eql(u8, family, "sans-serif") or
        std.mem.eql(u8, family, "serif") or
        std.mem.eql(u8, family, "monospace");
}

test "noop text system shapes and measures text" {
    const allocator = std.testing.allocator;
    var system = TextSystem.init(allocator, PlatformTextSystem.initNoop());

    const options = ShapeOptions{
        .font = .{
            .family = "system-ui",
            .size = 21,
            .weight = .medium,
        },
    };

    var shaped = try system.shape("hello", options);
    defer shaped.deinit(allocator);

    const metrics = try system.measure("hello", options);

    try std.testing.expectEqual(@as(usize, 5), shaped.glyphs.items.len);
    try std.testing.expectEqual(@as(usize, 1), shaped.runs.items.len);
    try std.testing.expectEqual(@as(f32, 60), metrics.size.width);
    try std.testing.expectEqual(@as(f32, 26.25), metrics.lineHeight());
    try std.testing.expect(system.fontFamilyAvailable("system-ui"));
    try std.testing.expect(!system.fontFamilyAvailable("Comic Sans MS"));
}

test "custom platform text system is forwarded through wrapper" {
    const allocator = std.testing.allocator;

    const State = struct {
        shaped: bool = false,
        measured: bool = false,
        line_height_requested: bool = false,
        family_checked: bool = false,
    };

    const Adapter = struct {
        fn shape(
            ctx: *anyopaque,
            call_allocator: std.mem.Allocator,
            text_value: []const u8,
            options: ShapeOptions,
        ) !ShapedText {
            const state: *State = @ptrCast(@alignCast(ctx));
            state.shaped = true;
            _ = options;

            var shaped = ShapedText{};
            try shaped.glyphs.append(call_allocator, .{
                .id = 1,
                .advance = @floatFromInt(text_value.len),
            });
            try shaped.runs.append(call_allocator, .{
                .text = text_value,
                .direction = .ltr,
                .glyph_start = 0,
                .glyph_count = shaped.glyphs.items.len,
            });
            return shaped;
        }

        fn measure(
            ctx: *anyopaque,
            text_value: []const u8,
            options: ShapeOptions,
        ) !Metrics {
            const state: *State = @ptrCast(@alignCast(ctx));
            state.measured = true;
            return .{
                .size = .{
                    .width = @floatFromInt(text_value.len),
                    .height = options.font.size,
                },
                .ascent = options.font.size * 0.7,
                .descent = options.font.size * 0.3,
                .glyph_count = text_value.len,
            };
        }

        fn lineHeight(
            ctx: *anyopaque,
            font: FontDescriptor,
        ) !f32 {
            const state: *State = @ptrCast(@alignCast(ctx));
            state.line_height_requested = true;
            return font.size + 2;
        }

        fn fontFamilyAvailable(ctx: *anyopaque, family: []const u8) bool {
            const state: *State = @ptrCast(@alignCast(ctx));
            state.family_checked = true;
            return std.mem.eql(u8, family, "Test Sans");
        }
    };

    var state = State{};
    var system = TextSystem.init(allocator, .{
        .ctx = &state,
        .shape_fn = Adapter.shape,
        .measure_fn = Adapter.measure,
        .line_height_fn = Adapter.lineHeight,
        .font_family_available_fn = Adapter.fontFamilyAvailable,
    });

    var shaped = try system.shape("abc", .{ .font = .{ .size = 18 } });
    defer shaped.deinit(allocator);
    const metrics = try system.measure("abc", .{ .font = .{ .size = 18 } });
    const line_height = try system.lineHeight(.{ .size = 18 });

    try std.testing.expect(state.shaped);
    try std.testing.expect(state.measured);
    try std.testing.expect(state.line_height_requested);
    try std.testing.expect(system.fontFamilyAvailable("Test Sans"));
    try std.testing.expect(state.family_checked);
    try std.testing.expectEqual(@as(usize, 1), shaped.glyphs.items.len);
    try std.testing.expectEqual(@as(f32, 3), metrics.size.width);
    try std.testing.expectEqual(@as(f32, 20), line_height);
}
