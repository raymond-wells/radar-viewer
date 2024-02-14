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
const ui = @import("ui.zig");
const c = @import("lib.zig").c;
const assets = @import("assets/bundled_assets.zig");

pub fn main() !void {
    const stderr = std.io.getStdErr();
    const writer = stderr.writer();
    try std.fmt.format(writer, assets.license, .{});
    defer stderr.close();

    const allocator = std.heap.c_allocator;
    var app = ui.Application.new(allocator);
    _ = c.g_application_run(@ptrCast(app), 0, null);
    c.g_clear_object(@ptrCast(&app));
}

test {
    _ = @import("nexrad.zig");
    _ = @import("lib.zig");
    _ = @import("ui.zig");
}
