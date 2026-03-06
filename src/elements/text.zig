const style = @import("../style.zig");
const builders = @import("builders.zig");

pub fn text(content: []const u8, node_style: style.Style) builders.NodeSpec {
    return builders.text(content, node_style);
}
