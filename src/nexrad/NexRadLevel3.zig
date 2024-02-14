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

//! NexRad Level 3 offers highly compressed, low-resolution products at a faster rate than level 2.
//! Reference: https://gitlab.com/joshua.tee/wx/-/blob/master/app/src/main/java/joshuatee/wx/radar/NexradLevel3.kt
//! Much of this code derived from Joshua Tee's excellent wX Project.
//! See also https://www.roc.noaa.gov/WSR88D/PublicDocs/ICDs/2620001AB.pdf for canonical information
//! about NexRad data.

const std = @import("std");
const utilities = @import("utilities.zig");
const defs = @import("definitions.zig");
const bzip2 = @import("bzip2.zig");
const Self = @This();

/// Radar products support up to 460km at 1/4km resolution.
const max_range_bin_count = 460 * 4;

allocator: std.mem.Allocator,
arena: ?*std.heap.ArenaAllocator = null,
header_loaded: bool = false,
product_loaded: bool = false,
radial_data: []u8 = undefined,
radial_starts: []f64 = undefined,
radial_deltas: []f64 = undefined,
num_radials: u32 = undefined,
num_data_points: usize = 0,
radial_affinity: []u32 = undefined,
index_of_first_range_bin: i16 = undefined,
product_code: i16 = 94,
range_scale_factor: f32 = 0.0,
num_range_bins: u16 = 0,
compressed_file_size: usize = 0,
radar_height: i16 = 0,
operational_mode: i16 = 0,
volume_coverage_pattern: i16 = 0,
volume_scan_date: i16 = 0,
volume_scan_number: i16 = 0,
volume_scan_time: i32 = 0,
radar_latitude: f32 = 0.0,
radar_longitude: f32 = 0.0,
sweep_i: i16 = 0,
sweep_j: i16 = 0,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.arena) |arena| {
        arena.deinit();
        self.allocator.destroy(self.arena.?);
        self.arena = null;
    }
}

/// Attempts to decode an entire radar data file, including the header.
pub fn decodeFile(self: *Self, reader: anytype) !void {
    if (!self.header_loaded) {
        try self.decodeHeader(reader);
    }

    if (self.arena == null) {
        self.arena = try self.allocator.create(std.heap.ArenaAllocator);
        self.arena.?.* = std.heap.ArenaAllocator.init(self.allocator);
    }

    try self.decodeDigitalRadialProduct(reader);
}

/// Decodes only the header, which may be useful for certain applications that
/// only need access to radar metadata without decoding the raw radial data.
pub fn decodeHeader(self: *Self, reader: anytype) !void {
    while (try reader.readInt(i16, .big) != -1) {}
    self.radar_latitude = @as(f32, @floatFromInt(try reader.readInt(i32, .big))) / 1000.0;
    self.radar_longitude = @as(f32, @floatFromInt(try reader.readInt(i32, .big))) / 1000.0;
    self.radar_height = try reader.readInt(i16, .big);
    self.product_code = try reader.readInt(i16, .big);

    self.operational_mode = try reader.readInt(i16, .big);
    self.volume_coverage_pattern = try reader.readInt(i16, .big);

    _ = try reader.readInt(u16, .big);

    self.volume_scan_number = try reader.readInt(i16, .big);
    self.volume_scan_date = try reader.readInt(i16, .big);
    self.volume_scan_time = try reader.readInt(i32, .big);

    // Compressed data beginns at offset 150.
    try reader.skipBytes(74, .{});
    self.header_loaded = true;
}

/// Attmepts to decode Digital Radial Data Packet code 16, containing 8 bit radial
/// products from the provided reader. These are bzip2 compressed.
fn decodeDigitalRadialProduct(self: *Self, reader: anytype) !void {
    var bzip2Stream = try bzip2.decompressReader(self.allocator, reader);
    defer bzip2Stream.deinit();
    var bzip2Reader = bzip2Stream.reader();

    // Verify that the message type & packet code are the correct ones.
    // Otherwise we may get garbage data. In the future we may need to iterate through
    // products and branch based on these codes. For now we'll skip the rest of the header
    // as we're going to infer sizes from the radial data itself.
    //
    // In the future, we may need to support files with multiple messages.
    try bzip2Reader.skipBytes(3, .{});
    const message_type = try bzip2Reader.readInt(u8, .big);
    if (message_type != @intFromEnum(defs.MessageType.DigitalRadarData)) {
        return error.UnsupportedProductType;
    }
    try bzip2Reader.skipBytes(12, .{});

    const packet_code = try bzip2Reader.readInt(u16, .big);
    if (packet_code != 0x10) {
        return error.UnsupportedGraphicPacketCode;
    }

    self.index_of_first_range_bin = try bzip2Reader.readInt(i16, .big);
    self.num_range_bins = try bzip2Reader.readInt(u16, .big);

    self.sweep_i = try bzip2Reader.readInt(i16, .big);
    self.sweep_j = try bzip2Reader.readInt(i16, .big);
    self.range_scale_factor = @as(f32, @floatFromInt(try bzip2Reader.readInt(u16, .big))) / 1000.0;

    const allocator = self.arena.?.allocator();
    self.num_radials = try bzip2Reader.readInt(u16, .big);
    self.radial_data = try allocator.alloc(u8, self.num_range_bins * self.num_radials);
    self.radial_starts = try allocator.alloc(f64, self.num_radials);
    self.radial_deltas = try allocator.alloc(f64, self.num_radials);
    self.radial_affinity = try allocator.alloc(u32, self.num_range_bins * self.num_radials);

    var expected_byte_count: u16 = 0;
    var read_head: usize = 0;
    var bytes_read: usize = 0;

    for (0..self.num_radials) |radial| {
        expected_byte_count = try bzip2Reader.readInt(u16, .big);
        self.radial_starts[radial] = @as(f64, @floatFromInt(try bzip2Reader.readInt(i16, .big))) / 10.0;
        self.radial_deltas[radial] = @as(f64, @floatFromInt(try bzip2Reader.readInt(i16, .big))) / 10.0;

        const bytes_to_read = @min(expected_byte_count, self.num_range_bins);
        bytes_read = try bzip2Reader.read(self.radial_data[read_head .. read_head + bytes_to_read]);

        // At higher tilts, the RPG may clip data-- resulting in a byte count of # of range bins + 1. In these cases,
        // we're not interested in this extraneous data, so we can disregard it.
        if (expected_byte_count > bytes_to_read) {
            try bzip2Reader.skipBytes(expected_byte_count - bytes_to_read, .{});
        }

        // For the sake of correctness, handle the theoretical case that a radial might specify less than the
        // count of range bins of data. This should not happen, but it is possible given the strictures of the format.
        if (bytes_to_read < self.num_range_bins) {
            read_head += @intCast(self.num_range_bins - expected_byte_count);
        }

        @memset(self.radial_affinity[read_head .. read_head + self.num_range_bins], @intCast(radial));
        read_head += bytes_read;
    }

    self.num_data_points = read_head;
    self.product_loaded = true;
}

/// Returns the volume scan date/time combination as the number of seconds after `1970-01-01 00:00 UTC`.
pub fn getEpochalRadarTime(self: Self) u64 {
    return @as(u64, @intCast(self.volume_scan_date - 1)) * 86400 + @as(u64, @intCast(self.volume_scan_time));
}

test "Decode Radar Image" {
    // Skip this test at the moment, as it requires a real radar image
    // that is not provided within the Git repository. Will rewrite this
    // test later on to use a generated artifact.
    if (true) {
        return error.SkipZigTest;
    }

    var level3 = Self.init(std.testing.allocator);
    defer level3.deinit();

    var file = try std.fs.cwd().openFile("assets/test-radar.bin", .{});
    defer file.close();

    var bufReader = std.io.bufferedReader(file.reader());
    const stream = bufReader.reader();

    try level3.decodeFile(stream);

    try std.testing.expectEqual(@round(level3.radar_latitude), 35);
    try std.testing.expectEqual(@round(level3.radar_longitude), -97);
    try std.testing.expectEqual(level3.radar_height, 1277);
    try std.testing.expectEqual(level3.product_code, 94);
    try std.testing.expectEqual(level3.volume_scan_number, 39);

    // The expected time of the radar scan:
    // datetime.datetime.utcfromtimestamp(0) + datetime.timedelta(days=19737) + datetime.timedelta(seconds=80766) = datetime.datetime(2024, 1, 15, 22, 26, 6)
    try std.testing.expectEqual(level3.volume_scan_date, 19737);
    try std.testing.expectEqual(level3.volume_scan_time, 80766);
    try std.testing.expectEqual(level3.getEpochalRadarTime(), 1705357566);
    try std.testing.expectEqual(level3.num_radials, 360);
    try std.testing.expectEqual(level3.num_range_bins, 460);
}
