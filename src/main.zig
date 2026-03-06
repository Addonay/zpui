const std = @import("std");

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print(
        "Native platform startup is not implemented yet. TestPlatform remains available only for tests.\n",
        .{},
    );
    return error.NativePlatformNotImplemented;
}
