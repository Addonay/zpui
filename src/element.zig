const std = @import("std");
const layout_box = @import("layout_box.zig");
const style_mod = @import("style.zig");

pub const NodeId = enum(u32) {
    _,

    pub fn index(self: NodeId) usize {
        return @as(usize, @intCast(@intFromEnum(self) - 1));
    }

    pub fn fromIndex(idx: usize) NodeId {
        return @enumFromInt(@as(u32, @intCast(idx + 1)));
    }
};

pub const NodeType = enum {
    container,
    text,
    custom,
};

pub const DirtyMask = struct {
    pub const none: u8 = 0;
    pub const layout: u8 = 1 << 0;
    pub const paint: u8 = 1 << 1;
    pub const state: u8 = 1 << 2;
    pub const all: u8 = layout | paint | state;
};

pub const Node = struct {
    id: NodeId,
    parent: ?NodeId = null,
    first_child: ?NodeId = null,
    last_child: ?NodeId = null,
    next_sibling: ?NodeId = null,
    prev_sibling: ?NodeId = null,
    node_type: NodeType = .container,
    style: style_mod.Style = .{},
    layout: layout_box.LayoutBox = .{},
    dirty: u8 = DirtyMask.all,
    text: []const u8 = "",
};

pub const NodeGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node) = .empty,
    root_id: ?NodeId = null,

    pub fn init(allocator: std.mem.Allocator) NodeGraph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeGraph) void {
        self.nodes.deinit(self.allocator);
    }

    pub fn createNode(
        self: *NodeGraph,
        node_type: NodeType,
        style: style_mod.Style,
        text: []const u8,
    ) !NodeId {
        const id = NodeId.fromIndex(self.nodes.items.len);
        const node = Node{
            .id = id,
            .node_type = node_type,
            .style = style,
            .text = text,
        };
        try self.nodes.append(self.allocator, node);
        if (self.root_id == null) self.root_id = id;
        return id;
    }

    pub fn setRoot(self: *NodeGraph, node_id: NodeId) void {
        self.root_id = node_id;
    }

    pub fn get(self: *NodeGraph, node_id: NodeId) *Node {
        return &self.nodes.items[node_id.index()];
    }

    pub fn getConst(self: *const NodeGraph, node_id: NodeId) *const Node {
        return &self.nodes.items[node_id.index()];
    }

    pub fn appendChild(self: *NodeGraph, parent_id: NodeId, child_id: NodeId) void {
        const parent_idx = parent_id.index();
        const child_idx = child_id.index();
        const prev_last = self.nodes.items[parent_idx].last_child;

        self.nodes.items[child_idx].parent = parent_id;
        self.nodes.items[child_idx].prev_sibling = prev_last;
        self.nodes.items[child_idx].next_sibling = null;

        if (prev_last) |last_id| {
            self.nodes.items[last_id.index()].next_sibling = child_id;
        } else {
            self.nodes.items[parent_idx].first_child = child_id;
        }
        self.nodes.items[parent_idx].last_child = child_id;
        self.markLayoutDirty(parent_id);
    }

    pub fn clearChildren(self: *NodeGraph, parent_id: NodeId) void {
        var cursor = self.get(parent_id).first_child;
        while (cursor) |child_id| {
            const next = self.get(child_id).next_sibling;
            var child = self.get(child_id);
            child.parent = null;
            child.prev_sibling = null;
            child.next_sibling = null;
            cursor = next;
        }
        var parent = self.get(parent_id);
        parent.first_child = null;
        parent.last_child = null;
        self.markLayoutDirty(parent_id);
    }

    pub fn markLayoutDirty(self: *NodeGraph, node_id: NodeId) void {
        self.get(node_id).dirty |= DirtyMask.layout | DirtyMask.paint;
        var cursor = self.get(node_id).parent;
        while (cursor) |parent_id| {
            self.get(parent_id).dirty |= DirtyMask.layout | DirtyMask.paint;
            cursor = self.get(parent_id).parent;
        }
    }

    pub fn markPaintDirty(self: *NodeGraph, node_id: NodeId) void {
        self.get(node_id).dirty |= DirtyMask.paint;
        var cursor = self.get(node_id).parent;
        while (cursor) |parent_id| {
            self.get(parent_id).dirty |= DirtyMask.paint;
            cursor = self.get(parent_id).parent;
        }
    }

    pub fn clearDirtySubtree(self: *NodeGraph, node_id: NodeId) void {
        self.get(node_id).dirty = DirtyMask.none;
        var cursor = self.get(node_id).first_child;
        while (cursor) |child_id| {
            self.clearDirtySubtree(child_id);
            cursor = self.getConst(child_id).next_sibling;
        }
    }

    pub fn childCount(self: *const NodeGraph, node_id: NodeId) usize {
        var count: usize = 0;
        var cursor = self.getConst(node_id).first_child;
        while (cursor) |child_id| {
            count += 1;
            cursor = self.getConst(child_id).next_sibling;
        }
        return count;
    }
};

test "node graph append child links siblings and parent pointers" {
    const allocator = std.testing.allocator;
    var graph = NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{}, "");
    graph.setRoot(root);
    const first = try graph.createNode(.container, .{}, "");
    const second = try graph.createNode(.container, .{}, "");
    graph.appendChild(root, first);
    graph.appendChild(root, second);

    try std.testing.expectEqual(@as(usize, 2), graph.childCount(root));
    try std.testing.expectEqual(root, graph.get(first).parent.?);
    try std.testing.expectEqual(first, graph.get(second).prev_sibling.?);
    try std.testing.expectEqual(second, graph.get(first).next_sibling.?);
}

test "mark layout dirty bubbles to root" {
    const allocator = std.testing.allocator;
    var graph = NodeGraph.init(allocator);
    defer graph.deinit();

    const root = try graph.createNode(.container, .{}, "");
    graph.setRoot(root);
    const child = try graph.createNode(.container, .{}, "");
    graph.appendChild(root, child);
    graph.clearDirtySubtree(root);

    graph.markLayoutDirty(child);
    try std.testing.expect((graph.get(child).dirty & DirtyMask.layout) != 0);
    try std.testing.expect((graph.get(root).dirty & DirtyMask.layout) != 0);
}
