const std = @import("std");
const geometry = @import("../geometry.zig");
const input = @import("../input.zig");
const scene = @import("../scene.zig");
const text = @import("../text_system/mod.zig");

pub const PollEventsFn = *const fn (
    ctx: *anyopaque,
    queue: *std.ArrayList(input.Event),
    allocator: std.mem.Allocator,
) anyerror!void;

pub const PresentFn = *const fn (
    ctx: *anyopaque,
    commands: []const scene.DrawCommand,
) anyerror!void;

pub const WindowHandle = u64;
pub const invalid_window_handle: WindowHandle = 0;

pub const WindowOptions = struct {
    title: []const u8 = "zpui",
    size: geometry.Size = .{ .width = 960, .height = 640 },
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
        queue: *std.ArrayList(input.Event),
        allocator: std.mem.Allocator,
    ) !void {
        try self.poll_events_fn(self.ctx, queue, allocator);
    }

    pub fn present(self: Platform, commands: []const scene.DrawCommand) !void {
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
};
