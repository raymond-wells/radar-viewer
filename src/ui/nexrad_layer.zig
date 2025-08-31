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
const lib = @import("../lib.zig");
const c = lib.c;
const gobject = @import("gobject.zig");
const gio = @import("async.zig");
const nexrad = @import("../nexrad.zig");
const color_tables = @import("color_tables.zig");
const RadarDataProvider = @import("radar_data_provider.zig").RadarDataProvider;

/// Provides a Shumate Layer which displays NexRad radar information for a given site / product combination.
///
/// Caveats:
/// * Single product display at a time.
/// * Cannot display products underneath roads / city names. Instead, uses alpha blending to
///   ensure that information is somewhat visible below.
/// * Does not handle map rotation.
///
pub const NexradLayer = struct {
    parent: c.ShumateLayer,
    allocator: std.mem.Allocator,
    provider: *RadarDataProvider,
    radar_latitude: f64,
    radar_longitude: f64,
    should_draw: bool = false,
    radar_surface: *c.cairo_surface_t,
    radar_paintable: *c.GdkPaintable,
    radial_length_meters: f32 = 0.0,
    internal_surface_size: c_int,
    color_table_manager: *color_tables.Manager,

    const Point = @Vector(2, f64);
    const GPoint = @Vector(2, f32);
    const BoxedRadarData = lib.AutoBoxed(nexrad.NexradLevel3);
    const Self = @This();

    pub usingnamespace gobject.RegisterType(Self, &c.shumate_layer_get_type, "NexradLayer", &.{});

    pub const Class = extern struct {
        parent: c.ShumateLayerClass,

        pub fn initClass(self: *Class) callconv(.C) void {
            const widget_class: *c.GtkWidgetClass = @ptrCast(self);

            widget_class.snapshot = @ptrCast(&onSnapshot);
        }
    };

    pub fn new(viewport: ?*c.ShumateViewport, allocator: std.mem.Allocator, provider: *RadarDataProvider, manager: *color_tables.Manager) *Self {
        const self: *Self = @alignCast(@ptrCast(c.g_object_new(
            Self.getType(),
            "viewport",
            viewport,
            gobject.end_of_args,
        )));
        self.allocator = allocator;
        self.provider = provider;
        self.color_table_manager = manager;

        _ = c.g_signal_connect_data(
            self.provider,
            "data-updated",
            @ptrCast(&onRadarDataUpdated),
            self,
            null,
            c.G_CONNECT_SWAPPED,
        );
        _ = c.g_signal_connect_data(
            viewport,
            "notify",
            @ptrCast(&onViewportChanged),
            self,
            null,
            c.G_CONNECT_SWAPPED,
        );

        return self;
    }

    pub fn init(self: *Self) callconv(.C) void {
        self.internal_surface_size = 20480;
        self.should_draw = false;
        self.initSurface();
    }

    pub fn finalize(self: *Self) callconv(.C) void {
        c.cairo_surface_destroy(self.radar_surface);
    }

    pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    pub fn setProperty(self: *Self, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {
        _ = self;
    }

    ///
    /// When the user zooms or pans the viewport, the application will need to redraw the layer.
    ///
    fn onViewportChanged(self: *Self, _: *c.GParamSpec, _: *c.ShumateViewport) callconv(.C) void {
        c.gtk_widget_queue_draw(@ptrCast(self));
    }

    ///
    /// Renders the internal radar texture to the widget at the correct location.
    ///
    fn onSnapshot(self: *Self, snapshot: *c.GtkSnapshot) callconv(.C) void {
        if (!self.should_draw) {
            return;
        }
        const radial_length_meters = self.radial_length_meters;
        const viewport: *c.ShumateViewport = c.shumate_layer_get_viewport(@ptrCast(self)).?;
        var radar_coords: Point = .{ 0.0, 0.0 };
        c.shumate_viewport_location_to_widget_coords(
            viewport,
            @ptrCast(self),
            self.radar_latitude,
            self.radar_longitude,
            &radar_coords[0],
            &radar_coords[1],
        );

        var radar_top: Point = undefined;
        c.shumate_viewport_location_to_widget_coords(
            viewport,
            @ptrCast(self),
            self.radar_latitude + 2.0 * (radial_length_meters / 1.110447e+5),
            self.radar_longitude - 2.0 * (radial_length_meters / (111321.0 * std.math.cos(self.radar_latitude * std.math.pi / 180.0))),
            &radar_top[0],
            &radar_top[1],
        );

        var radar_bottom: Point = undefined;
        c.shumate_viewport_location_to_widget_coords(
            viewport,
            @ptrCast(self),
            self.radar_latitude - 2.0 * (radial_length_meters / 1.110447e+5),
            self.radar_longitude + 2.0 * (radial_length_meters / (111321.0 * std.math.cos(self.radar_latitude * std.math.pi / 180.0))),
            &radar_bottom[0],
            &radar_bottom[1],
        );

        const radar_width = @abs(radar_bottom[0] - radar_top[0]);
        const radar_height = @abs(radar_bottom[1] - radar_top[1]);

        var radar_offset: GPoint = .{
            @floatCast(radar_coords[0]),
            @floatCast(radar_coords[1]),
        };
        radar_offset -= GPoint{ @floatCast(radar_width / 2.0), @floatCast(radar_height / 2.0) };

        c.gtk_snapshot_save(snapshot);
        c.gtk_snapshot_push_opacity(snapshot, 0.65);
        c.gtk_snapshot_append_texture(
            snapshot,
            @ptrCast(self.radar_paintable),
            &.{
                .origin = .{ .x = radar_offset[0], .y = radar_offset[1] },
                .size = .{ .width = @floatCast(radar_width), .height = @floatCast(radar_height) },
            },
        );
        c.gtk_snapshot_pop(snapshot);
        c.gtk_snapshot_restore(snapshot);
    }

    /// Intializes a Cairo surface on which to draw a texture containing the current radar image
    /// alongside a GdkPaintable sharing the same memory space, to use with drawing via `onSnapshot`.
    ///
    /// Calls to Cairo are expensive, so it's much cheaper to draw the radar image once to a raster layer,
    /// then rely on Gsk to display the raster layer efficiently. Since the texture is shared between
    /// Cairo and Gsk, there is no need to copy data.
    fn initSurface(self: *Self) void {
        self.radar_surface = c.cairo_image_surface_create(
            c.CAIRO_FORMAT_ARGB32,
            self.internal_surface_size,
            self.internal_surface_size,
        ).?;

        self.resetPaintable();
    }

    /// Triggers a re-draw of the backing radar image texture upon new data received from the provider.
    fn onRadarDataUpdated(self: *Self, data_ptr: *BoxedRadarData, _: c.gpointer, _: c.gpointer) callconv(.C) void {
        const radar_data = &data_ptr.value;
        self.should_draw = false;
        self.radar_latitude = radar_data.radar_latitude;
        self.radar_longitude = radar_data.radar_longitude;
        self.radial_length_meters = switch (radar_data.product_code) {
            94 => 230000.0,
            99, 159, 161 => 150012.1,
            180, 182 => 44448.02,
            135 => 172236.1,
            else => 0.0,
        };
        const task = gio.asyncTaskWrapper(
            radarTextureUpdateThread,
            radarTextureUpdateFinished,
        ).runInTaskThread(self, data_ptr.ref());
        defer c.g_object_unref(task);
    }

    fn radarTextureUpdateThread(_: *c.GTask, self: *Self, radar_data: *BoxedRadarData, _: *c.GCancellable) !void {
        try self.redrawRadarTexture(&radar_data.value);
    }

    fn radarTextureUpdateFinished(self: *Self, result: *c.GAsyncResult, _: *anyopaque) callconv(.C) void {
        // Since we created a reference to the radar data at the task call site,
        // we'll need to release the reference corresponding reference here in order to ensure
        // that it get cleaned up properly.
        const boxed: *BoxedRadarData = @alignCast(@ptrCast(c.g_task_get_task_data(@ptrCast(result))));
        boxed.unref();

        var g_error: ?*c.GError = null;
        _ = c.g_task_propagate_boolean(@ptrCast(result), &g_error);

        if (g_error) |error_value| {
            c.g_log(
                null,
                c.G_LOG_LEVEL_WARNING,
                "Failed to update radar due to an error: %s",
                error_value.message,
            );
            c.g_error_free(g_error);
            return;
        }

        self.should_draw = true;
        self.resetPaintable();
        c.gtk_widget_queue_draw(@ptrCast(self));
    }

    /// Takes the currently loaded radar image and draws the radial data to the internal radar surface.
    fn redrawRadarTexture(self: *Self, radar_data: *nexrad.NexradLevel3) !void {
        const surface_size: f64 = @floatFromInt(self.internal_surface_size);
        const surface_diameter: f64 = @as(f64, @floatFromInt(radar_data.num_range_bins)) * 2.0;
        const scale_fac = surface_size / surface_diameter;
        const context = c.cairo_create(self.radar_surface) orelse return error.@"Failed to create cairo context.";
        defer c.cairo_destroy(context);

        const product: color_tables.ProductAssociation = switch (radar_data.product_code) {
            94, 180 => .BaseReflectivity,
            99, 182 => .BaseVelocity,
            161 => .CorrelationCoefficient,
            135 => .EnhancedEchoTops,
            159 => .DifferentialReflectivity,
            else => .BaseReflectivity,
        };

        const color_table = self.color_table_manager.getEntryForProduct(product) orelse return error.NoColorTableForProduct;
        defer color_table.unref();

        var dynamic_lut: [256]@Vector(4, f64) = undefined;
        var lut: []@Vector(4, f64) = undefined;

        if (radar_data.decoding_parameters) |parameters| {
            color_table.value.table.populateDynamicLookupTable(f64, &dynamic_lut, parameters);
            lut = &dynamic_lut;
        } else {
            lut = &color_table.value.lut;
        }

        c.cairo_set_source_rgba(context, 0.0, 0.0, 0.0, 0.0);
        c.cairo_set_operator(context, c.CAIRO_OPERATOR_SOURCE);
        c.cairo_paint(context);

        c.cairo_set_operator(context, c.CAIRO_OPERATOR_OVER);

        c.cairo_translate(context, surface_size / 2.0, surface_size / 2.0);
        c.cairo_scale(context, scale_fac, scale_fac);

        var range_bin: u64 = 0;
        var radial: u64 = 0;
        for (
            radar_data.radial_data[0..radar_data.num_data_points],
            0..,
        ) |data, i| {
            range_bin = i % @as(u64, @intCast(radar_data.num_range_bins));
            radial += @intFromBool(i > 0 and range_bin == 0);

            if (data == 0) {
                continue;
            }
            c.cairo_new_sub_path(context);
            c.cairo_arc(
                context,
                0.0,
                0.0,
                @floatFromInt(range_bin),
                (radar_data.radial_starts[radial] * std.math.pi / 180.0) - 2.0 * std.math.pi / 4.0,
                ((radar_data.radial_starts[radial] + radar_data.radial_deltas[radial]) * std.math.pi / 180.0) - 2.0 * std.math.pi / 4.0,
            );
            c.cairo_arc_negative(
                context,
                0.0,
                0.0,
                @floatFromInt(range_bin + 1),
                ((radar_data.radial_starts[radial] + radar_data.radial_deltas[radial]) * std.math.pi / 180.0) - 2.0 * std.math.pi / 4.0,
                (radar_data.radial_starts[radial] * std.math.pi / 180.0) - 2.0 * std.math.pi / 4.0,
            );
            c.cairo_close_path(context);
            const color = lut[@as(usize, @intCast(data))];
            c.cairo_set_source_rgba(
                context,
                color[0],
                color[1],
                color[2],
                color[3],
            );
            c.cairo_fill(context);
        }
    }

    /// Reloads the Cairo surface contents into the radar texture for display.
    fn resetPaintable(self: *Self) void {
        c.g_clear_object(@ptrCast(&self.radar_paintable));

        const radar_data = c.cairo_image_surface_get_data(self.radar_surface);
        const radar_data_stride = c.cairo_image_surface_get_stride(self.radar_surface);
        const radar_data_len = c.cairo_image_surface_get_width(
            self.radar_surface,
        ) * radar_data_stride;
        const radar_data_bytes = c.g_bytes_new_static(radar_data, @intCast(radar_data_len));
        self.radar_paintable = @ptrCast(c.gdk_memory_texture_new(
            self.internal_surface_size,
            self.internal_surface_size,
            c.GDK_MEMORY_B8G8R8A8_PREMULTIPLIED,
            radar_data_bytes,
            @intCast(radar_data_stride),
        ));

        c.g_bytes_unref(radar_data_bytes);
    }
};
