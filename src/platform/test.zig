const std = @import("std");
const backend = @import("backend.zig");
const input = @import("../input.zig");
const scene = @import("../scene.zig");
const text = @import("../text_system/mod.zig");

pub const TestPlatformState = struct {
    next_window_handle: backend.WindowHandle = 1,
    clipboard_buf: [2048]u8 = undefined,
    clipboard_len: usize = 0,
    cursor_style: backend.CursorStyle = .default,
};

pub const TestPlatform = struct {
    state: *TestPlatformState,

    pub fn init(state: *TestPlatformState) TestPlatform {
        return .{ .state = state };
    }

    pub fn asPlatform(self: *TestPlatform) backend.Platform {
        return .{
            .ctx = self.state,
            .poll_events_fn = pollEvents,
            .present_fn = present,
            .open_window_fn = openWindow,
            .close_window_fn = closeWindow,
            .set_cursor_style_fn = setCursorStyle,
            .read_clipboard_text_fn = readClipboardText,
            .write_clipboard_text_fn = writeClipboardText,
            .text_system_fn = textSystem,
        };
    }
};

fn pollEvents(
    ctx: *anyopaque,
    queue: *std.ArrayList(input.Event),
    allocator: std.mem.Allocator,
) !void {
    _ = ctx;
    _ = queue;
    _ = allocator;
}

fn present(ctx: *anyopaque, commands: []const scene.DrawCommand) !void {
    _ = ctx;
    _ = commands;
}

fn openWindow(ctx: *anyopaque, options: backend.WindowOptions) !backend.WindowHandle {
    const state: *TestPlatformState = @ptrCast(@alignCast(ctx));
    _ = options;
    const handle = state.next_window_handle;
    state.next_window_handle += 1;
    return handle;
}

fn closeWindow(ctx: *anyopaque, window: backend.WindowHandle) !void {
    _ = ctx;
    _ = window;
}

fn setCursorStyle(ctx: *anyopaque, style: backend.CursorStyle) !void {
    const state: *TestPlatformState = @ptrCast(@alignCast(ctx));
    state.cursor_style = style;
}

fn readClipboardText(
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
) !?[]u8 {
    const state: *TestPlatformState = @ptrCast(@alignCast(ctx));
    if (state.clipboard_len == 0) return null;
    return try allocator.dupe(u8, state.clipboard_buf[0..state.clipboard_len]);
}

fn writeClipboardText(ctx: *anyopaque, value: []const u8) !void {
    const state: *TestPlatformState = @ptrCast(@alignCast(ctx));
    if (value.len > state.clipboard_buf.len) return error.ClipboardTooLarge;
    @memcpy(state.clipboard_buf[0..value.len], value);
    state.clipboard_len = value.len;
}

fn textSystem(ctx: *anyopaque) text.PlatformTextSystem {
    _ = ctx;
    return text.PlatformTextSystem.initNoop();
}

test "test platform exposes platform services" {
    const allocator = std.testing.allocator;
    var state = TestPlatformState{};
    var platform_impl = TestPlatform.init(&state);
    const platform_api = platform_impl.asPlatform();

    const first = try platform_api.openWindow(.{ .title = "One" });
    const second = try platform_api.openWindow(.{ .title = "Two" });
    try std.testing.expect(first != backend.invalid_window_handle);
    try std.testing.expect(second == first + 1);

    try platform_api.setCursorStyle(.text);
    try std.testing.expectEqual(backend.CursorStyle.text, state.cursor_style);

    try platform_api.writeClipboardText("clipboard");
    const clipboard = (try platform_api.readClipboardText(allocator)).?;
    defer allocator.free(clipboard);
    try std.testing.expectEqualStrings("clipboard", clipboard);

    const metrics = try platform_api.textSystem().measure("hello", .{});
    try std.testing.expectEqual(@as(usize, 5), metrics.glyph_count);
}
