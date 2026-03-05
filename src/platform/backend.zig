const std = @import("std");
const runtime_events = @import("../runtime/events.zig");
const render = @import("../render/mod.zig");

pub const PollEventsFn = *const fn (
    ctx: *anyopaque,
    queue: *std.ArrayList(runtime_events.Event),
    allocator: std.mem.Allocator,
) anyerror!void;

pub const PresentFn = *const fn (
    ctx: *anyopaque,
    commands: []const render.DrawCommand,
) anyerror!void;

pub const Backend = struct {
    ctx: *anyopaque,
    poll_events_fn: PollEventsFn,
    present_fn: PresentFn,

    pub fn pollEvents(
        self: Backend,
        queue: *std.ArrayList(runtime_events.Event),
        allocator: std.mem.Allocator,
    ) !void {
        try self.poll_events_fn(self.ctx, queue, allocator);
    }

    pub fn present(self: Backend, commands: []const render.DrawCommand) !void {
        try self.present_fn(self.ctx, commands);
    }

    pub fn initNull() Backend {
        return .{
            .ctx = &null_ctx,
            .poll_events_fn = nullPollEvents,
            .present_fn = nullPresent,
        };
    }
};

const NullContext = struct {};
var null_ctx = NullContext{};

fn nullPollEvents(
    ctx: *anyopaque,
    queue: *std.ArrayList(runtime_events.Event),
    allocator: std.mem.Allocator,
) !void {
    _ = ctx;
    _ = queue;
    _ = allocator;
}

fn nullPresent(ctx: *anyopaque, commands: []const render.DrawCommand) !void {
    _ = ctx;
    _ = commands;
}
