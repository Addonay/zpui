const std = @import("std");
const zpui = @import("zpui");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    var app = zpui.App.init(arena, zpui.Backend.initNull());
    defer app.deinit();
    const theme = zpui.Theme.dark();

    const root = try zpui.mount(&app, null, zpui.column(.{
        .padding = zpui.EdgeInsets.all(16),
        .gap = 12,
        .background = theme.palette.surface,
    }));
    _ = try zpui.mount(&app, root, zpui.textNode("ZPUI bootstrap frame", .{
        .height = 20,
        .text_color = theme.palette.text_primary,
    }));

    try app.frame();
    std.debug.print(
        "Generated {d} draw command(s) in one frame.\n",
        .{app.renderer.commands.items.len},
    );
}
