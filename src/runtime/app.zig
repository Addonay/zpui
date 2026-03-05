const std = @import("std");
const core = @import("../core/mod.zig");
const layout = @import("../layout/mod.zig");
const render = @import("../render/mod.zig");
const platform = @import("../platform/mod.zig");
const events = @import("events.zig");
const signals = @import("signals.zig");
const tasks = @import("tasks.zig");

pub const Phase = enum {
    events,
    state,
    layout,
    paint,
    submit,
};

pub const FrameTrace = struct {
    phases: [8]Phase = undefined,
    len: usize = 0,

    pub fn clear(self: *FrameTrace) void {
        self.len = 0;
    }

    pub fn push(self: *FrameTrace, phase: Phase) void {
        std.debug.assert(self.len < self.phases.len);
        self.phases[self.len] = phase;
        self.len += 1;
    }
};

pub const App = struct {
    allocator: std.mem.Allocator,
    graph: core.NodeGraph,
    reactor: signals.Reactor,
    layout_engine: layout.LayoutEngine = .{},
    renderer: render.Renderer,
    backend: platform.Backend,
    scheduler: tasks.TaskScheduler,
    frame_trace: FrameTrace = .{},
    event_queue: std.ArrayList(events.Event) = .empty,

    pub fn init(allocator: std.mem.Allocator, backend: platform.Backend) App {
        return .{
            .allocator = allocator,
            .graph = core.NodeGraph.init(allocator),
            .reactor = signals.Reactor.init(allocator),
            .renderer = render.Renderer.init(allocator),
            .backend = backend,
            .scheduler = tasks.TaskScheduler.init(allocator),
        };
    }

    pub fn deinit(self: *App) void {
        self.event_queue.deinit(self.allocator);
        self.scheduler.deinit();
        self.renderer.deinit();
        self.reactor.deinit();
        self.graph.deinit();
    }

    pub fn createNode(
        self: *App,
        node_type: core.NodeType,
        style: core.Style,
        text: []const u8,
    ) !core.NodeId {
        return self.graph.createNode(node_type, style, text);
    }

    pub fn appendChild(self: *App, parent: core.NodeId, child: core.NodeId) void {
        self.graph.appendChild(parent, child);
    }

    pub fn beginBatch(self: *App) void {
        self.reactor.beginBatch();
    }

    pub fn endBatch(self: *App) void {
        self.reactor.endBatch();
    }

    pub fn frame(self: *App) !void {
        self.frame_trace.clear();

        self.frame_trace.push(.events);
        try self.backend.pollEvents(&self.event_queue, self.allocator);

        self.frame_trace.push(.state);
        self.scheduler.drainUi();
        self.reactor.flush();

        self.frame_trace.push(.layout);
        if (self.graph.root_id) |_| {
            try self.layout_engine.layoutTree(&self.graph);
        }

        self.frame_trace.push(.paint);
        if (self.graph.root_id) |_| {
            try self.renderer.build(&self.graph);
            self.graph.clearDirtySubtree(self.graph.root_id.?);
        } else {
            self.renderer.clear();
        }

        self.frame_trace.push(.submit);
        try self.backend.present(self.renderer.commands.items);

        self.event_queue.clearRetainingCapacity();
    }

    pub fn postToUi(self: *App, callback: tasks.TaskFn, ctx: *anyopaque) !void {
        try self.scheduler.postToUi(callback, ctx);
    }

    pub fn spawnTask(self: *App, callback: tasks.TaskFn, ctx: *anyopaque) !void {
        try self.scheduler.spawnTask(callback, ctx);
    }
};

test "app frame executes phases in order" {
    const allocator = std.testing.allocator;
    const backend = platform.Backend.initNull();
    var app = App.init(allocator, backend);
    defer app.deinit();

    const root = try app.createNode(.container, .{
        .display = .flex,
        .direction = .column,
        .padding = core.EdgeInsets.all(8),
    }, "");
    app.graph.setRoot(root);
    const text = try app.createNode(.text, .{
        .display = .text,
        .height = 20,
    }, "hello");
    app.appendChild(root, text);

    try app.frame();

    try std.testing.expectEqual(@as(usize, 5), app.frame_trace.len);
    try std.testing.expectEqual(Phase.events, app.frame_trace.phases[0]);
    try std.testing.expectEqual(Phase.state, app.frame_trace.phases[1]);
    try std.testing.expectEqual(Phase.layout, app.frame_trace.phases[2]);
    try std.testing.expectEqual(Phase.paint, app.frame_trace.phases[3]);
    try std.testing.expectEqual(Phase.submit, app.frame_trace.phases[4]);
    try std.testing.expect(app.renderer.commands.items.len >= 1);
}
