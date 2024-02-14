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

const std = @import("std");

pub const MessageType = enum(u8) {
    Unknown = 0,
    DigitalRadarData = 1,
};

const product_code_to_product_string = std.ComptimeStringMap([]const u8, .{
    .{ "N0R", "DS.p19r0" },
    .{ "N1R", "DS.p19r1" },
    .{ "N2R", "DS.p19r2" },
    .{ "N3R", "DS.p19r3" },
    .{ "NSP", "DS.p28sw" },
    .{ "NSW", "DS.p30sw" },
    .{ "N0Q", "DS.p94r0" },
    .{ "N1Q", "DS.p94r1" },
    .{ "N2Q", "DS.p94r2" },
    .{ "N3Q", "DS.p94r3" },
    .{ "N0V", "DS.p27v0" },
    .{ "N1V", "DS.p27v1" },
    .{ "N2V", "DS.p27v2" },
    .{ "N3V", "DS.p27v3" },
    .{ "NCR", "DS.p37cr" },
    .{ "NCZ", "DS.p38cr" },
    .{ "ET", "DS.p41et" },
    .{ "N0U", "DS.p99v0" },
    .{ "N1U", "DS.p99v1" },
    .{ "N2U", "DS.p99v2" },
    .{ "N3U", "DS.p99v3" },
    .{ "N0S", "DS.56rm0" },
    .{ "N1S", "DS.56rm1" },
    .{ "N2S", "DS.56rm2" },
    .{ "N3S", "DS.56rm3" },
    .{ "VIL", "DS.57vil" },
    .{ "STI", "DS.58sti" },
    .{ "TVS", "DS.61tvs" },
    .{ "HI", "DS.p59hi" },
    .{ "DVL", "DS.134il" },
    .{ "EET", "DS.135et" },
    .{ "DSP FIXME", "DS.138dp" },
    .{ "TZ0", "DS.180z0" },
    .{ "TZ1", "DS.180z1" },
    .{ "TZ2", "DS.180z2" },
    .{ "TR0", "DS.181r0" },
    .{ "TR1", "DS.181r1" },
    .{ "TR2", "DS.181r2" },
    .{ "TR3", "DS.181r3" },
    .{ "TV0", "DS.182v0" },
    .{ "TV1", "DS.182v1" },
    .{ "TV2", "DS.182v2" },
    .{ "TV3", "DS.182v3" },
    .{ "TZL", "DS.186zl" },
    .{ "N1P", "DS.78ohp" },
    .{ "NTP", "DS.80stp" },
    .{ "NVL", "DS.57vil" },
    .{ "N0X", "DS.159x0" },
    .{ "N1X", "DS.159x1" },
    .{ "N2X", "DS.159x2" },
    .{ "N3X", "DS.159x3" },
    .{ "N0C", "DS.161c0" },
    .{ "N1C", "DS.161c1" },
    .{ "N2C", "DS.161c2" },
    .{ "N3C", "DS.161c3" },
    .{ "N0K", "DS.163k0" },
    .{ "N1K", "DS.163k1" },
    .{ "N2K", "DS.163k2" },
    .{ "N3K", "DS.163k3" },
    .{ "DAA", "DS.170aa" },
    .{ "DSA", "DS.172dt" },
    .{ "DSP", "DS.172dt" },
    .{ "H0C", "DS.165h0" },
    .{ "H1C", "DS.165h1" },
    .{ "H2C", "DS.165h2" },
    .{ "H3C", "DS.165h3" },
    .{ "VWP", "DS.48vwp" },
    .{ "N0B", "DS.00n1b" },
    .{ "N0G", "DS.00n1g" },
});

pub fn getDSCodeForProductCode(product_code: []const u8) ![]const u8 {
    if (product_code_to_product_string.get(product_code)) |ds_code| {
        return ds_code;
    }

    return error.@"Unknown product code";
}

test "getDSCodeForProductCode: Known" {
    try std.testing.expectEqualStrings("DS.00n1g", try getDSCodeForProductCode("N0G"));
}

test "getDSCodeForProductCode: Unknown" {
    try std.testing.expectError(error.@"Unknown product code", getDSCodeForProductCode("OOPS"));
}
