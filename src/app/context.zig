const std = @import("std");
const application = @import("application.zig");
const entity_mod = @import("entity.zig");
const platform = @import("../platform/mod.zig");
const text = @import("../text/mod.zig");

pub fn Context(comptime T: type) type {
    return struct {
        app: *application.App,
        handle: entity_mod.Entity(T),

        pub fn init(app: *application.App, handle: entity_mod.Entity(T)) @This() {
            return .{
                .app = app,
                .handle = handle,
            };
        }

        pub fn appState(self: @This()) *application.App {
            return self.app;
        }

        pub fn entityId(self: @This()) entity_mod.EntityId {
            return self.handle.id;
        }

        pub fn entity(self: @This()) entity_mod.Entity(T) {
            return self.handle;
        }

        pub fn get(self: *@This()) !*T {
            return self.app.getEntity(T, self.handle);
        }

        pub fn getConst(self: *const @This()) !*const T {
            return self.app.getEntityConst(T, self.handle);
        }

        pub fn update(self: *@This(), callback: anytype) !void {
            callback(try self.app.getEntity(T, self.handle), self);
        }

        pub fn read(self: *const @This(), callback: anytype) !void {
            callback(try self.app.getEntityConst(T, self.handle), self);
        }

        pub fn destroy(self: *@This()) !void {
            try self.app.destroyEntity(T, self.handle);
        }

        pub fn textSystem(self: *@This()) *text.TextSystem {
            return self.app.textSystem();
        }

        pub fn setCursorStyle(self: *@This(), style: platform.CursorStyle) !void {
            try self.app.setCursorStyle(style);
        }

        pub fn readClipboardText(self: *@This()) !?[]u8 {
            return self.app.readClipboardText();
        }

        pub fn writeClipboardText(self: *@This(), value: []const u8) !void {
            try self.app.writeClipboardText(value);
        }
    };
}

test "typed app context updates entities and forwards platform services" {
    const allocator = std.testing.allocator;
    var headless_state = platform.HeadlessPlatformState{};
    var app = application.App.init(allocator, platform.Platform.initHeadlessWithState(&headless_state));
    defer app.deinit();

    const Counter = struct { value: usize };
    const CounterContext = Context(Counter);

    const counter = try app.createEntity(Counter, .{ .value = 2 });
    var cx = CounterContext.init(&app, counter);

    try cx.update(struct {
        fn run(value: *Counter, context: *CounterContext) void {
            _ = context;
            value.value += 5;
        }
    }.run);
    try std.testing.expectEqual(@as(usize, 7), (try cx.get()).value);

    try cx.setCursorStyle(.text);
    try std.testing.expectEqual(platform.CursorStyle.text, headless_state.cursor_style);

    try cx.writeClipboardText("hello");
    const clipboard = (try cx.readClipboardText()).?;
    defer allocator.free(clipboard);
    try std.testing.expectEqualStrings("hello", clipboard);

    const metrics = try cx.textSystem().measure("hello", .{});
    try std.testing.expectEqual(@as(usize, 5), metrics.glyph_count);
}
