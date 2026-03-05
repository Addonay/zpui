const std = @import("std");
const core = @import("../core/mod.zig");
const layout = @import("../layout/mod.zig");
const render = @import("../render/mod.zig");
const platform = @import("../platform/mod.zig");
const text_mod = @import("../text/mod.zig");
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
    platform_impl: platform.Platform,
    text_system: text_mod.TextSystem,
    scheduler: tasks.TaskScheduler,
    frame_trace: FrameTrace = .{},
    event_queue: std.ArrayList(events.Event) = .empty,
    quit_requested: bool = false,
    window_size: ?core.Size = null,

    pub fn init(allocator: std.mem.Allocator, platform_impl: platform.Platform) App {
        return .{
            .allocator = allocator,
            .graph = core.NodeGraph.init(allocator),
            .reactor = signals.Reactor.init(allocator),
            .renderer = render.Renderer.init(allocator),
            .platform_impl = platform_impl,
            .text_system = text_mod.TextSystem.init(allocator, platform_impl.textSystem()),
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
        text_value: []const u8,
    ) !core.NodeId {
        return self.graph.createNode(node_type, style, text_value);
    }

    pub fn appendChild(self: *App, parent: core.NodeId, child: core.NodeId) void {
        self.graph.appendChild(parent, child);
    }

    pub fn setRootNode(self: *App, node_id: core.NodeId) void {
        self.graph.setRoot(node_id);
    }

    pub fn beginBatch(self: *App) void {
        self.reactor.beginBatch();
    }

    pub fn endBatch(self: *App) void {
        self.reactor.endBatch();
    }

    pub fn frame(self: *App) !void {
        self.frame_trace.clear();
        self.event_queue.clearRetainingCapacity();

        self.frame_trace.push(.events);
        try self.platform_impl.pollEvents(&self.event_queue, self.allocator);
        self.capturePlatformState();

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
        try self.platform_impl.present(self.renderer.commands.items);
    }

    pub fn shouldQuit(self: *const App) bool {
        return self.quit_requested;
    }

    pub fn currentWindowSize(self: *const App) ?core.Size {
        return self.window_size;
    }

    pub fn textSystem(self: *App) *text_mod.TextSystem {
        return &self.text_system;
    }

    pub fn drawCommandCount(self: *const App) usize {
        return self.renderer.commands.items.len;
    }

    pub fn openPlatformWindow(self: *App, options: platform.WindowOptions) !platform.WindowHandle {
        return self.platform_impl.openWindow(options);
    }

    pub fn closePlatformWindow(self: *App, window: platform.WindowHandle) !void {
        if (window == platform.invalid_window_handle) return;
        try self.platform_impl.closeWindow(window);
    }

    pub fn setCursorStyle(self: *App, style: platform.CursorStyle) !void {
        try self.platform_impl.setCursorStyle(style);
    }

    pub fn readClipboardText(self: *App) !?[]u8 {
        return self.platform_impl.readClipboardText(self.allocator);
    }

    pub fn writeClipboardText(self: *App, value: []const u8) !void {
        try self.platform_impl.writeClipboardText(value);
    }

    pub fn postToUi(self: *App, callback: tasks.TaskFn, ctx: *anyopaque) !void {
        try self.scheduler.postToUi(callback, ctx);
    }

    pub fn spawnTask(self: *App, callback: tasks.TaskFn, ctx: *anyopaque) !void {
        try self.scheduler.spawnTask(callback, ctx);
    }

    fn capturePlatformState(self: *App) void {
        for (self.event_queue.items) |event| {
            switch (event) {
                .quit_requested => self.quit_requested = true,
                .window_resized => |ev| self.window_size = ev.size,
                else => {},
            }
        }
    }

    pub fn recentEvents(self: *const App) []const events.Event {
        return self.event_queue.items;
    }
};

test "app frame executes phases in order" {
    const allocator = std.testing.allocator;
    var headless_state = platform.HeadlessPlatformState{};
    const platform_impl = platform.Platform.initHeadlessWithState(&headless_state);
    var app = App.init(allocator, platform_impl);
    defer app.deinit();

    const root = try app.createNode(.container, .{
        .display = .flex,
        .direction = .column,
        .padding = core.EdgeInsets.all(8),
    }, "");
    app.graph.setRoot(root);
    const text_node = try app.createNode(.text, .{
        .display = .text,
        .height = 20,
    }, "hello");
    app.appendChild(root, text_node);

    try app.frame();

    try std.testing.expectEqual(@as(usize, 5), app.frame_trace.len);
    try std.testing.expectEqual(Phase.events, app.frame_trace.phases[0]);
    try std.testing.expectEqual(Phase.state, app.frame_trace.phases[1]);
    try std.testing.expectEqual(Phase.layout, app.frame_trace.phases[2]);
    try std.testing.expectEqual(Phase.paint, app.frame_trace.phases[3]);
    try std.testing.expectEqual(Phase.submit, app.frame_trace.phases[4]);
    try std.testing.expect(app.renderer.commands.items.len >= 1);
}

test "app tracks platform quit and resize state" {
    const allocator = std.testing.allocator;

    const PlatformState = struct {
        emitted: bool = false,

        fn poll(
            ctx: *anyopaque,
            queue: *std.ArrayList(events.Event),
            allocator_arg: std.mem.Allocator,
        ) !void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.emitted) return;
            self.emitted = true;
            try queue.append(allocator_arg, .{
                .window_resized = .{
                    .window = 0,
                    .size = .{
                        .width = 640,
                        .height = 480,
                    },
                },
            });
            try queue.append(allocator_arg, .{ .quit_requested = {} });
        }

        fn present(ctx: *anyopaque, commands: []const render.DrawCommand) !void {
            _ = ctx;
            _ = commands;
        }

        fn openWindow(ctx: *anyopaque, options: platform.WindowOptions) !platform.WindowHandle {
            _ = ctx;
            _ = options;
            return 1;
        }

        fn closeWindow(ctx: *anyopaque, window: platform.WindowHandle) !void {
            _ = ctx;
            _ = window;
        }

        fn setCursorStyle(ctx: *anyopaque, style: platform.CursorStyle) !void {
            _ = ctx;
            _ = style;
        }

        fn readClipboardText(ctx: *anyopaque, allocator_arg: std.mem.Allocator) !?[]u8 {
            _ = ctx;
            _ = allocator_arg;
            return null;
        }

        fn writeClipboardText(ctx: *anyopaque, value: []const u8) !void {
            _ = ctx;
            _ = value;
        }

        fn textSystem(ctx: *anyopaque) text_mod.PlatformTextSystem {
            _ = ctx;
            return text_mod.PlatformTextSystem.initNoop();
        }
    };

    var state = PlatformState{};
    var app = App.init(allocator, .{
        .ctx = &state,
        .poll_events_fn = PlatformState.poll,
        .present_fn = PlatformState.present,
        .open_window_fn = PlatformState.openWindow,
        .close_window_fn = PlatformState.closeWindow,
        .set_cursor_style_fn = PlatformState.setCursorStyle,
        .read_clipboard_text_fn = PlatformState.readClipboardText,
        .write_clipboard_text_fn = PlatformState.writeClipboardText,
        .text_system_fn = PlatformState.textSystem,
    });
    defer app.deinit();

    try app.frame();

    try std.testing.expect(app.shouldQuit());
    try std.testing.expectEqual(@as(f32, 640), app.currentWindowSize().?.width);
    try std.testing.expectEqual(@as(f32, 480), app.currentWindowSize().?.height);
}

test "app exposes backend platform services" {
    const allocator = std.testing.allocator;
    var headless_state = platform.HeadlessPlatformState{};
    var app = App.init(allocator, platform.Platform.initHeadlessWithState(&headless_state));
    defer app.deinit();

    const platform_window = try app.openPlatformWindow(.{ .title = "Scratchpad" });
    try std.testing.expect(platform_window != platform.invalid_window_handle);

    try app.setCursorStyle(.pointer);
    try std.testing.expectEqual(platform.CursorStyle.pointer, headless_state.cursor_style);

    try app.writeClipboardText("zpui");
    const clipboard = (try app.readClipboardText()).?;
    defer allocator.free(clipboard);
    try std.testing.expectEqualStrings("zpui", clipboard);

    const metrics = try app.textSystem().measure("render", .{ .font = .{ .size = 16 } });
    try std.testing.expectEqual(@as(usize, 6), metrics.glyph_count);
}
