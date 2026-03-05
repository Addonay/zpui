const std = @import("std");
const core = @import("../core/mod.zig");
const runtime_events = @import("../runtime/events.zig");
const render = @import("../render/mod.zig");
const text = @import("../text/mod.zig");

pub const PollEventsFn = *const fn (
    ctx: *anyopaque,
    queue: *std.ArrayList(runtime_events.Event),
    allocator: std.mem.Allocator,
) anyerror!void;

pub const PresentFn = *const fn (
    ctx: *anyopaque,
    commands: []const render.DrawCommand,
) anyerror!void;

pub const WindowHandle = u64;
pub const invalid_window_handle: WindowHandle = 0;

pub const WindowOptions = struct {
    title: []const u8 = "zpui",
    size: core.Size = .{ .width = 960, .height = 640 },
    resizable: bool = true,
};

pub const CursorStyle = enum {
    default,
    pointer,
    text,
    crosshair,
    move,
    resize_horizontal,
    resize_vertical,
};

pub const OpenWindowFn = *const fn (
    ctx: *anyopaque,
    options: WindowOptions,
) anyerror!WindowHandle;

pub const CloseWindowFn = *const fn (
    ctx: *anyopaque,
    window: WindowHandle,
) anyerror!void;

pub const SetCursorStyleFn = *const fn (
    ctx: *anyopaque,
    style: CursorStyle,
) anyerror!void;

pub const ReadClipboardTextFn = *const fn (
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
) anyerror!?[]u8;

pub const WriteClipboardTextFn = *const fn (
    ctx: *anyopaque,
    value: []const u8,
) anyerror!void;

pub const TextSystemFn = *const fn (
    ctx: *anyopaque,
) text.PlatformTextSystem;

pub const Platform = struct {
    ctx: *anyopaque,
    poll_events_fn: PollEventsFn,
    present_fn: PresentFn,
    open_window_fn: OpenWindowFn,
    close_window_fn: CloseWindowFn,
    set_cursor_style_fn: SetCursorStyleFn,
    read_clipboard_text_fn: ReadClipboardTextFn,
    write_clipboard_text_fn: WriteClipboardTextFn,
    text_system_fn: TextSystemFn,

    pub fn pollEvents(
        self: Platform,
        queue: *std.ArrayList(runtime_events.Event),
        allocator: std.mem.Allocator,
    ) !void {
        try self.poll_events_fn(self.ctx, queue, allocator);
    }

    pub fn present(self: Platform, commands: []const render.DrawCommand) !void {
        try self.present_fn(self.ctx, commands);
    }

    pub fn openWindow(self: Platform, options: WindowOptions) !WindowHandle {
        return self.open_window_fn(self.ctx, options);
    }

    pub fn closeWindow(self: Platform, window: WindowHandle) !void {
        try self.close_window_fn(self.ctx, window);
    }

    pub fn setCursorStyle(self: Platform, style: CursorStyle) !void {
        try self.set_cursor_style_fn(self.ctx, style);
    }

    pub fn readClipboardText(
        self: Platform,
        allocator: std.mem.Allocator,
    ) !?[]u8 {
        return self.read_clipboard_text_fn(self.ctx, allocator);
    }

    pub fn writeClipboardText(self: Platform, value: []const u8) !void {
        try self.write_clipboard_text_fn(self.ctx, value);
    }

    pub fn textSystem(self: Platform) text.PlatformTextSystem {
        return self.text_system_fn(self.ctx);
    }

    pub fn initHeadlessWithState(state: *HeadlessPlatformState) Platform {
        return .{
            .ctx = state,
            .poll_events_fn = headlessPollEvents,
            .present_fn = headlessPresent,
            .open_window_fn = headlessOpenWindow,
            .close_window_fn = headlessCloseWindow,
            .set_cursor_style_fn = headlessSetCursorStyle,
            .read_clipboard_text_fn = headlessReadClipboardText,
            .write_clipboard_text_fn = headlessWriteClipboardText,
            .text_system_fn = headlessTextSystem,
        };
    }
};

pub const HeadlessPlatformState = struct {
    next_window_handle: WindowHandle = 1,
    clipboard_buf: [2048]u8 = undefined,
    clipboard_len: usize = 0,
    cursor_style: CursorStyle = .default,
};

fn headlessPollEvents(
    ctx: *anyopaque,
    queue: *std.ArrayList(runtime_events.Event),
    allocator: std.mem.Allocator,
) !void {
    _ = ctx;
    _ = queue;
    _ = allocator;
}

fn headlessPresent(ctx: *anyopaque, commands: []const render.DrawCommand) !void {
    _ = ctx;
    _ = commands;
}

fn headlessOpenWindow(ctx: *anyopaque, options: WindowOptions) !WindowHandle {
    const state: *HeadlessPlatformState = @ptrCast(@alignCast(ctx));
    _ = options;
    const handle = state.next_window_handle;
    state.next_window_handle += 1;
    return handle;
}

fn headlessCloseWindow(ctx: *anyopaque, window: WindowHandle) !void {
    _ = ctx;
    _ = window;
}

fn headlessSetCursorStyle(ctx: *anyopaque, style: CursorStyle) !void {
    const state: *HeadlessPlatformState = @ptrCast(@alignCast(ctx));
    state.cursor_style = style;
}

fn headlessReadClipboardText(
    ctx: *anyopaque,
    allocator: std.mem.Allocator,
) !?[]u8 {
    const state: *HeadlessPlatformState = @ptrCast(@alignCast(ctx));
    if (state.clipboard_len == 0) return null;
    return @as(?[]u8, try allocator.dupe(u8, state.clipboard_buf[0..state.clipboard_len]));
}

fn headlessWriteClipboardText(ctx: *anyopaque, value: []const u8) !void {
    const state: *HeadlessPlatformState = @ptrCast(@alignCast(ctx));
    if (value.len > state.clipboard_buf.len) return error.ClipboardTooLarge;
    @memcpy(state.clipboard_buf[0..value.len], value);
    state.clipboard_len = value.len;
}

fn headlessTextSystem(ctx: *anyopaque) text.PlatformTextSystem {
    _ = ctx;
    return text.PlatformTextSystem.initNoop();
}

test "headless platform exposes platform services" {
    const allocator = std.testing.allocator;
    var state = HeadlessPlatformState{};
    const platform_impl = Platform.initHeadlessWithState(&state);

    const first = try platform_impl.openWindow(.{ .title = "One" });
    const second = try platform_impl.openWindow(.{ .title = "Two" });
    try std.testing.expect(first != invalid_window_handle);
    try std.testing.expect(second == first + 1);

    try platform_impl.setCursorStyle(.text);
    try std.testing.expectEqual(CursorStyle.text, state.cursor_style);

    try platform_impl.writeClipboardText("clipboard");
    const clipboard = (try platform_impl.readClipboardText(allocator)).?;
    defer allocator.free(clipboard);
    try std.testing.expectEqualStrings("clipboard", clipboard);

    const metrics = try platform_impl.textSystem().measure("hello", .{});
    try std.testing.expectEqual(@as(usize, 5), metrics.glyph_count);
}
