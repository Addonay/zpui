const std = @import("std");
const element = @import("../element.zig");
const app_runtime = @import("../app/runtime.zig");
const style_mod = @import("../style.zig");

pub const NodeSpec = struct {
    node_type: element.NodeType = .container,
    style: style_mod.Style = .{},
    text: []const u8 = "",
};

pub fn row(style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .flex;
    next.direction = .row;
    return .{
        .style = next,
    };
}

pub fn column(style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .flex;
    next.direction = .column;
    return .{
        .style = next,
    };
}

pub fn grid(columns: u16, style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .grid;
    next.grid_columns = if (columns == 0) 1 else columns;
    return .{
        .style = next,
    };
}

pub fn stack(style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .stack;
    return .{
        .style = next,
    };
}

pub fn text(content: []const u8, style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .text;
    return .{
        .node_type = .text,
        .style = next,
        .text = content,
    };
}

pub fn custom(style: style_mod.Style) NodeSpec {
    var next = style;
    next.display = .custom;
    return .{
        .node_type = .custom,
        .style = next,
    };
}

pub fn mount(app: anytype, parent: ?element.NodeId, spec: NodeSpec) !element.NodeId {
    const node_id = try app.createNode(spec.node_type, spec.style, spec.text);
    if (parent) |parent_id| {
        app.appendChild(parent_id, node_id);
    } else {
        app.setRootNode(node_id);
    }
    return node_id;
}

test "builder mounts text node into app graph" {
    const allocator = std.testing.allocator;
    const platform = @import("../platform/mod.zig");
    var test_platform_state = platform.@"test".TestPlatformState{};
    var test_platform = platform.@"test".TestPlatform.init(&test_platform_state);
    var app = app_runtime.App.init(allocator, test_platform.asPlatform());
    defer app.deinit();

    const root = try mount(&app, null, column(.{ .gap = 8 }));
    const child = try mount(&app, root, text("value", .{}));

    try std.testing.expectEqual(@as(usize, 1), app.graph.childCount(root));
    try std.testing.expectEqual(element.NodeType.text, app.graph.getConst(child).node_type);
}
