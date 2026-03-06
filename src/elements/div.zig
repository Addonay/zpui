const style = @import("../style.zig");
const builders = @import("builders.zig");

pub fn div(node_style: style.Style) builders.NodeSpec {
    return .{
        .style = node_style,
    };
}
