const std = @import("std");
const draw_command = @import("draw_command.zig");
const element = @import("element.zig");
const geometry = @import("geometry.zig");

pub const DrawCommand = draw_command.DrawCommand;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(DrawCommand) = .empty,

    pub fn init(allocator: std.mem.Allocator) Renderer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Renderer) void {
        self.commands.deinit(self.allocator);
    }

    pub fn clear(self: *Renderer) void {
        self.commands.clearRetainingCapacity();
    }

    pub fn build(self: *Renderer, graph: *const element.NodeGraph) !void {
        self.clear();
        if (graph.root_id) |root_id| {
            try self.collectNode(graph, root_id);
        }
    }

    fn collectNode(self: *Renderer, graph: *const element.NodeGraph, node_id: element.NodeId) !void {
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
                    .color = node.style.text_color orelse geometry.Color.rgb(245, 245, 245),
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
    var graph = element.NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{
        .display = .flex,
        .background = geometry.Color.rgb(20, 30, 40),
        .width = 100,
        .height = 80,
    }, "");
    graph.setRoot(root);
    const text = try graph.createNode(.text, .{
        .display = .text,
        .text_color = geometry.Color.rgb(1, 2, 3),
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
