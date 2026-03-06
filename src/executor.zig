const std = @import("std");

pub const TaskFn = *const fn (ctx: *anyopaque) void;

pub const QueuedTask = struct {
    callback: TaskFn,
    ctx: *anyopaque,
};

pub const TaskScheduler = struct {
    allocator: std.mem.Allocator,
    mutex: std.atomic.Mutex = .unlocked,
    ui_queue: std.ArrayList(QueuedTask) = .empty,

    pub fn init(allocator: std.mem.Allocator) TaskScheduler {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TaskScheduler) void {
        self.ui_queue.deinit(self.allocator);
    }

    pub fn postToUi(self: *TaskScheduler, callback: TaskFn, ctx: *anyopaque) !void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        try self.ui_queue.append(self.allocator, .{
            .callback = callback,
            .ctx = ctx,
        });
    }

    pub fn drainUi(self: *TaskScheduler) void {
        var local: std.ArrayList(QueuedTask) = .empty;
        defer local.deinit(self.allocator);

        lock(&self.mutex);
        local = self.ui_queue;
        self.ui_queue = .empty;
        unlock(&self.mutex);

        for (local.items) |task| {
            task.callback(task.ctx);
        }
    }

    pub fn spawnTask(self: *TaskScheduler, callback: TaskFn, ctx: *anyopaque) !void {
        _ = self;
        const thread = try std.Thread.spawn(.{}, runDetached, .{ callback, ctx });
        thread.detach();
    }
};

fn runDetached(callback: TaskFn, ctx: *anyopaque) void {
    callback(ctx);
}

fn lock(mutex: *std.atomic.Mutex) void {
    while (!mutex.tryLock()) {
        std.atomic.spinLoopHint();
    }
}

fn unlock(mutex: *std.atomic.Mutex) void {
    mutex.unlock();
}

test "task scheduler drains queued ui tasks" {
    const allocator = std.testing.allocator;
    var scheduler = TaskScheduler.init(allocator);
    defer scheduler.deinit();

    const Counter = struct {
        value: usize = 0,
        fn run(ctx: *anyopaque) void {
            var self: *@This() = @ptrCast(@alignCast(ctx));
            self.value += 1;
        }
    };

    var counter = Counter{};
    try scheduler.postToUi(Counter.run, &counter);
    try std.testing.expectEqual(@as(usize, 0), counter.value);
    scheduler.drainUi();
    try std.testing.expectEqual(@as(usize, 1), counter.value);
}
