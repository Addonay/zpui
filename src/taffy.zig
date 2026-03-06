const std = @import("std");
const element = @import("element.zig");
const geometry = @import("geometry.zig");
const style_mod = @import("style.zig");
const text_engine = @import("text_system/engine.zig");

pub const LayoutEngine = struct {
    pub fn layoutTree(self: *LayoutEngine, graph: *element.NodeGraph) anyerror!void {
        _ = self;
        if (graph.root_id) |root_id| {
            _ = try layoutNode(graph, root_id, .{});
        }
    }
};

fn layoutNode(graph: *element.NodeGraph, node_id: element.NodeId, origin: geometry.Point) anyerror!geometry.Size {
    const style = graph.getConst(node_id).style;
    return switch (style.display) {
        .grid => try layoutGrid(graph, node_id, style, origin),
        .stack => try layoutStack(graph, node_id, style, origin),
        .text, .custom => layoutLeaf(graph, node_id, style, origin),
        .flex => try layoutFlex(graph, node_id, style, origin),
    };
}

fn layoutLeaf(
    graph: *element.NodeGraph,
    node_id: element.NodeId,
    style: style_mod.Style,
    origin: geometry.Point,
) geometry.Size {
    const node = graph.getConst(node_id);
    const text_width: f32 = if (node.node_type == .text)
        text_engine.measureText(node.text, 14).width
    else
        0;
    const width = resolveDimension(style.width, style.min_width, style.max_width, text_width + style.padding.horizontal());
    const height = resolveDimension(style.height, style.min_height, style.max_height, 16 + style.padding.vertical());
    graph.get(node_id).layout = .{
        .rect = .{
            .x = origin.x,
            .y = origin.y,
            .width = width,
            .height = height,
        },
        .content_size = .{
            .width = width - style.padding.horizontal(),
            .height = height - style.padding.vertical(),
        },
    };
    return .{ .width = width, .height = height };
}

fn layoutFlex(
    graph: *element.NodeGraph,
    node_id: element.NodeId,
    style: style_mod.Style,
    origin: geometry.Point,
) anyerror!geometry.Size {
    const main_gap = if (style.direction == .row) columnGap(style) else rowGap(style);
    const first_child = graph.getConst(node_id).first_child;

    var child_count: usize = 0;
    var total_main: f32 = 0;
    var max_cross: f32 = 0;

    var cursor_measure = first_child;
    while (cursor_measure) |child_id| {
        const size = try layoutNode(graph, child_id, .{});
        child_count += 1;
        if (style.direction == .row) {
            total_main += size.width;
            max_cross = @max(max_cross, size.height);
        } else {
            total_main += size.height;
            max_cross = @max(max_cross, size.width);
        }
        cursor_measure = graph.getConst(child_id).next_sibling;
    }
    if (child_count > 1) total_main += main_gap * @as(f32, @floatFromInt(child_count - 1));

    var content_width: f32 = 0;
    var content_height: f32 = 0;
    if (style.direction == .row) {
        content_width = total_main;
        content_height = max_cross;
    } else {
        content_width = max_cross;
        content_height = total_main;
    }

    const width = resolveDimension(
        style.width,
        style.min_width,
        style.max_width,
        content_width + style.padding.horizontal(),
    );
    const height = resolveDimension(
        style.height,
        style.min_height,
        style.max_height,
        content_height + style.padding.vertical(),
    );

    const inner_width = @max(0, width - style.padding.horizontal());
    const inner_height = @max(0, height - style.padding.vertical());
    const start_main = resolveJustifyStart(style, total_main, inner_width, inner_height);

    var cursor = first_child;
    var main_offset = start_main;
    while (cursor) |child_id| {
        const child_rect = graph.getConst(child_id).layout.rect;
        const child_x: f32 = if (style.direction == .row)
            origin.x + style.padding.left + main_offset
        else
            origin.x + style.padding.left + resolveAlignOffset(style.align_items, inner_width, child_rect.width);
        const child_y: f32 = if (style.direction == .row)
            origin.y + style.padding.top + resolveAlignOffset(style.align_items, inner_height, child_rect.height)
        else
            origin.y + style.padding.top + main_offset;

        const child_size = try layoutNode(graph, child_id, .{ .x = child_x, .y = child_y });
        main_offset += if (style.direction == .row) child_size.width + main_gap else child_size.height + main_gap;
        cursor = graph.getConst(child_id).next_sibling;
    }

    graph.get(node_id).layout = .{
        .rect = .{
            .x = origin.x,
            .y = origin.y,
            .width = width,
            .height = height,
        },
        .content_size = .{
            .width = inner_width,
            .height = inner_height,
        },
    };
    return .{ .width = width, .height = height };
}

fn layoutGrid(
    graph: *element.NodeGraph,
    node_id: element.NodeId,
    style: style_mod.Style,
    origin: geometry.Point,
) anyerror!geometry.Size {
    const columns_count: usize = @max(@as(usize, 1), @as(usize, style.grid_columns));
    const col_gap = columnGap(style);
    const r_gap = rowGap(style);

    var children: std.ArrayList(element.NodeId) = .empty;
    defer children.deinit(graph.allocator);

    var cursor = graph.getConst(node_id).first_child;
    while (cursor) |child_id| {
        try children.append(graph.allocator, child_id);
        cursor = graph.getConst(child_id).next_sibling;
    }

    const rows_count: usize = if (children.items.len == 0)
        0
    else if (style.grid_rows > 0)
        @as(usize, style.grid_rows)
    else
        (children.items.len + columns_count - 1) / columns_count;

    const col_widths = try graph.allocator.alloc(f32, columns_count);
    defer graph.allocator.free(col_widths);
    const row_heights = try graph.allocator.alloc(f32, if (rows_count == 0) 1 else rows_count);
    defer graph.allocator.free(row_heights);
    @memset(col_widths, 0);
    @memset(row_heights, 0);

    for (children.items, 0..) |child_id, child_idx| {
        const measured = try layoutNode(graph, child_id, .{});
        const row = child_idx / columns_count;
        const col = child_idx % columns_count;
        if (row < row_heights.len) {
            col_widths[col] = @max(col_widths[col], measured.width);
            row_heights[row] = @max(row_heights[row], measured.height);
        }
    }

    var content_width: f32 = 0;
    for (col_widths) |value| content_width += value;
    if (columns_count > 1) {
        content_width += col_gap * @as(f32, @floatFromInt(columns_count - 1));
    }

    var content_height: f32 = 0;
    if (rows_count > 0) {
        for (row_heights[0..rows_count]) |value| content_height += value;
        if (rows_count > 1) {
            content_height += r_gap * @as(f32, @floatFromInt(rows_count - 1));
        }
    }

    const width = resolveDimension(
        style.width,
        style.min_width,
        style.max_width,
        content_width + style.padding.horizontal(),
    );
    const height = resolveDimension(
        style.height,
        style.min_height,
        style.max_height,
        content_height + style.padding.vertical(),
    );

    for (children.items, 0..) |child_id, child_idx| {
        const row = child_idx / columns_count;
        const col = child_idx % columns_count;
        if (row >= rows_count) continue;

        var x = origin.x + style.padding.left;
        var i: usize = 0;
        while (i < col) : (i += 1) x += col_widths[i] + col_gap;

        var y = origin.y + style.padding.top;
        i = 0;
        while (i < row) : (i += 1) y += row_heights[i] + r_gap;

        _ = try layoutNode(graph, child_id, .{ .x = x, .y = y });
    }

    graph.get(node_id).layout = .{
        .rect = .{
            .x = origin.x,
            .y = origin.y,
            .width = width,
            .height = height,
        },
        .content_size = .{
            .width = @max(0, width - style.padding.horizontal()),
            .height = @max(0, height - style.padding.vertical()),
        },
    };
    return .{ .width = width, .height = height };
}

fn layoutStack(
    graph: *element.NodeGraph,
    node_id: element.NodeId,
    style: style_mod.Style,
    origin: geometry.Point,
) anyerror!geometry.Size {
    var max_width: f32 = 0;
    var max_height: f32 = 0;
    var cursor = graph.getConst(node_id).first_child;
    while (cursor) |child_id| {
        const size = try layoutNode(graph, child_id, .{
            .x = origin.x + style.padding.left,
            .y = origin.y + style.padding.top,
        });
        max_width = @max(max_width, size.width);
        max_height = @max(max_height, size.height);
        cursor = graph.getConst(child_id).next_sibling;
    }

    const width = resolveDimension(
        style.width,
        style.min_width,
        style.max_width,
        max_width + style.padding.horizontal(),
    );
    const height = resolveDimension(
        style.height,
        style.min_height,
        style.max_height,
        max_height + style.padding.vertical(),
    );

    graph.get(node_id).layout = .{
        .rect = .{
            .x = origin.x,
            .y = origin.y,
            .width = width,
            .height = height,
        },
        .content_size = .{
            .width = @max(0, width - style.padding.horizontal()),
            .height = @max(0, height - style.padding.vertical()),
        },
    };
    return .{ .width = width, .height = height };
}

fn resolveDimension(explicit: ?f32, min: ?f32, max: ?f32, measured: f32) f32 {
    var value = explicit orelse measured;
    if (min) |minimum| value = @max(value, minimum);
    if (max) |maximum| value = @min(value, maximum);
    return value;
}

fn columnGap(style: style_mod.Style) f32 {
    return style.column_gap orelse style.gap;
}

fn rowGap(style: style_mod.Style) f32 {
    return style.row_gap orelse style.gap;
}

fn resolveJustifyStart(style: style_mod.Style, content_main: f32, inner_width: f32, inner_height: f32) f32 {
    const inner_main = if (style.direction == .row) inner_width else inner_height;
    return switch (style.justify_content) {
        .start => 0,
        .center => @max(0, (inner_main - content_main) * 0.5),
        .end => @max(0, inner_main - content_main),
        .space_between => 0,
    };
}

fn resolveAlignOffset(_align: geometry.Align, inner_cross: f32, child_cross: f32) f32 {
    return switch (_align) {
        .start => 0,
        .center => @max(0, (inner_cross - child_cross) * 0.5),
        .end => @max(0, inner_cross - child_cross),
        .stretch => 0,
    };
}

test "layout flex row places children with gap" {
    const allocator = std.testing.allocator;
    var graph = element.NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{
        .display = .flex,
        .direction = .row,
        .gap = 10,
        .padding = geometry.EdgeInsets.all(4),
    }, "");
    graph.setRoot(root);
    const a = try graph.createNode(.container, .{ .width = 30, .height = 20 }, "");
    const b = try graph.createNode(.container, .{ .width = 20, .height = 12 }, "");
    graph.appendChild(root, a);
    graph.appendChild(root, b);

    var engine = LayoutEngine{};
    try engine.layoutTree(&graph);

    const first = graph.getConst(a).layout.rect;
    const second = graph.getConst(b).layout.rect;
    try std.testing.expectApproxEqAbs(@as(f32, 4), first.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 44), second.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), first.y, 0.001);
}

test "layout grid computes row and column offsets" {
    const allocator = std.testing.allocator;
    var graph = element.NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{
        .display = .grid,
        .grid_columns = 2,
        .column_gap = 8,
        .row_gap = 6,
        .padding = geometry.EdgeInsets.all(2),
    }, "");
    graph.setRoot(root);

    const c1 = try graph.createNode(.container, .{ .width = 10, .height = 10 }, "");
    const c2 = try graph.createNode(.container, .{ .width = 20, .height = 12 }, "");
    const c3 = try graph.createNode(.container, .{ .width = 16, .height = 9 }, "");
    graph.appendChild(root, c1);
    graph.appendChild(root, c2);
    graph.appendChild(root, c3);

    var engine = LayoutEngine{};
    try engine.layoutTree(&graph);

    const first = graph.getConst(c1).layout.rect;
    const second = graph.getConst(c2).layout.rect;
    const third = graph.getConst(c3).layout.rect;
    try std.testing.expectApproxEqAbs(@as(f32, 2), first.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), second.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), third.y, 0.001);
}
