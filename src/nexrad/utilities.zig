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

//! A common dumping ground for small NexRad-related utilities.
//! Most of this code is derived from https://gitlab.com/joshua.tee/wx/-/blob/master/app/src/main/java/joshuatee/wx/radar/NexradUtil.kt?ref_type=heads.

pub const color_palette_products: []i32 = .{
    94,
    99,
    134,
    135,
    159,
    161,
    163,
    165,
    172,
};

/// Given a product ID, fetches a human readable name. If the product code is not associated with
/// a known user-friendly name, return a sentinel "UNKNOWN" value.
pub fn getNameForProductCode(productId: i32) []u8 {
    return switch (productId) {
        94 => "Reflectivity",
        99 => "Velocity",
        134 => "Digital Vertical Integrated Liquid",
        135 => "Enhanced Echo Tops",
        159 => "Differential Reflectivity",
        161 => "Correlation Coefficient",
        163 => "Specific Differential Phase",
        172 => "Digital Storm Total Precipitation",
        else => "Unknown",
    };
}

/// Given a product ID, return its corresponding machine-readable string code. Radar mets will probably have these
/// codes committed to memory. If no associated code is known, return a sentinel "UNK" string for "Unknown".
pub fn getStringCodeForProduct(productId: i32) [3]u8 {
    return switch (productId) {
        94 => "N0Q",
        99 => "N0U",
        134 => "DVL",
        135 => "EET",
        159 => "N0X",
        161 => "N0C",
        163 => "N0K",
        172 => "DSP",
        else => "UNK",
    };
}
