// Radar Viewer: Open Source Viewer for NexRad Radar Data.
// Copyright (C) 2024  Raymond F. Wells
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

//! Color tables are mappings which translate raw data values taken from
//! radar products into colors for display on a radar map. Typically these values
//! comprise either a smooth gradient between measured units or a series of bands of solid colors.
const std = @import("std");
const models = @import("models.zig");
const RGBA = @Vector(4, u8);
const Self = @This();

pub const Step = struct {
    value: f32,
    color: RGBA,
    color_end: ?RGBA = null,

    fn lessThan(_: void, a: Step, b: Step) bool {
        return a.value < b.value;
    }
};

const StatementType = enum {
    Product,
    Units,
    Scale,
    Offset,
    Step,
    RF,
    Color,
    Color4,
    SolidColor,
    SolidColor4,
};

const TinyString = std.BoundedArray(u8, 16);

allocator: std.mem.Allocator,
product: TinyString,
units: TinyString,
scale: f32 = undefined,
offset: f32 = undefined,
step: f32 = undefined,
range_folded: ?RGBA,
color_steps: []Step,
unit_conversion_factor: f32 = 1.0,

/// Parses the data provided by the given `GenericReader` into a new instance. Uses an allocator to allocate
/// space for the color steps, which can be of variable number.
///
/// Color steps are *sorted in order of level*, which may or may not be the order in which they appear inside
/// of the file. This is required in order to correctly perform interpolation.
///
pub fn parseColorTable(allocator: std.mem.Allocator, reader: anytype) !Self {
    var self: Self = .{
        .allocator = allocator,
        .product = try TinyString.init(0),
        .units = try TinyString.init(0),
        .scale = 0.0,
        .offset = 0.0,
        .range_folded = null,
        .color_steps = &.{},
    };

    var color_steps = std.ArrayList(Step).init(allocator);
    defer color_steps.deinit();

    var line_buf: [1024]u8 = undefined;
    @memset(&line_buf, 0);

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        const trimmed = std.mem.trimRight(u8, std.mem.trimLeft(u8, line, " "), "\r");

        if (trimmed.len == 0 or trimmed[0] == ';' or trimmed[0] == '#') {
            continue;
        }

        var statement_iterator = std.mem.splitAny(u8, trimmed, ":");
        const statement_type = std.meta.stringToEnum(StatementType, std.mem.trim(u8, statement_iterator.first(), " "));
        const statement = std.mem.trim(u8, statement_iterator.rest(), " ");

        if (statement_type == null) {
            return error.UnknownStatementType;
        }

        switch (statement_type.?) {
            .Product => self.product = try TinyString.fromSlice(statement[0..@min(15, statement.len)]),
            .Units => self.units = try TinyString.fromSlice(statement[0..@min(15, statement.len)]),
            .Scale => self.scale = try std.fmt.parseFloat(@TypeOf(self.scale), statement),
            .Offset => self.offset = try std.fmt.parseFloat(@TypeOf(self.offset), statement),
            .Step => self.step = try std.fmt.parseFloat(@TypeOf(self.step), statement),
            .Color, .SolidColor => try color_steps.append(try parseAnyColorStep(statement, parseRgb)),
            .Color4, .SolidColor4 => try color_steps.append(try parseAnyColorStep(statement, parseRgba)),
            .RF => self.range_folded = try parseRgb(@constCast(&std.mem.splitAny(u8, statement, " "))),
        }
    }

    self.color_steps = try color_steps.toOwnedSlice();
    std.sort.heap(Step, self.color_steps, {}, Step.lessThan);

    // See if we can better handle special cases like this.
    // If we have a base velocity product, the units are expressed in
    // Knots in the color table, but m/s from the radar.
    if (std.mem.eql(u8, self.product.slice(), "BV") and std.mem.eql(u8, self.units.slice(), "KT")) {
        self.unit_conversion_factor = 0.5144447;
    }

    return self;
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.color_steps);
}

/// Gets a 256-entry lookup table useful for quickly fetching a given color by its corresponding byte value.
///
/// `max_level` and `min_level` should correspond to the actual levels of the radar product for which the color mapping is intended.
/// Caller must provide these as not all color maps will have a product declaration, and even if they did, the product field is
/// a free-form string bearing no canonical definition.
pub fn getLookupTable(self: Self, comptime T: type, allocator: std.mem.Allocator, min_level: f32, max_level: f32) ![]@Vector(4, T) {
    const table = try allocator.alloc(@Vector(4, T), 256);
    self.populateDynamicLookupTable(T, table, .{
        .MinWithIncrement = .{
            .min_value = min_level,
            .num_levels = 254,
            .increment = (max_level - min_level) / 254.0,
        },
    });
    return table;
}

/// Populates a pre-existing lookup table with interpolated values derived from the color steps
/// within the given color table, and a set of `DecodingParameters` from the product, which specify
/// how to relate te data levels therein to the physical values specified within the color table.
///
pub fn populateDynamicLookupTable(
    self: Self,
    comptime T: type,
    lut: []@Vector(4, T),
    decoding_properties: models.DecodingParameters,
) void {
    var max_level: f32 = undefined;
    var min_level: f32 = undefined;
    var increment: f32 = undefined;
    var data_units: usize = undefined;

    switch (decoding_properties) {
        .MinWithIncrement => |v| {
            increment = v.increment;
            min_level = v.min_value;
            max_level = @floatFromInt(v.num_levels);
            max_level *= increment;
            max_level += min_level;
            data_units = @intCast(v.num_levels);
        },
        .EchoTops => {
            data_units = 254;
        },
        .ScaledWithOffset => |v| {
            data_units = v.max_data_level - v.leading_flags;
        },
    }
    var level = min_level;

    lut[0] = @splat(0.0);
    lut[1] = if (self.range_folded) |range_folded| @Vector(4, T){
        @as(T, @floatFromInt(range_folded[0])),
        @as(T, @floatFromInt(range_folded[1])),
        @as(T, @floatFromInt(range_folded[2])),
        @as(T, @floatFromInt(range_folded[3])),
    } else @splat(0.0);

    switch (decoding_properties) {
        .MinWithIncrement => for (2..(data_units + 2)) |i| {
            lut[i] = self.getInterpolatedColor(T, level);
            level += increment;
        },
        .EchoTops => |v| for (2..(data_units + 2)) |i| {
            lut[i] = self.getInterpolatedColor(
                T,
                @as(f32, @floatFromInt(i & v.data_mask)) / v.data_scale - v.data_offset,
            );
        },
        .ScaledWithOffset => |v| for (v.leading_flags..(data_units + v.leading_flags)) |i| {
            lut[i] = self.getInterpolatedColor(
                T,
                (@as(f32, @floatFromInt(i)) - v.offset) / v.scale,
            );
        },
    }

    if (data_units < 254) {
        for ((data_units + 2)..256) |overflow| {
            lut[overflow] = self.getInterpolatedColor(T, level);
        }
    }
}

/// Given a raw level value, produces a blended color value taken by performing liner interpolation between its two nearest
/// color steps. Note that callers are **strongly** encouraged to use `getLookupTable()`, and to store the lookup table locally
/// rater than using this method, as this method is O(N) with respect to the number of color steps.
pub fn getInterpolatedColor(self: Self, comptime T: type, radar_level: f32) @Vector(4, T) {
    const level = radar_level * self.unit_conversion_factor;
    if (self.color_steps.len == 0 or level < self.color_steps[0].value) {
        return @Vector(4, T){ 0.0, 0.0, 0.0, 0.0 };
    }

    if (self.color_steps.len == 1) {
        return @Vector(4, T){
            @as(T, @floatFromInt(self.color_steps[0].color[0])) / 255.0,
            @as(T, @floatFromInt(self.color_steps[0].color[1])) / 255.0,
            @as(T, @floatFromInt(self.color_steps[0].color[2])) / 255.0,
            @as(T, @floatFromInt(self.color_steps[0].color[3])) / 255.0,
        };
    }

    var bottom_index: usize = 0;
    var top_index: usize = 0;
    for (self.color_steps, 0..) |step, i| {
        if (step.value > level) {
            top_index = i;
            break;
        }
        bottom_index = i;
    }

    const start_color = @Vector(4, T){
        @as(T, @floatFromInt(self.color_steps[bottom_index].color[0])) / 255.0,
        @as(T, @floatFromInt(self.color_steps[bottom_index].color[1])) / 255.0,
        @as(T, @floatFromInt(self.color_steps[bottom_index].color[2])) / 255.0,
        @as(T, @floatFromInt(self.color_steps[bottom_index].color[3])) / 255.0,
    };

    var end_color_raw = self.color_steps[bottom_index].color_end;
    if (end_color_raw == null) {
        end_color_raw = self.color_steps[top_index].color;
    }
    const end_color = @Vector(4, T){
        @as(T, @floatFromInt(end_color_raw.?[0])) / 255.0,
        @as(T, @floatFromInt(end_color_raw.?[1])) / 255.0,
        @as(T, @floatFromInt(end_color_raw.?[2])) / 255.0,
        @as(T, @floatFromInt(end_color_raw.?[3])) / 255.0,
    };

    const range = self.color_steps[top_index].value - self.color_steps[bottom_index].value;
    const dist = (level - self.color_steps[bottom_index].value);
    const fac: T = @floatCast(dist / range);
    const sfac: T = @floatCast(1.0 - fac);
    return (start_color * @as(@Vector(4, T), @splat(sfac)) + end_color * @as(@Vector(4, T), @splat(fac)));
}

/// Parses (Solid)Color(4) steps into a new `Step` instance given a raw `statement`.
inline fn parseAnyColorStep(statement: []const u8, parseColor: anytype) !Step {
    var return_value = Step{
        .value = undefined,
        .color = undefined,
        .color_end = null,
    };

    var split_statement = std.mem.splitAny(u8, statement, " ");
    return_value.value = try std.fmt.parseFloat(@TypeOf(return_value.value), nextNonEmpty(&split_statement) orelse return error.MissingValueEntry);
    return_value.color = try parseColor(&split_statement);

    if (split_statement.peek() != null) {
        return_value.color_end = try parseRgb(&split_statement);
    }

    return return_value;
}

/// Parses a tuple of 3 decimal numbers (e.g. "255 64 112") into a 4-byte vector containing the RGB color value
/// and a fixed alpha of 255 sacrificing a single byte per color for a predictable memory layout and ease of processing.
fn parseRgb(split_iterator: anytype) !RGBA {
    return RGBA{
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbValue, 10),
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbValue, 10),
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbValue, 10),
        255,
    };
}

/// Parses a tuple of 4 decimal numbers (e.g. "255 64 128 96") into a 4-byte vector containing the RGBA color value.
fn parseRgba(split_iterator: anytype) !RGBA {
    return RGBA{
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbaValue, 10),
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbaValue, 10),
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbaValue, 10),
        try std.fmt.parseInt(u8, nextNonEmpty(split_iterator) orelse return error.InvalidRgbaValue, 10),
    };
}

/// Searches the provided `split_iterator` for the next non-empty string, consumes, and returns its value.
/// Useful for parsing human-generated color map files as they may contain an arbitrary number of spaces between values.
fn nextNonEmpty(split_iterator: anytype) ?[]const u8 {
    var it = split_iterator;
    while (it.peek()) |token| {
        if (token.len > 0) {
            return it.next();
        }

        _ = it.next();
    }

    return null;
}

test "Parse Color Table: No steps" {
    const color_table = (
        \\; Test Color Table
        \\ Product: BR
        \\ Units: dbZ
    );

    var fbs = std.io.fixedBufferStream(color_table);
    const parsed_table = try parseColorTable(std.testing.allocator, fbs.reader());
    defer parsed_table.deinit();

    try std.testing.expectEqualStrings("BR", parsed_table.product.constSlice());
    try std.testing.expectEqualStrings("dbZ", parsed_table.units.constSlice());
}

test "Parse Color Table: Color Steps" {
    const color_table = (
        \\; Test Color Table
        \\ Product: BR
        \\ Units: dbZ
        \\ Step: 5.0
        \\ Color: 10 255 128 64
        \\ SolidColor: 20 16 32 64 128 192 255
    );

    var fbs = std.io.fixedBufferStream(color_table);
    const parsed_table = try parseColorTable(std.testing.allocator, fbs.reader());
    defer parsed_table.deinit();

    try std.testing.expectEqualStrings("BR", parsed_table.product.constSlice());
    try std.testing.expectEqualStrings("dbZ", parsed_table.units.constSlice());
    try std.testing.expectEqual(2, parsed_table.color_steps.len);

    try std.testing.expectEqual(10.0, parsed_table.color_steps[0].value);
    try std.testing.expectEqual(RGBA{ 255, 128, 64, 255 }, parsed_table.color_steps[0].color);
    try std.testing.expectEqual(null, parsed_table.color_steps[0].color_end);

    try std.testing.expectEqual(20.0, parsed_table.color_steps[1].value);
    try std.testing.expectEqual(RGBA{ 16, 32, 64, 255 }, parsed_table.color_steps[1].color);
    try std.testing.expectEqual(RGBA{ 128, 192, 255, 255 }, parsed_table.color_steps[1].color_end);
}

test "Color Interpolation" {
    const color_table = (
        \\; Test Color Table
        \\ Product: BR
        \\ Units: dbZ
        \\ Step: 5.0
        \\ Color: 10 255 127 63
        \\ SolidColor: 20 16 32 63 127 192 255
    );

    var fbs = std.io.fixedBufferStream(color_table);
    const parsed_table = try parseColorTable(std.testing.allocator, fbs.reader());
    defer parsed_table.deinit();

    const result = parsed_table.getInterpolatedColor(f32, 10.0);
    try std.testing.expectApproxEqAbs(1.0, result[0], 0.01);
    try std.testing.expectApproxEqAbs(0.5, result[1], 0.01);
    try std.testing.expectApproxEqAbs(0.25, result[2], 0.01);
    try std.testing.expectApproxEqAbs(1.0, result[3], 0.01);
}

test "Get Lookup Table" {
    var fs = try std.fs.cwd().openFile("src/assets/nexrad_l3_p94.wctpal", .{});
    defer fs.close();
    const parsed_table = try parseColorTable(std.testing.allocator, fs.reader());
    defer parsed_table.deinit();

    const lut = try parsed_table.getLookupTable(f32, std.testing.allocator, -32.0, 95.0);
    defer std.testing.allocator.free(lut);
}
