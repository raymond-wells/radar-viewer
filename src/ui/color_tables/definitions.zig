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
};

pub const ProductCodeToAssociation = std.ComptimeStringMap(
    ProductAssociation,
    &.{
        .{ "BR", .BaseReflectivity },
        .{ "BV", .BaseVelocity },
        .{ "CC", .CorrelationCoefficient },
    },
);

pub const Ranges: [@typeInfo(ProductAssociation).Enum.fields.len]struct { f32, f32 } = .{
    .{ -32.0, 95.0 },
    .{ -247.0, 245.0 },
    .{ 0.2, 1.05 },
};

pub const number_of_products = std.enums.values(ProductAssociation).len;
