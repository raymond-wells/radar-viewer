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
const c = @import("lib.zig").c;
const assets = @import("assets/bundled_assets.zig");
const gobject = @import("ui/gobject.zig");
const nexrad = @import("nexrad.zig");
const color_tables = @import("ui/color_tables.zig");
const NexradLayer = @import("ui/nexrad_layer.zig").NexradLayer;
const RadarSiteLayer = @import("ui/radar_site_layer.zig").RadarSiteLayer;
const RadarDataProvider = @import("ui/radar_data_provider.zig").RadarDataProvider;

pub const Application = struct {
    parent: c.GtkApplication,
    cache_dir: *c.GString = undefined,
    current_radar_layer: ?*c.ShumateLayer = null,
    simple_map: ?*c.ShumateSimpleMap = null,
    map: ?*c.ShumateMap = null,
    radar_options: ?*c.GtkWidget,
    radar: ?*NexradLayer = null,
    provider: *RadarDataProvider,
    color_table_manager: *color_tables.Manager,
    product_selector: ?*c.GtkDropDown,
    product_table: []const nexrad.products.Product,
    site_selector: ?*c.GtkDropDown,
    tilt_selector: *c.GtkSpinButton,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub const Class = struct {
        parent_class: c.GtkApplicationClass,
    };

    pub usingnamespace gobject.RegisterType(
        Self,
        &c.gtk_application_get_type,
        "RadarViewerApplication",
        &.{},
    );

    pub fn new(allocator: std.mem.Allocator) *Self {
        const object = c.g_object_new(
            Self.getType(),
            "application-id",
            "org.rwells.RadarViewer",
            "flags",
            c.G_APPLICATION_DEFAULT_FLAGS,
        );

        _ = c.g_signal_connect_data(
            object,
            "activate",
            c.G_CALLBACK(&activate),
            null,
            null,
            c.G_CONNECT_DEFAULT,
        );

        const self: *Self = @alignCast(@ptrCast(object));
        self.allocator = allocator;
        self.provider = RadarDataProvider.new(&self.allocator, self.cache_dir.str);

        return self;
    }

    pub fn init(self: *Self) void {
        self.cache_dir = c.g_string_new(c.g_get_user_cache_dir());
        self.cache_dir = c.g_string_append(self.cache_dir, "/org.rwells.RadarViewer");
    }

    pub fn finalize(self: *Self) void {
        _ = c.g_string_free(self.cache_dir, 1);
        c.g_object_unref(self.provider);
        c.g_object_unref(self.color_table_manager);
    }

    pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}

    fn activate(self: *Self, _: c.gpointer) void {
        registerCustomResources();
        self.color_table_manager = color_tables.Manager.new(self.allocator);
        self.color_table_manager.loadDefaultColorTables();

        const css_provider = c.gtk_css_provider_new();
        c.gtk_css_provider_load_from_resource(css_provider, "/org/rwells/RadarViewer/main.css");

        c.gtk_style_context_add_provider_for_display(
            c.gdk_display_get_default(),
            @ptrCast(css_provider),
            c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
        );

        const window = c.gtk_application_window_new(@ptrCast(self));
        const header_bar = c.gtk_header_bar_new();
        c.gtk_window_set_titlebar(@ptrCast(window), @ptrCast(header_bar));

        c.gtk_window_set_title(@ptrCast(window), "Radar Viewer");
        c.gtk_window_set_default_size(@ptrCast(window), 640, 480);
        _ = c.g_signal_connect_data(
            @ptrCast(window),
            "show",
            c.G_CALLBACK(&onWindowShown),
            @ptrCast(self),
            null,
            c.G_CONNECT_SWAPPED,
        );

        c.gtk_window_present(@ptrCast(window));

        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 1);

        const options_toggle = c.gtk_toggle_button_new();
        c.gtk_button_set_icon_name(
            @ptrCast(options_toggle),
            "document-properties-symbolic",
        );
        c.gtk_header_bar_pack_end(@ptrCast(header_bar), @ptrCast(options_toggle));

        const sites_toggle = c.gtk_toggle_button_new();
        c.gtk_button_set_icon_name(
            @ptrCast(sites_toggle),
            "radar-site",
        );
        c.gtk_widget_set_tooltip_text(
            @ptrCast(sites_toggle),
            "Show Radar Sites",
        );
        c.gtk_header_bar_pack_start(@ptrCast(header_bar), @ptrCast(sites_toggle));

        self.product_table = nexrad.products.standard_products;
        const product_model = c.gtk_string_list_new(null);
        self.product_selector = @ptrCast(c.gtk_drop_down_new(
            @ptrCast(product_model),
            c.gtk_property_expression_new(
                c.gtk_string_object_get_type(),
                null,
                "string",
            ),
        ));
        self.syncProductModelWithTable();
        c.gtk_drop_down_set_enable_search(@ptrCast(self.product_selector), 1);
        c.gtk_drop_down_set_selected(@ptrCast(self.product_selector), 0);
        c.gtk_header_bar_pack_end(@ptrCast(header_bar), @alignCast(@ptrCast(self.product_selector)));
        _ = c.g_signal_connect_data(
            @ptrCast(self.product_selector),
            "notify::selected-item",
            c.G_CALLBACK(&onProductChanged),
            @ptrCast(self),
            null,
            c.G_CONNECT_SWAPPED,
        );

        const site_model = c.gtk_string_list_new(null);
        for (assets.radar_sites) |site| {
            c.gtk_string_list_append(site_model, site.name.ptr);
        }
        self.site_selector = @alignCast(@ptrCast(c.gtk_drop_down_new(
            @ptrCast(site_model),
            c.gtk_property_expression_new(c.gtk_string_object_get_type(), null, "string"),
        )));
        c.gtk_drop_down_set_enable_search(@ptrCast(self.site_selector), 1);
        c.gtk_drop_down_set_selected(@ptrCast(self.site_selector), 87);
        c.gtk_header_bar_pack_end(@ptrCast(header_bar), @alignCast(@ptrCast(self.site_selector)));
        _ = c.g_signal_connect_data(
            @ptrCast(self.site_selector),
            "notify::selected-item",
            c.G_CALLBACK(&onSiteChanged),
            @ptrCast(self),
            null,
            c.G_CONNECT_SWAPPED,
        );

        self.radar_options = @alignCast(@ptrCast(self.createRadarOptions()));
        _ = c.g_object_bind_property(
            @alignCast(@ptrCast(options_toggle)),
            "active",
            @alignCast(@ptrCast(self.radar_options)),
            "visible",
            c.G_BINDING_DEFAULT,
        );

        const root_pane = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
        c.gtk_box_append(@ptrCast(root_pane), @alignCast(@ptrCast(box)));
        c.gtk_box_append(@ptrCast(root_pane), self.radar_options);
        c.gtk_widget_set_hexpand(@alignCast(@ptrCast(box)), 1);
        c.gtk_window_set_child(@ptrCast(window), @alignCast(@ptrCast(root_pane)));

        c.gtk_widget_hide(self.radar_options);

        self.simple_map = createMap();
        self.map = c.shumate_simple_map_get_map(self.simple_map);
        c.shumate_map_go_to_full(self.map, 35.0, -97.0, 7.0);

        self.radar = NexradLayer.new(
            c.shumate_map_get_viewport(self.map),
            self.allocator,
            self.provider,
            self.color_table_manager,
        );
        c.shumate_simple_map_add_overlay_layer(self.simple_map, @ptrCast(self.radar));
        c.gtk_box_append(@ptrCast(box), @alignCast(@ptrCast(self.simple_map)));

        const site_layer = RadarSiteLayer.new(c.shumate_map_get_viewport(self.map));
        c.gtk_widget_set_visible(@alignCast(@ptrCast(site_layer.marker_layer)), 0);
        c.shumate_simple_map_add_overlay_layer(self.simple_map, @alignCast(@ptrCast(site_layer.marker_layer)));
        _ = c.g_object_bind_property(
            @alignCast(@ptrCast(self.site_selector)),
            "selected",
            @alignCast(@ptrCast(site_layer)),
            "selected-index",
            c.G_BINDING_BIDIRECTIONAL,
        );
        _ = c.g_object_bind_property(
            @alignCast(@ptrCast(sites_toggle)),
            "active",
            @alignCast(@ptrCast(site_layer.marker_layer)),
            "visible",
            c.G_BINDING_DEFAULT,
        );
    }

    fn createMap() ?*c.ShumateSimpleMap {
        const registry = c.shumate_map_source_registry_new_with_defaults();
        const source = c.shumate_map_source_registry_get_by_id(
            registry,
            c.SHUMATE_MAP_SOURCE_OSM_MAPNIK,
        ) orelse @panic("Could not fetch map source");

        const simple_map = c.shumate_simple_map_new();
        c.shumate_simple_map_set_map_source(simple_map, source);
        c.gtk_widget_set_halign(@alignCast(@ptrCast(simple_map)), c.GTK_ALIGN_FILL);
        c.gtk_widget_set_valign(@alignCast(@ptrCast(simple_map)), c.GTK_ALIGN_FILL);
        c.gtk_widget_set_hexpand(@alignCast(@ptrCast(simple_map)), 1);
        c.gtk_widget_set_vexpand(@alignCast(@ptrCast(simple_map)), 1);

        return simple_map;
    }

    fn createRadarOptions(self: *Self) [*c]c.GtkWidget {
        const list_box = c.gtk_list_box_new();
        c.gtk_list_box_set_selection_mode(@alignCast(@ptrCast(list_box)), c.GTK_SELECTION_NONE);

        const tilt_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 20);
        const tilt_label = c.gtk_label_new("Tilt");
        self.tilt_selector = self.createTiltSelector();
        c.gtk_box_append(@alignCast(@ptrCast(tilt_box)), @alignCast(@ptrCast(tilt_label)));
        c.gtk_box_append(@alignCast(@ptrCast(tilt_box)), @alignCast(@ptrCast(self.tilt_selector)));

        c.gtk_list_box_append(@alignCast(@ptrCast(list_box)), @alignCast(@ptrCast(tilt_box)));
        return @alignCast(@ptrCast(list_box));
    }

    fn createTiltSelector(self: *Self) *c.GtkSpinButton {
        const button = c.gtk_spin_button_new_with_range(1.0, 4.0, 1.0);
        _ = c.g_signal_connect_data(
            button,
            "changed",
            @ptrCast(&onTiltChanged),
            self,
            null,
            c.G_CONNECT_SWAPPED,
        );
        return @alignCast(@ptrCast(button));
    }

    fn onSiteChanged(self: *Self, _: *c.GParamSpec, selector: *c.GtkDropDown) void {
        const site_object = c.gtk_drop_down_get_selected_item(selector);
        const site = c.gtk_string_object_get_string(@ptrCast(site_object));

        const new_table = nexrad.products.getProductsForSite(std.mem.sliceTo(site, 0)).?;
        if (@intFromPtr(new_table.ptr) != @intFromPtr(self.product_table.ptr)) {
            self.product_table = new_table;
            self.syncProductModelWithTable();
        }

        self.provider.setRadarSite(site);
        _ = self.provider.checkForRadarUpdates();
    }

    fn onProductChanged(self: *Self, _: *c.GParamSpec, selector: *c.GtkDropDown) void {
        const product_idx: usize = @intCast(c.gtk_drop_down_get_selected(selector));
        if (product_idx == c.GTK_INVALID_LIST_POSITION) {
            return;
        }

        self.provider.setRadarProduct(@ptrCast(&self.product_table[product_idx].code_name));
        c.gtk_spin_button_set_range(
            self.tilt_selector,
            1.0,
            @floatFromInt(self.product_table[product_idx].tilt_levels),
        );
        self.onTiltChanged(self.tilt_selector);
    }

    fn onTiltChanged(self: *Self, tilt: *c.GtkSpinButton) void {
        const tilt_value = @as(u8, @intFromFloat(c.gtk_spin_button_get_value(tilt)));
        const product_index: usize = @intCast(c.gtk_drop_down_get_selected(self.product_selector));
        const tilt_index = self.product_table[product_index].tilt_digit_index;
        self.provider.radar_product.str[tilt_index] = '0' + (tilt_value - 1);
        _ = self.provider.checkForRadarUpdates();
    }

    fn onWindowShown(self: *Self, _: c.gpointer) void {
        _ = self.provider.checkForRadarUpdates();
        self.provider.reScheduleUpdateChecks();
    }

    fn registerCustomResources() void {
        var g_error: ?*c.GError = null;
        const resources = c.g_resource_new_from_data(c.g_bytes_new_static(
            @ptrCast(assets.resources.ptr),
            assets.resources.len,
        ), &g_error);

        if (g_error) |error_value| {
            std.debug.print(
                "Could not load resources: {s} {d}\n",
                .{
                    error_value.message,
                    assets.resources.len,
                },
            );
            @panic("Failed to load resources.");
        }
        c.g_resources_register(resources);
        const icon_theme = c.gtk_icon_theme_get_for_display(c.gdk_display_get_default());
        c.gtk_icon_theme_add_resource_path(icon_theme, "/org/gtk/example/icons");
    }

    fn syncProductModelWithTable(self: *Self) void {
        const model: *c.GtkStringList = @ptrCast(c.gtk_drop_down_get_model(self.product_selector));

        _ = c.g_object_ref(model);
        defer c.g_object_unref(model);

        c.gtk_drop_down_set_model(self.product_selector, null);
        const count = c.g_list_model_get_n_items(@ptrCast(model));
        for (0..count) |_| {
            c.gtk_string_list_remove(model, 0);
        }
        for (self.product_table) |product| {
            c.gtk_string_list_append(
                model,
                @ptrCast(product.getProductName().ptr),
            );
        }
        c.gtk_drop_down_set_model(self.product_selector, @alignCast(@ptrCast(model)));
    }
};

test {
    _ = @import("ui/async.zig");
    _ = @import("ui/gobject.zig");
    _ = @import("ui/color_tables.zig");
}
