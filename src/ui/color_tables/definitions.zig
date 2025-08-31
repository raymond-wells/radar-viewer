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
pub const ProductAssociation = enum {
    BaseReflectivity,
    BaseVelocity,
    CorrelationCoefficient,
    EnhancedEchoTops,
    DifferentialReflectivity,
    SpecificDifferentialPhase,
};

pub const ProductCodeToAssociation = std.StaticStringMap(ProductAssociation).initComptime(
    &.{
        .{ "BR", .BaseReflectivity },
        .{ "BV", .BaseVelocity },
        .{ "CC", .CorrelationCoefficient },
        .{ "EET", .EnhancedEchoTops },
        .{ "DR", .DifferentialReflectivity },
        .{ "SDP", .SpecificDifferentialPhase },
    },
);

/// Static ranges, deprecated as static ranges are the "old way" of decoding values.
/// The new data level decoding scheme will use dynamic LUTs to support more accurate
/// conversion of data, at the cost of a little performance.
pub const Ranges: [@typeInfo(ProductAssociation).@"enum".fields.len]struct { f32, f32 } = .{
    .{ -32.0, 95.0 },
    .{ -247.0, 245.0 },
    .{ 0.2, 1.05 },
    .{ 0.0, 75.0 },
    .{ -8.0, 8.0 },
    .{ 0.0, 45.0 },
};

pub const number_of_products = std.enums.values(ProductAssociation).len;
