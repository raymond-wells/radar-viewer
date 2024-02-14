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

//! Built-in color tables provided by the NOAA Weather and Climate Toolkit
//! (WCT). See ACKNOWLEDGEMENTS for details.
pub const color_tables = struct {
    pub const nexrad_l3_p94 = @embedFile("nexrad_l3_p94.wctpal");
    pub const nexrad_l3_p99 = @embedFile("nexrad_l3_p99.wctpal");
    pub const nexrad_l3_p161 = @embedFile("nexrad_l3_p161.wctpal");
};

pub const license = @embedFile("license_statement.txt");
pub const resources = @embedFile("resources.gresource");
pub const radar_sites = @import("radar_sites.zig").radar_site_locations;
