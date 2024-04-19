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
//
//! NexRAD data are compressed scans of weather radar (typically WSR-88D installations) data. Data are organized into one or more "products", which correspond to different
//! types of information inferred from raw radar beam data. NexRAD data arrives compressed at various levels:
//!
//! Level 1 -- Raw Uncompressed data, unavailable at the current time.
//! Level 2 -- High-resolution data, more expensive to decode & process, but finer-grained. Useful for identifying smaller scale features.
//! Level 3 -- Low-resolution data, less expensive to decode & process, typically contains higher-level analysis products at the cost of resolution.
pub const NexradLevel3 = @import("nexrad/NexRadLevel3.zig");
pub const ColorTable = @import("nexrad/ColorTable.zig");
pub const utilities = @import("nexrad/utilities.zig");
pub const io = @import("nexrad/io.zig");
pub const definitions = @import("nexrad/definitions.zig");
pub const products = @import("nexrad/products.zig");
pub const models = @import("nexrad/models.zig");

test {
    _ = @import("nexrad/definitions.zig");
    _ = @import("nexrad/products.zig");
    _ = @import("nexrad/io.zig");
    _ = @import("nexrad/NexRadLevel3.zig");
    _ = @import("nexrad/bzip2.zig");
    _ = @import("nexrad/ColorTable.zig");
}
