const app = @import("app/mod.zig");

// This port stage still models views as entity-backed window roots.
pub fn View(comptime T: type) type {
    return app.Entity(T);
}

pub const AnyView = app.AnyEntity;
