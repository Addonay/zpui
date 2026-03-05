const std = @import("std");

pub const EntityId = enum(u32) {
    _,

    pub fn index(self: EntityId) usize {
        return @as(usize, @intCast(@intFromEnum(self) - 1));
    }

    pub fn fromIndex(idx: usize) EntityId {
        return @enumFromInt(@as(u32, @intCast(idx + 1)));
    }
};

pub const AnyEntity = struct {
    id: EntityId,
    type_token: TypeToken,
};

pub fn Entity(comptime T: type) type {
    return struct {
        id: EntityId,

        pub fn asAny(self: @This()) AnyEntity {
            return .{
                .id = self.id,
                .type_token = typeToken(T),
            };
        }
    };
}

pub fn Reservation(comptime T: type) type {
    return struct {
        id: EntityId,

        pub fn entity(self: @This()) Entity(T) {
            return .{ .id = self.id };
        }
    };
}

pub const EntityStore = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,

    pub fn init(allocator: std.mem.Allocator) EntityStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *EntityStore) void {
        for (self.entries.items) |*entry| {
            entry.release(self.allocator);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn reserve(self: *EntityStore, comptime T: type) !Reservation(T) {
        const id = EntityId.fromIndex(self.entries.items.len);
        try self.entries.append(self.allocator, Entry.init(T));
        return .{ .id = id };
    }

    pub fn insertReserved(
        self: *EntityStore,
        comptime T: type,
        reservation: Reservation(T),
        value: T,
    ) !Entity(T) {
        const entry = try self.entryFor(T, reservation.id);
        if (entry.live_value) return error.EntityAlreadyInitialized;

        const ptr = try self.allocator.create(T);
        ptr.* = value;
        entry.ptr = ptr;
        entry.live_value = true;
        return reservation.entity();
    }

    pub fn create(self: *EntityStore, comptime T: type, value: T) !Entity(T) {
        const reservation = try self.reserve(T);
        return try self.insertReserved(T, reservation, value);
    }

    pub fn get(self: *EntityStore, comptime T: type, handle: Entity(T)) !*T {
        const entry = try self.entryFor(T, handle.id);
        if (!entry.live_value or entry.ptr == null) return error.EntityNotInitialized;
        return @ptrCast(@alignCast(entry.ptr.?));
    }

    pub fn getConst(self: *const EntityStore, comptime T: type, handle: Entity(T)) !*const T {
        const entry = try self.entryForConst(T, handle.id);
        if (!entry.live_value or entry.ptr == null) return error.EntityNotInitialized;
        return @ptrCast(@alignCast(entry.ptr.?));
    }

    pub fn update(self: *EntityStore, comptime T: type, handle: Entity(T), callback: anytype) !void {
        callback(try self.get(T, handle));
    }

    pub fn read(self: *const EntityStore, comptime T: type, handle: Entity(T), callback: anytype) !void {
        callback(try self.getConst(T, handle));
    }

    pub fn destroy(self: *EntityStore, comptime T: type, handle: Entity(T)) !void {
        const entry = try self.entryFor(T, handle.id);
        entry.release(self.allocator);
    }

    fn entryFor(self: *EntityStore, comptime T: type, id: EntityId) !*Entry {
        if (id.index() >= self.entries.items.len) return error.EntityNotFound;
        const entry = &self.entries.items[id.index()];
        if (entry.type_token != typeToken(T)) return error.EntityTypeMismatch;
        return entry;
    }

    fn entryForConst(self: *const EntityStore, comptime T: type, id: EntityId) !*const Entry {
        if (id.index() >= self.entries.items.len) return error.EntityNotFound;
        const entry = &self.entries.items[id.index()];
        if (entry.type_token != typeToken(T)) return error.EntityTypeMismatch;
        return entry;
    }
};

const TypeToken = *const fn () void;

const Entry = struct {
    type_token: TypeToken,
    ptr: ?*anyopaque = null,
    destroy: *const fn (std.mem.Allocator, *anyopaque) void,
    live_value: bool = false,

    fn init(comptime T: type) Entry {
        return .{
            .type_token = typeToken(T),
            .destroy = destroyFn(T),
        };
    }

    fn release(self: *Entry, allocator: std.mem.Allocator) void {
        if (!self.live_value or self.ptr == null) return;
        self.destroy(allocator, self.ptr.?);
        self.ptr = null;
        self.live_value = false;
    }
};

fn typeToken(comptime T: type) TypeToken {
    return &struct {
        fn token() void {
            _ = T;
        }
    }.token;
}

fn destroyFn(comptime T: type) *const fn (std.mem.Allocator, *anyopaque) void {
    return &struct {
        fn destroy(allocator: std.mem.Allocator, ptr: *anyopaque) void {
            const typed: *T = @ptrCast(@alignCast(ptr));
            if (comptime @hasDecl(T, "deinit")) {
                const params = @typeInfo(@TypeOf(@field(T, "deinit"))).@"fn".params;
                if (comptime params.len == 2) {
                    typed.deinit(allocator);
                } else {
                    typed.deinit();
                }
            }
            allocator.destroy(typed);
        }
    }.destroy;
}

test "entity store creates and updates typed entities" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const Counter = struct { value: usize };

    const counter = try store.create(Counter, .{ .value = 1 });
    try std.testing.expectEqual(@as(usize, 1), (try store.get(Counter, counter)).value);

    try store.update(Counter, counter, struct {
        fn run(value: *Counter) void {
            value.value += 4;
        }
    }.run);
    try std.testing.expectEqual(@as(usize, 5), (try store.get(Counter, counter)).value);
}

test "entity store supports reservations before insertion" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const Settings = struct { dark_mode: bool };

    const reservation = try store.reserve(Settings);
    try std.testing.expectError(error.EntityNotInitialized, store.get(Settings, reservation.entity()));

    const handle = try store.insertReserved(Settings, reservation, .{ .dark_mode = true });
    try std.testing.expect((try store.get(Settings, handle)).dark_mode);
}

test "entity store rejects type mismatches" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const A = struct { value: u8 };
    const B = struct { value: u8 };

    const handle = try store.create(A, .{ .value = 7 });
    const wrong: Entity(B) = .{ .id = handle.id };

    try std.testing.expectError(error.EntityTypeMismatch, store.get(B, wrong));
}

test "entity store calls deinit on types that own resources" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const OwnedList = struct {
        items: std.ArrayList(u8) = .empty,

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            self.items.deinit(alloc);
        }
    };

    const handle = try store.create(OwnedList, .{});
    const ptr = try store.get(OwnedList, handle);
    try ptr.items.append(allocator, 1);
    try ptr.items.append(allocator, 2);

    // destroy should call deinit, freeing the ArrayList buffer
    // std.testing.allocator will detect leaks if deinit is not called
    try store.destroy(OwnedList, handle);
}
