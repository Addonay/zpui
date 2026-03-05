const std = @import("std");
const core = @import("../core/mod.zig");
const runtime = @import("../runtime/mod.zig");

pub const NodeSpec = struct {
    node_type: core.NodeType = .container,
    style: core.Style = .{},
    text: []const u8 = "",
};

pub fn row(style: core.Style) NodeSpec {
    var next = style;
    next.display = .flex;
    next.direction = .row;
    return .{
        .style = next,
    };
}

pub fn column(style: core.Style) NodeSpec {
    var next = style;
    next.display = .flex;
    next.direction = .column;
    return .{
        .style = next,
    };
}

pub fn grid(columns: u16, style: core.Style) NodeSpec {
    var next = style;
    next.display = .grid;
    next.grid_columns = if (columns == 0) 1 else columns;
    return .{
        .style = next,
    };
}

pub fn stack(style: core.Style) NodeSpec {
    var next = style;
    next.display = .stack;
    return .{
        .style = next,
    };
}

pub fn text(content: []const u8, style: core.Style) NodeSpec {
    var next = style;
    next.display = .text;
    return .{
        .node_type = .text,
        .style = next,
        .text = content,
    };
}

pub fn custom(style: core.Style) NodeSpec {
    var next = style;
    next.display = .custom;
    return .{
        .node_type = .custom,
        .style = next,
    };
}

pub fn mount(app: anytype, parent: ?core.NodeId, spec: NodeSpec) !core.NodeId {
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
    var headless_state = @import("../platform/mod.zig").HeadlessPlatformState{};
    var app = runtime.App.init(allocator, @import("../platform/mod.zig").Platform.initHeadlessWithState(&headless_state));
    defer app.deinit();

    const root = try mount(&app, null, column(.{ .gap = 8 }));
    const child = try mount(&app, root, text("value", .{}));

    try std.testing.expectEqual(@as(usize, 1), app.graph.childCount(root));
    try std.testing.expectEqual(core.NodeType.text, app.graph.getConst(child).node_type);
}
