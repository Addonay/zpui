const std = @import("std");
const core = @import("../core/mod.zig");
const commands = @import("commands.zig");

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(commands.DrawCommand) = .empty,

    pub fn init(allocator: std.mem.Allocator) Renderer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Renderer) void {
        self.commands.deinit(self.allocator);
    }

    pub fn clear(self: *Renderer) void {
        self.commands.clearRetainingCapacity();
    }

    pub fn build(self: *Renderer, graph: *const core.NodeGraph) !void {
        self.clear();
        if (graph.root_id) |root_id| {
            try self.collectNode(graph, root_id);
        }
    }

    fn collectNode(self: *Renderer, graph: *const core.NodeGraph, node_id: core.NodeId) !void {
        const node = graph.getConst(node_id);
        const rect = node.layout.rect;
        if (node.style.background) |background| {
            try self.commands.append(self.allocator, .{
                .fill_rect = .{
                    .rect = rect,
                    .color = background,
                    .radius = node.style.border_radius,
                },
            });
        }

        if (node.node_type == .text and node.text.len > 0) {
            try self.commands.append(self.allocator, .{
                .text = .{
                    .rect = rect,
                    .text = node.text,
                    .color = node.style.text_color orelse core.Color.rgb(245, 245, 245),
                },
            });
        }

        var cursor = node.first_child;
        while (cursor) |child_id| {
            try self.collectNode(graph, child_id);
            cursor = graph.getConst(child_id).next_sibling;
        }
    }
};

test "renderer emits background and text commands" {
    const allocator = std.testing.allocator;
    var graph = core.NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{
        .display = .flex,
        .background = core.Color.rgb(20, 30, 40),
        .width = 100,
        .height = 80,
    }, "");
    graph.setRoot(root);
    const text = try graph.createNode(.text, .{
        .display = .text,
        .text_color = core.Color.rgb(1, 2, 3),
        .width = 80,
        .height = 18,
    }, "hello");
    graph.appendChild(root, text);

    graph.get(root).layout.rect = .{ .x = 0, .y = 0, .width = 100, .height = 80 };
    graph.get(text).layout.rect = .{ .x = 0, .y = 0, .width = 80, .height = 18 };

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();
    try renderer.build(&graph);

    try std.testing.expectEqual(@as(usize, 2), renderer.commands.items.len);
}
