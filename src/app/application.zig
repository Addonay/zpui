const std = @import("std");
const element = @import("../element.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform/mod.zig");
const runtime = @import("runtime.zig");
const style_mod = @import("../style.zig");
const text = @import("../text_system/mod.zig");
const entity = @import("entity_map.zig");

pub const WindowId = enum(u32) {
    _,

    pub fn index(self: WindowId) usize {
        return @as(usize, @intCast(@intFromEnum(self) - 1));
    }

    pub fn fromIndex(idx: usize) WindowId {
        return @enumFromInt(@as(u32, @intCast(idx + 1)));
    }
};

pub const WindowOptions = struct {
    title: []const u8 = "zpui",
    size: geometry.Size = .{ .width = 960, .height = 640 },
    resizable: bool = true,
    root: ?entity.AnyEntity = null,
};

pub const Window = struct {
    id: WindowId,
    platform_window: platform.WindowHandle = platform.invalid_window_handle,
    title: []const u8,
    size: geometry.Size,
    root: ?entity.AnyEntity = null,
    live: bool = true,
};

pub const App = struct {
    allocator: std.mem.Allocator,
    runtime_app: runtime.App,
    entities: entity.EntityStore,
    windows: std.ArrayList(Window) = .empty,
    active_window: ?WindowId = null,

    pub fn init(allocator: std.mem.Allocator, platform_impl: platform.Platform) App {
        return .{
            .allocator = allocator,
            .runtime_app = runtime.App.init(allocator, platform_impl),
            .entities = entity.EntityStore.init(allocator),
        };
    }

    pub fn deinit(self: *App) void {
        for (self.windows.items) |*record| {
            if (record.live) {
                self.runtime_app.closePlatformWindow(record.platform_window) catch {};
                record.live = false;
            }
            if (record.title.len > 0) {
                self.allocator.free(record.title);
            }
        }
        self.windows.deinit(self.allocator);
        self.entities.deinit();
        self.runtime_app.deinit();
    }

    pub fn frame(self: *App) !void {
        try self.runtime_app.frame();
        self.processWindowEvents();
    }

    pub fn createNode(
        self: *App,
        node_type: element.NodeType,
        style: style_mod.Style,
        text_value: []const u8,
    ) !element.NodeId {
        return self.runtime_app.createNode(node_type, style, text_value);
    }

    pub fn appendChild(self: *App, parent: element.NodeId, child: element.NodeId) void {
        self.runtime_app.appendChild(parent, child);
    }

    pub fn setRootNode(self: *App, node_id: element.NodeId) void {
        self.runtime_app.setRootNode(node_id);
    }

    pub fn shouldQuit(self: *const App) bool {
        return self.runtime_app.shouldQuit();
    }

    pub fn textSystem(self: *App) *text.TextSystem {
        return self.runtime_app.textSystem();
    }

    pub fn drawCommandCount(self: *const App) usize {
        return self.runtime_app.drawCommandCount();
    }

    pub fn setCursorStyle(self: *App, style: platform.CursorStyle) !void {
        try self.runtime_app.setCursorStyle(style);
    }

    pub fn readClipboardText(self: *App) !?[]u8 {
        return self.runtime_app.readClipboardText();
    }

    pub fn writeClipboardText(self: *App, value: []const u8) !void {
        try self.runtime_app.writeClipboardText(value);
    }

    pub fn openWindow(self: *App, options: WindowOptions) !WindowId {
        const id = WindowId.fromIndex(self.windows.items.len);
        const title = try self.allocator.dupe(u8, options.title);
        errdefer self.allocator.free(title);

        const platform_window = try self.runtime_app.openPlatformWindow(.{
            .title = options.title,
            .size = options.size,
            .resizable = options.resizable,
        });
        errdefer self.runtime_app.closePlatformWindow(platform_window) catch {};

        try self.windows.append(self.allocator, .{
            .id = id,
            .platform_window = platform_window,
            .title = title,
            .size = options.size,
            .root = options.root,
            .live = true,
        });
        if (self.active_window == null) self.active_window = id;
        return id;
    }

    pub fn closeWindow(self: *App, id: WindowId) !void {
        if (id.index() >= self.windows.items.len) return;
        var record = &self.windows.items[id.index()];
        if (!record.live) return;

        try self.runtime_app.closePlatformWindow(record.platform_window);
        self.allocator.free(record.title);
        record.platform_window = platform.invalid_window_handle;
        record.title = &.{};
        record.root = null;
        record.live = false;

        if (self.active_window == id) {
            self.active_window = self.firstLiveWindow();
        }
    }

    pub fn window(self: *App, id: WindowId) ?*Window {
        if (id.index() >= self.windows.items.len) return null;
        const record = &self.windows.items[id.index()];
        if (!record.live) return null;
        return record;
    }

    pub fn createEntity(self: *App, comptime T: type, value: T) !entity.Entity(T) {
        return self.entities.create(T, value);
    }

    pub fn reserveEntity(self: *App, comptime T: type) !entity.Reservation(T) {
        return self.entities.reserve(T);
    }

    pub fn insertEntity(
        self: *App,
        comptime T: type,
        reservation: entity.Reservation(T),
        value: T,
    ) !entity.Entity(T) {
        return self.entities.insertReserved(T, reservation, value);
    }

    pub fn updateEntity(self: *App, comptime T: type, handle: entity.Entity(T), callback: anytype) !void {
        try self.entities.update(T, handle, callback);
    }

    pub fn readEntity(self: *const App, comptime T: type, handle: entity.Entity(T), callback: anytype) !void {
        try self.entities.read(T, handle, callback);
    }

    pub fn getEntity(self: *App, comptime T: type, handle: entity.Entity(T)) !*T {
        return self.entities.get(T, handle);
    }

    pub fn getEntityConst(self: *const App, comptime T: type, handle: entity.Entity(T)) !*const T {
        return self.entities.getConst(T, handle);
    }

    pub fn destroyEntity(self: *App, comptime T: type, handle: entity.Entity(T)) !void {
        try self.entities.destroy(T, handle);
    }

    pub fn setWindowRoot(self: *App, id: WindowId, root: entity.AnyEntity) void {
        if (self.window(id)) |record| {
            record.root = root;
        }
    }

    pub fn liveWindowCount(self: *const App) usize {
        var count: usize = 0;
        for (self.windows.items) |record| {
            if (record.live) count += 1;
        }
        return count;
    }

    fn firstLiveWindow(self: *const App) ?WindowId {
        for (self.windows.items) |record| {
            if (record.live) return record.id;
        }
        return null;
    }

    fn processWindowEvents(self: *App) void {
        for (self.runtime_app.recentEvents()) |event| {
            switch (event) {
                .window_resized => |ev| {
                    for (self.windows.items) |*record| {
                        if (record.live and record.platform_window == ev.window) {
                            record.size = ev.size;
                            break;
                        }
                    }
                },
                else => {},
            }
        }
    }
};

pub const Application = struct {
    app: App,

    pub fn init(allocator: std.mem.Allocator, platform_impl: platform.Platform) Application {
        return .{
            .app = App.init(allocator, platform_impl),
        };
    }

    pub fn deinit(self: *Application) void {
        self.app.deinit();
    }

    pub fn run(self: *Application, bootstrap: anytype) !void {
        try bootstrap(&self.app);
        while (self.app.liveWindowCount() > 0 and !self.app.shouldQuit()) {
            try self.app.frame();
        }
    }

    pub fn runOneFrame(self: *Application, bootstrap: anytype) !void {
        try bootstrap(&self.app);
        try self.app.frame();
    }

    pub fn state(self: *Application) *App {
        return &self.app;
    }
};

test "application app tracks windows and typed roots" {
    const allocator = std.testing.allocator;
    var test_platform_state = platform.@"test".TestPlatformState{};
    var test_platform = platform.@"test".TestPlatform.init(&test_platform_state);
    var app = App.init(allocator, test_platform.asPlatform());
    defer app.deinit();

    const View = struct { title: []const u8 };

    const root = try app.createEntity(View, .{ .title = "dashboard" });
    const window_id = try app.openWindow(.{
        .title = "Main",
        .root = root.asAny(),
    });

    try std.testing.expectEqual(@as(usize, 1), app.liveWindowCount());
    try std.testing.expectEqualStrings("Main", app.window(window_id).?.title);
    try std.testing.expectEqual(root.id, app.window(window_id).?.root.?.id);
    try std.testing.expect(app.window(window_id).?.platform_window != platform.invalid_window_handle);

    try app.closeWindow(window_id);
    try std.testing.expectEqual(@as(usize, 0), app.liveWindowCount());
}

test "application wrapper bootstraps one frame" {
    const allocator = std.testing.allocator;
    var test_platform_state = platform.@"test".TestPlatformState{};
    var test_platform = platform.@"test".TestPlatform.init(&test_platform_state);
    var application = Application.init(allocator, test_platform.asPlatform());
    defer application.deinit();

    const Model = struct { value: usize };

    try application.runOneFrame(struct {
        fn bootstrap(app: *App) !void {
            _ = try app.openWindow(.{ .title = "Boot" });
            _ = try app.createEntity(Model, .{ .value = 42 });
        }
    }.bootstrap);

    try std.testing.expectEqual(@as(usize, 1), application.state().liveWindowCount());
}

test "application delegates clipboard and cursor services" {
    const allocator = std.testing.allocator;
    var test_platform_state = platform.@"test".TestPlatformState{};
    var test_platform = platform.@"test".TestPlatform.init(&test_platform_state);
    var app = App.init(allocator, test_platform.asPlatform());
    defer app.deinit();

    try app.setCursorStyle(.text);
    try std.testing.expectEqual(platform.CursorStyle.text, test_platform_state.cursor_style);

    try app.writeClipboardText("workspace");
    const clipboard = (try app.readClipboardText()).?;
    defer allocator.free(clipboard);
    try std.testing.expectEqualStrings("workspace", clipboard);

    const metrics = try app.textSystem().measure("hello", .{});
    try std.testing.expectEqual(@as(usize, 5), metrics.glyph_count);
}
