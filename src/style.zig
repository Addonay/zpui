const geometry = @import("geometry.zig");

pub const Display = enum {
    flex,
    grid,
    stack,
    text,
    custom,
};

pub const Wrap = enum {
    no_wrap,
    wrap,
};

pub const Justify = enum {
    start,
    center,
    end,
    space_between,
};

pub const Style = struct {
    display: Display = .flex,
    direction: geometry.Axis = .column,
    wrap: Wrap = .no_wrap,
    align_items: geometry.Align = .start,
    justify_content: Justify = .start,
    gap: f32 = 0,
    row_gap: ?f32 = null,
    column_gap: ?f32 = null,
    width: ?f32 = null,
    height: ?f32 = null,
    min_width: ?f32 = null,
    min_height: ?f32 = null,
    max_width: ?f32 = null,
    max_height: ?f32 = null,
    padding: geometry.EdgeInsets = .{},
    margin: geometry.EdgeInsets = .{},
    background: ?geometry.Color = null,
    text_color: ?geometry.Color = null,
    border_radius: f32 = 0,
    border_width: f32 = 0,
    border_color: ?geometry.Color = null,
    grid_columns: u16 = 1,
    grid_rows: u16 = 0,

    pub fn row() Style {
        return .{
            .display = .flex,
            .direction = .row,
        };
    }

    pub fn column() Style {
        return .{
            .display = .flex,
            .direction = .column,
        };
    }

    pub fn grid(columns: u16) Style {
        return .{
            .display = .grid,
            .grid_columns = if (columns == 0) 1 else columns,
        };
    }

    pub fn stack() Style {
        return .{
            .display = .stack,
        };
    }
};
