const std = @import("std");

pub const EffectId = enum(u32) {
    _,

    pub fn index(self: EffectId) usize {
        return @as(usize, @intCast(@intFromEnum(self) - 1));
    }

    pub fn fromIndex(idx: usize) EffectId {
        return @enumFromInt(@as(u32, @intCast(idx + 1)));
    }
};

pub const EffectCallback = *const fn (ctx: *anyopaque) void;

const EffectEntry = struct {
    callback: EffectCallback,
    ctx: *anyopaque,
    dirty: bool = true,
    active: bool = true,
};

pub const Reactor = struct {
    allocator: std.mem.Allocator,
    effects: std.ArrayList(EffectEntry) = .empty,
    pending: std.ArrayList(EffectId) = .empty,
    batch_depth: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Reactor {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Reactor) void {
        self.effects.deinit(self.allocator);
        self.pending.deinit(self.allocator);
    }

    pub fn createEffect(
        self: *Reactor,
        callback: EffectCallback,
        ctx: *anyopaque,
    ) !EffectId {
        const id = EffectId.fromIndex(self.effects.items.len);
        try self.effects.append(self.allocator, .{
            .callback = callback,
            .ctx = ctx,
            .dirty = true,
            .active = true,
        });
        try self.pending.append(self.allocator, id);
        if (self.batch_depth == 0) self.flush();
        return id;
    }

    pub fn disposeEffect(self: *Reactor, id: EffectId) void {
        self.effects.items[id.index()].active = false;
    }

    pub fn markDirty(self: *Reactor, id: EffectId) !void {
        const entry = &self.effects.items[id.index()];
        if (!entry.active or entry.dirty) return;
        entry.dirty = true;
        try self.pending.append(self.allocator, id);
        if (self.batch_depth == 0) self.flush();
    }

    pub fn beginBatch(self: *Reactor) void {
        self.batch_depth += 1;
    }

    pub fn endBatch(self: *Reactor) void {
        std.debug.assert(self.batch_depth > 0);
        self.batch_depth -= 1;
        if (self.batch_depth == 0) self.flush();
    }

    pub fn flush(self: *Reactor) void {
        var cursor: usize = 0;
        while (cursor < self.pending.items.len) : (cursor += 1) {
            const id = self.pending.items[cursor];
            const entry = &self.effects.items[id.index()];
            if (!entry.active or !entry.dirty) continue;
            entry.dirty = false;
            entry.callback(entry.ctx);
        }
        self.pending.clearRetainingCapacity();
    }
};

pub fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        reactor: ?*Reactor = null,
        subscribers: std.ArrayList(EffectId) = .empty,

        pub fn init(value: T) Self {
            return .{
                .value = value,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.subscribers.deinit(allocator);
        }

        pub fn attach(self: *Self, reactor: *Reactor) void {
            self.reactor = reactor;
        }

        pub fn subscribe(self: *Self, allocator: std.mem.Allocator, effect_id: EffectId) !void {
            for (self.subscribers.items) |existing| {
                if (existing == effect_id) return;
            }
            try self.subscribers.append(allocator, effect_id);
        }

        pub fn get(self: *const Self) T {
            return self.value;
        }

        pub fn set(self: *Self, value: T) !bool {
            if (std.meta.eql(self.value, value)) return false;
            self.value = value;
            if (self.reactor) |reactor| {
                for (self.subscribers.items) |effect_id| {
                    try reactor.markDirty(effect_id);
                }
            }
            return true;
        }
    };
}

test "signal notifies effect and batching coalesces updates" {
    const allocator = std.testing.allocator;
    var reactor = Reactor.init(allocator);
    defer reactor.deinit();

    const Counter = struct {
        runs: usize = 0,
        fn onEffect(ctx: *anyopaque) void {
            var self: *@This() = @ptrCast(@alignCast(ctx));
            self.runs += 1;
        }
    };

    var counter = Counter{};
    const effect_id = try reactor.createEffect(Counter.onEffect, &counter);
    try std.testing.expectEqual(@as(usize, 1), counter.runs);

    var signal = Signal(i32).init(0);
    defer signal.deinit(allocator);
    signal.attach(&reactor);
    try signal.subscribe(allocator, effect_id);

    try std.testing.expect(try signal.set(1));
    try std.testing.expectEqual(@as(usize, 2), counter.runs);

    reactor.beginBatch();
    _ = try signal.set(2);
    _ = try signal.set(3);
    try std.testing.expectEqual(@as(usize, 2), counter.runs);
    reactor.endBatch();
    try std.testing.expectEqual(@as(usize, 3), counter.runs);
}
