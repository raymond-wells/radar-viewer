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

//! Color Table Entries associate a given color table with a precomputed
//! lookup table and a decoded product association.
const std = @import("std");
const defs = @import("definitions.zig");
const nexrad = @import("../../nexrad.zig");

const Self = @This();

table: nexrad.ColorTable,
lut: [256]@Vector(4, f64),
product: defs.ProductAssociation,

pub fn deinit(self: Self) void {
    self.table.deinit();
}
