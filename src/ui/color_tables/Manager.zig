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

//!
//! The Color Table Manager provides a point of interaction with color tables, mappings by which
//! the radar viewer application turns raw radar data values into RGBA pixel values for redering on screen.
//!
//! The color table manager will need to support importing color tables, which involves pre-computing the
//! look-up tables.
//!
const std = @import("std");
const gobject = @import("../gobject.zig");
const nexrad = @import("../../nexrad.zig");
const defs = @import("definitions.zig");
const gio = @import("../async.zig");
const lib = @import("../../lib.zig");
const assets = @import("../../assets/bundled_assets.zig");
const c = lib.c;

const Entry = @import("Entry.zig");

const Self = @This();

const ImportColorTableFromFileTask = gio.asyncTaskWrapper(
    Self.importColorTableFromFileThread,
    Self.importColorTableFinished,
);

const ImportColorTableFromBufferTask = gio.asyncTaskWrapper(
    Self.importColorTableFromBufferThread,
    Self.importColorTableFinished,
);

parent: c.GObject,
allocator: std.mem.Allocator,
entry_list: std.ArrayListUnmanaged(*lib.AutoBoxed(Entry)),
product_association: [defs.number_of_products]?usize = .{null} ** defs.number_of_products,

pub usingnamespace gobject.RegisterType(
    Self,
    &c.g_object_get_type,
    "RadarViewerColorTableManager",
    &.{},
);

pub const Class = struct {
    parent_class: c.GObjectClass,
};

/// Instantiates a new instance as a `GObject`. Caller is responsible for
/// freeing data via `g_object_unref`.
pub fn new(allocator: std.mem.Allocator) *Self {
    const self: *Self = @alignCast(@ptrCast(c.g_object_new(Self.getType(), null)));
    self.allocator = allocator;
    return self;
}

pub fn init(self: *Self) void {
    self.entry_list = .{};
}

pub fn finalize(self: *Self) void {
    for (self.entry_list.items) |entry| {
        entry.unref();
    }
    self.entry_list.deinit(self.allocator);
}

///
/// Attempts to load a series of built-in hardcoded color tables. This is a *blocking* operation
/// which *may* (but should not ever) fail silently.
///
pub fn loadDefaultColorTables(self: *Self) void {
    inline for (@typeInfo(assets.color_tables).Struct.decls) |table_field_decl| {
        const table = @field(assets.color_tables, table_field_decl.name);
        const task = ImportColorTableFromBufferTask.runInTaskThreadSync(self, c.g_bytes_new(table.ptr, table.len));
        defer c.g_object_unref(task);

        self.importColorTableFinished(@ptrCast(task), null);
    }
}

/// Attempts to asynchronously import a color table from a file at the given path.
///
/// * `path` *must* be an **absolute** path.
pub fn importColorTableFromFile(self: *Self, path: []const u8) void {
    const task = ImportColorTableFromFileTask.runInTaskThread(
        self,
        c.g_string_new_len(path.ptr, path.len),
    );
    defer c.g_object_unref(task);
}

/// Updates the color table listing and if necessary the product association mapping after a successful import.
/// If import unsuccessful, logs a message to the console.
fn importColorTableFinished(
    self: *Self,
    result: *c.GAsyncResult,
    data: c.gpointer,
) void {
    var g_error: ?*c.GError = null;
    const maybe_entry: ?*lib.AutoBoxed(Entry) = @alignCast(@ptrCast(c.g_task_propagate_pointer(
        @ptrCast(result),
        @ptrCast(&g_error),
    )));
    defer if (maybe_entry) |entry| entry.unref();

    if (g_error) |error_value| {
        c.g_log(
            "org.rwells.RadarViewer",
            c.G_LOG_LEVEL_INFO,
            "Color Table Failed to Import: %s",
            error_value.message,
        );
        c.g_error_free(g_error);
        return;
    }
    _ = data;
    self.entry_list.append(self.allocator, maybe_entry.?.ref()) catch {
        c.g_log(
            "org.rwells.RadarViewer",
            c.G_LOG_LEVEL_INFO,
            "Color Table Failed to Import",
        );
        return;
    };

    c.g_log(
        "org.rwells.RadarViewer",
        c.G_LOG_LEVEL_DEBUG,
        "Loaded Color Table.",
    );
    const p_assoc = &self.product_association[@intFromEnum(maybe_entry.?.value.product)];
    if (p_assoc.* == null) {
        p_assoc.* = self.entry_list.items.len - 1;
        c.g_log(
            "org.rwells.RadarViewer",
            c.G_LOG_LEVEL_DEBUG,
            "Set default for product #%d.",
            @as(usize, @intCast(@intFromEnum(maybe_entry.?.value.product))),
        );
    }
}

fn importColorTableFromFileThread(_: *c.GTask, self: *Self, absolute_file_path: *c.GString, _: *c.GCancellable) !*lib.AutoBoxed(Entry) {
    const file = try std.fs.openFileAbsolute(gobject.gStringToSlice(absolute_file_path), .{});
    defer file.close();

    return self.importColorTableFromReader(file.reader());
}

fn importColorTableFromBufferThread(_: *c.GTask, self: *Self, buffer: *c.GBytes, _: *c.GCancellable) !*lib.AutoBoxed(Entry) {
    var stream = std.io.fixedBufferStream(gobject.gBytesToSlice(buffer));
    defer c.g_bytes_unref(buffer);

    return self.importColorTableFromReader(stream.reader());
}

/// Given a `std.io.Reader` providing access to raw color table data, parse the color table and
/// generate a look-up table for use when rendering images.
fn importColorTableFromReader(self: *Self, reader: anytype) !*lib.AutoBoxed(Entry) {
    var entry = try lib.AutoBoxed(Entry).create(self.allocator, .{
        .table = try nexrad.ColorTable.parseColorTable(self.allocator, reader),
        .lut = std.mem.zeroes([256]@Vector(4, f64)),
        .product = .BaseReflectivity,
    });

    entry.value.product = defs.ProductCodeToAssociation.get(
        entry.value.table.product.constSlice(),
    ) orelse .BaseReflectivity;

    const range = defs.Ranges[@intFromEnum(entry.value.product)];
    const params: nexrad.models.DecodingParameters = switch (entry.value.product) {
        .EnhancedEchoTops => .{ .EchoTops = .{
            .topped_mask = 0x80,
            .data_mask = 0x7f,
            .data_scale = 1,
            .data_offset = 2,
        } },
        else => .{
            .MinWithIncrement = .{
                .min_value = range[0],
                .increment = (range[1] - range[0]) / 254.0,
                .num_levels = 254,
            },
        },
    };

    entry.value.table.populateDynamicLookupTable(
        f64,
        &entry.value.lut,
        params,
    );

    return entry;
}

/// Given a `ProductAssociation` value, attempts to get the associated color table entry, if one is
/// defined.
///
/// Caller assumes ownership of the return value and is responsible for freeing it via `.unref()`.
pub fn getEntryForProduct(self: Self, product: defs.ProductAssociation) ?*lib.AutoBoxed(Entry) {
    if (self.product_association[@intFromEnum(product)]) |idx| {
        return self.entry_list.items[idx].ref();
    }
    return null;
}

test "Type Intiailization" {
    try std.testing.expectEqualStrings(
        std.mem.sliceTo(c.g_type_name(Self.getType()), 0),
        "RadarViewerColorTableManager",
    );
}

test "Instantiation and Cleanup" {
    const instance = Self.new(std.testing.allocator);
    c.g_object_unref(@ptrCast(instance));
}

test "Import Color Table From File" {
    const instance = Self.new(std.testing.allocator);
    defer c.g_object_unref(@ptrCast(instance));
    const path: []u8 = try std.testing.allocator.alloc(u8, 1024);
    defer std.testing.allocator.free(path);
    const realpath = try std.fs.cwd().realpath("src/assets/nexrad_l3_p99.wctpal", path);
    const g_path = c.g_string_new_len(realpath.ptr, @intCast(realpath.len & 0xFFFF));
    defer _ = c.g_string_free(g_path, 1);
    const entry = try importColorTableFromFileThread(undefined, instance, g_path, undefined);
    defer entry.unref();

    try std.testing.expectEqual(.BaseVelocity, entry.value.product);
    try std.testing.expectEqual(entry.value.table.color_steps.len, 15);
    try std.testing.expectEqual(entry.value.table.color_steps[0].value, -70.0);
    try std.testing.expectEqual(entry.value.table.color_steps[14].value, 70.0);
}

test "Import Color Table Finished" {
    const instance = Self.new(std.testing.allocator);
    defer c.g_object_unref(@ptrCast(instance));
    const path: []u8 = try std.testing.allocator.alloc(u8, 1024);
    defer std.testing.allocator.free(path);
    const realpath = try std.fs.cwd().realpath("src/assets/nexrad_l3_p99.wctpal", path);
    const g_path = c.g_string_new_len(realpath.ptr, @intCast(realpath.len & 0xFFFF));
    defer _ = c.g_string_free(g_path, 1);
    const entry = try importColorTableFromFileThread(undefined, instance, g_path, undefined);

    // Note: This will grab a reference on `instance`.
    const task = c.g_task_new(@ptrCast(instance), null, null, null);
    defer c.g_object_unref(task);
    defer c.g_object_unref(@ptrCast(instance));

    c.g_task_return_pointer(task, @ptrCast(entry), null);
    instance.importColorTableFinished(@ptrCast(task), null);

    try std.testing.expectEqual(instance.entry_list.items.len, 1);
    try std.testing.expectEqual(instance.entry_list.items[0], entry);
}
