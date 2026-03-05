const std = @import("std");
const zpui = @import("zpui");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const theme = zpui.Theme.dark();

    var headless_state = zpui.HeadlessPlatformState{};
    var app = zpui.App.init(arena, zpui.Platform.initHeadlessWithState(&headless_state));
    defer app.deinit();

    _ = try app.openWindow(.{
        .title = "zpui bootstrap",
        .size = .{ .width = 960, .height = 640 },
    });

    try buildBootstrapUi(&app, theme, 960, 640);
    try app.frame();

    std.debug.print(
        "Generated {d} draw command(s) for {d} headless window(s).\n",
        .{ app.drawCommandCount(), app.liveWindowCount() },
    );
}

fn buildBootstrapUi(app: *zpui.App, theme: zpui.Theme, width: f32, height: f32) !void {
    const root = try zpui.mount(app, null, zpui.column(.{
        .width = width,
        .height = height,
        .padding = zpui.EdgeInsets.all(20),
        .gap = 16,
        .background = theme.palette.surface,
    }));

    const hero = try zpui.mount(app, root, zpui.column(.{
        .height = 128,
        .padding = zpui.EdgeInsets.all(16),
        .gap = 10,
        .background = theme.palette.accent,
        .border_radius = 18,
    }));
    _ = try zpui.mount(app, hero, zpui.textNode("ZPUI Application", .{
        .text_color = theme.palette.text_primary,
    }));
    _ = try zpui.mount(app, hero, zpui.textNode("Std-first core, GPUI-style app state, headless bootstrap platform.", .{
        .text_color = theme.palette.text_primary,
    }));
    const badges = try zpui.mount(app, hero, zpui.row(.{ .gap = 8 }));
    _ = try zpui.mount(app, badges, zpui.textNode("WINDOWS", .{
        .padding = zpui.EdgeInsets.axis(8, 4),
        .background = theme.palette.surface,
        .text_color = theme.palette.text_primary,
        .border_radius = 999,
    }));
    _ = try zpui.mount(app, badges, zpui.textNode("ENTITIES", .{
        .padding = zpui.EdgeInsets.axis(8, 4),
        .background = theme.palette.success,
        .text_color = theme.palette.text_primary,
        .border_radius = 999,
    }));
    _ = try zpui.mount(app, badges, zpui.textNode("HEADLESS", .{
        .padding = zpui.EdgeInsets.axis(8, 4),
        .background = theme.palette.warning,
        .text_color = theme.palette.text_primary,
        .border_radius = 999,
    }));

    const content = try zpui.mount(app, root, zpui.row(.{ .gap = 16 }));

    const left = try zpui.mount(app, content, zpui.grid(2, .{
        .column_gap = 16,
        .row_gap = 16,
    }));
    try statCard(app, left, theme.palette.surface_alt, theme.palette.text_primary, theme.palette.text_muted, "Platform", "Headless");
    try statCard(app, left, theme.palette.surface_alt, theme.palette.text_primary, theme.palette.text_muted, "Renderer", "Retained -> Commands");
    try statCard(app, left, theme.palette.surface_alt, theme.palette.text_primary, theme.palette.text_muted, "Text", "Std Bootstrap");
    try statCard(app, left, theme.palette.surface_alt, theme.palette.text_primary, theme.palette.text_muted, "Mode", "Porting");

    const right = try zpui.mount(app, content, zpui.column(.{
        .width = 260,
        .padding = zpui.EdgeInsets.all(14),
        .gap = 8,
        .background = theme.palette.surface_alt,
        .border_radius = 16,
    }));
    _ = try zpui.mount(app, right, zpui.textNode("What this slice owns", .{
        .text_color = theme.palette.text_primary,
    }));
    _ = try zpui.mount(app, right, zpui.textNode("Keeps window state and typed entities in the higher-level App state.", .{
        .text_color = theme.palette.text_muted,
    }));
    _ = try zpui.mount(app, right, zpui.textNode("Builds layout and draw commands through the runtime frame pipeline.", .{
        .text_color = theme.palette.text_muted,
    }));
    _ = try zpui.mount(app, right, zpui.textNode("Stays std-first until text shaping or native platform work actually requires more.", .{
        .text_color = theme.palette.text_muted,
    }));
}

fn statCard(
    app: *zpui.App,
    parent: zpui.NodeId,
    background: zpui.Color,
    ink: zpui.Color,
    muted: zpui.Color,
    label: []const u8,
    value: []const u8,
) !void {
    const card = try zpui.mount(app, parent, zpui.column(.{
        .width = 300,
        .height = 100,
        .padding = zpui.EdgeInsets.all(14),
        .gap = 8,
        .background = background,
        .border_radius = 16,
    }));
    _ = try zpui.mount(app, card, zpui.textNode(label, .{
        .text_color = muted,
    }));
    _ = try zpui.mount(app, card, zpui.textNode(value, .{
        .text_color = ink,
    }));
}
