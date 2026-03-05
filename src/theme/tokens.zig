const std = @import("std");
const core = @import("../core/mod.zig");

pub const Palette = struct {
    surface: core.Color,
    surface_alt: core.Color,
    text_primary: core.Color,
    text_muted: core.Color,
    accent: core.Color,
    success: core.Color,
    warning: core.Color,
    danger: core.Color,
};

pub const SpacingScale = struct {
    xs: f32 = 4,
    sm: f32 = 8,
    md: f32 = 12,
    lg: f32 = 16,
    xl: f32 = 24,
};

pub const TypographyScale = struct {
    body: f32 = 14,
    body_large: f32 = 16,
    title: f32 = 20,
    headline: f32 = 28,
};

pub const Theme = struct {
    palette: Palette,
    spacing: SpacingScale = .{},
    typography: TypographyScale = .{},

    pub fn dark() Theme {
        return .{
            .palette = .{
                .surface = core.Color.rgb(18, 22, 28),
                .surface_alt = core.Color.rgb(27, 32, 40),
                .text_primary = core.Color.rgb(236, 238, 244),
                .text_muted = core.Color.rgb(154, 162, 178),
                .accent = core.Color.rgb(52, 123, 235),
                .success = core.Color.rgb(43, 170, 99),
                .warning = core.Color.rgb(222, 166, 36),
                .danger = core.Color.rgb(220, 72, 72),
            },
        };
    }

    pub fn light() Theme {
        return .{
            .palette = .{
                .surface = core.Color.rgb(246, 247, 250),
                .surface_alt = core.Color.rgb(232, 236, 243),
                .text_primary = core.Color.rgb(26, 30, 38),
                .text_muted = core.Color.rgb(89, 97, 116),
                .accent = core.Color.rgb(43, 103, 208),
                .success = core.Color.rgb(33, 144, 80),
                .warning = core.Color.rgb(198, 136, 16),
                .danger = core.Color.rgb(191, 55, 55),
            },
        };
    }
};

test "theme presets expose distinct surfaces" {
    const dark = Theme.dark();
    const light = Theme.light();
    try std.testing.expect(!std.meta.eql(dark.palette.surface, light.palette.surface));
}
