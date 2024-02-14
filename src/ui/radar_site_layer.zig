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
const gobject = @import("gobject.zig");
const lib = @import("../lib.zig");
const c = lib.c;
const assets = @import("../assets/bundled_assets.zig");

pub const RadarSiteLayer = struct {
    parent: c.GObject,
    marker_layer: *c.ShumateMarkerLayer,
    viewport: *c.ShumateViewport,
    markers: [assets.radar_sites.len]*c.ShumateMarker,
    marker_indices: [assets.radar_sites.len]c.guint64,
    const Self = @This();

    pub usingnamespace gobject.RegisterType(
        Self,
        &c.g_object_get_type,
        "RadarSiteLayer",
        &.{},
    );

    pub const Class = struct {
        parent_class: c.GObjectClass,

        pub fn initClass(class: *Class) void {
            class.parent_class.constructed = @ptrCast(&constructed);

            c.g_object_class_install_property(
                @ptrCast(class),
                1,
                c.g_param_spec_object(
                    "viewport",
                    "viewport",
                    "The viewport for the shumate layer.",
                    c.shumate_viewport_get_type(),
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT_ONLY,
                ),
            );

            c.g_object_class_install_property(@ptrCast(class), 2, c.g_param_spec_uint64(
                "selected-index",
                "selected-index",
                "The index of the currently selected radar site.",
                0,
                assets.radar_sites.len,
                83,
                c.G_PARAM_READWRITE,
            ));

            _ = c.g_signal_new(
                "site-changed",
                Self.getType(),
                c.G_SIGNAL_RUN_LAST | c.G_SIGNAL_DETAILED,
                0,
                null,
                null,
                c.g_cclosure_marshal_VOID__OBJECT,
                c.G_TYPE_NONE,
                2,
                c.G_TYPE_POINTER,
                c.G_TYPE_INT64,
            );
        }
    };

    pub fn new(viewport: ?*c.ShumateViewport) *Self {
        const self: *Self = @alignCast(@ptrCast(c.g_object_new(
            Self.getType(),
            "viewport",
            viewport,
            gobject.end_of_args,
        )));

        return self;
    }

    pub fn init(_: *Self) void {}

    pub fn dispose(self: *Self) void {
        c.g_clear_object(@ptrCast(&self.marker_layer));

        for (&self.markers) |*marker| {
            c.g_clear_object(@ptrCast(marker));
        }
    }

    pub fn constructed(self: *Self) void {
        gobject.getParentClass(Self.getType()).constructed.?(@ptrCast(self));

        self.marker_layer = c.shumate_marker_layer_new(self.viewport).?;

        for (assets.radar_sites, &self.markers, &self.marker_indices, 0..) |site, *marker, *index, i| {
            marker.* = c.shumate_marker_new();
            index.* = i;
            const image = c.gtk_image_new_from_icon_name("radar-site");
            const css_classes: []const ?[*:0]const u8 = &.{ "radar-site", null };
            c.gtk_widget_set_css_classes(@ptrCast(image), @constCast(@ptrCast(css_classes)));
            c.gtk_widget_set_tooltip_text(@ptrCast(image), site.name.ptr);
            c.shumate_marker_set_child(marker.*, image);
            c.shumate_marker_set_selectable(marker.*, 1);
            c.shumate_location_set_location(@ptrCast(marker.*), @floatCast(site.lat), @floatCast(site.lon));
            c.g_object_set_data(@ptrCast(marker.*), "site", @constCast(@ptrCast(&site)));
            c.g_object_set_data(@ptrCast(marker.*), "index", @ptrCast(index));
            c.shumate_marker_layer_add_marker(self.marker_layer, @ptrCast(marker.*));
        }

        _ = c.shumate_marker_layer_select_marker(self.marker_layer, self.markers[83]);

        c.shumate_marker_layer_set_selection_mode(self.marker_layer, c.GTK_SELECTION_SINGLE);
        _ = c.g_signal_connect_data(
            self.marker_layer,
            "marker-selected",
            @ptrCast(&onMarkerSelected),
            self,
            null,
            c.G_CONNECT_SWAPPED,
        );
        _ = c.g_signal_connect_data(
            self.marker_layer,
            "marker-unselected",
            @ptrCast(&onMarkerDeselected),
            self,
            null,
            c.G_CONNECT_SWAPPED,
        );
    }

    pub fn getProperty(self: *Self, id: c.guint, value: *c.GValue, _: *c.GParamSpec) void {
        switch (id) {
            1 => c.g_value_set_object(value, @ptrCast(self.viewport)),
            2 => {
                const markers = c.shumate_marker_layer_get_selected(self.marker_layer);
                const selected = c.g_list_first(markers);
                const selected_marker: *c.GObject = @alignCast(@ptrCast(selected.*.data));
                c.g_value_set_uint64(
                    value,
                    @as(*c.guint64, @alignCast(@ptrCast(c.g_object_get_data(selected_marker, "index")))).*,
                );
            },
            else => {},
        }
    }

    pub fn setProperty(self: *Self, id: c.guint, value: *c.GValue, _: *c.GParamSpec) void {
        switch (id) {
            1 => self.viewport = @alignCast(@ptrCast(c.g_value_get_object(value))),
            2 => {
                const selected = c.g_value_get_uint64(value);
                _ = c.shumate_marker_layer_select_marker(self.marker_layer, self.markers[selected]);
            },
            else => {},
        }
    }

    fn onMarkerSelected(self: *Self, marker: *c.ShumateMarker, _: c.gpointer) void {
        const marker_index = @as(*c.guint64, @alignCast(@ptrCast(c.g_object_get_data(@ptrCast(marker), "index")))).*;
        c.g_object_set(self, "selected-index", marker_index, gobject.end_of_args);
        c.gtk_widget_set_visible(@ptrCast(c.shumate_marker_get_child(marker)), 0);
        c.g_signal_emit_by_name(
            self,
            "site-changed",
            c.g_object_get_data(@ptrCast(marker), "site"),
            marker_index,
            gobject.end_of_args,
        );
    }

    fn onMarkerDeselected(_: *Self, marker: *c.ShumateMarker, _: c.gpointer) void {
        c.gtk_widget_set_visible(c.shumate_marker_get_child(marker), 1);
    }
};
