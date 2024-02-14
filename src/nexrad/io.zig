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

//! A dumping ground for utility methods for reading and decoding NexRad Radar Data.
const std = @import("std");
const defs = @import("definitions.zig");
const nws_pub_radar_url_prefix = "https://tgftp.nws.noaa.gov";

const known_prefixes_by_radar_site = std.ComptimeStringMap(u8, &.{
    .{ "JUA", 't' },
    .{ "HKI", 'p' },
    .{ "HMO", 'p' },
    .{ "HKM", 'p' },
    .{ "HWA", 'p' },
    .{ "APD", 'p' },
    .{ "ACG", 'p' },
    .{ "AIH", 'p' },
    .{ "AHG", 'p' },
    .{ "AKC", 'p' },
    .{ "ABC", 'p' },
    .{ "AEC", 'p' },
    .{ "GUA", 'p' },
});

pub fn getRidPrefix(radar_site: []const u8) u8 {
    if (known_prefixes_by_radar_site.get(radar_site)) |known| {
        return known;
    }

    return 'k';
}

/// Attempts to fetch the NexRad Level 3 data URL for the latest scan of the provided radar product. The "product code" here is
/// the string product code.
pub fn getRadarFileUrl(buffer: []u8, radar_site: []const u8, product_code: []const u8) ![]u8 {
    var lower_buf: [4:0]u8 = .{0} ** 4;
    const lowercase_radar_site = std.ascii.lowerString(&lower_buf, radar_site);
    return try std.fmt.bufPrint(buffer, "{s}/SL.us008001/DF.of/DC.radar/{s}/SI.{s}/sn.last", .{
        nws_pub_radar_url_prefix,
        try defs.getDSCodeForProductCode(product_code),
        lowercase_radar_site,
    });
}

test "getRadarFileUrl: Known product" {
    const url_buffer: []u8 = try std.testing.allocator.alloc(u8, 2048);
    defer std.testing.allocator.free(url_buffer);
    try std.testing.expectEqualStrings(
        "https://tgftp.nws.noaa.gov/SL.us008001/DF.of/DC.radar/DS.p94r0/SI.ktlx/sn.last",
        try getRadarFileUrl(url_buffer, "KTLX", "N0Q"),
    );
}

test "getRadarFileUrl: Unknown Product" {
    const url_buffer = try std.testing.allocator.alloc(u8, 2048);
    defer std.testing.allocator.free(url_buffer);
    try std.testing.expectError(
        error.@"Unknown product code",
        getRadarFileUrl(url_buffer, "KTLX", "OOPS"),
    );
}
