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

const BoxedRadarData = lib.AutoBoxed(nexrad.NexradLevel3);

/// The Radar Data Provider manages radar data by product and location.
///
/// There are two sources of radar data, examined in the following order of
/// precedence:
///
/// * Locally cached radar scan data.
/// * Online radar data provided by the NWS.
///
/// In order to be a good steward of bandwidth, we don't waste time downloading radar
/// images if we do not need to. Instead, we use a generous update interval and only update
/// radar images when new information is present.
///
///
/// Radar images sourced from the public dataset available on NOAA's tgftp.
/// Maintainers should reference https://www.weather.gov/tg/general for general
/// terms of use.
pub const RadarDataProvider = extern struct {
    parent: c.GObject,
    allocator: *std.mem.Allocator,
    update_interval_seconds: f64,
    cache_root: *c.GString,
    radar_site: *c.GString,
    radar_product: *c.GString,
    check_in_progress: c.gint,
    last_scan_time: f64,
    radar_check_timeout: c.guint,
    session: *c.SoupSession,

    const Self = @This();

    /// Wraps checking for radar updates in a Task generator used to run these tasks in a separate thread.
    const CheckRadarUpdateTask = gio.asyncTaskWrapper(checkRadarHandler, updateCheckFinished);

    const Properties = enum(c_int) {
        Allocator = 1,
        UpdateInterval = 2,
        CacheRoot = 3,
        RadarSite = 4,
        RadarProduct = 5,
    };

    const Signals = enum(usize) {
        /// Emitted with a pointer to new radar data whenever radar data is successfully updated.
        DataUpdated = 0,
    };

    pub usingnamespace gobject.RegisterType(Self, &c.g_object_get_type, "RadarDataProvider", &.{});

    pub const Class = extern struct {
        parent: c.GObjectClass,

        pub var signals: [1]c.guint = undefined;

        pub fn initClass(self: *Class) void {
            self.parent.constructed = @ptrCast(&constructed);

            c.g_object_class_install_property(
                @ptrCast(self),
                @intFromEnum(Properties.Allocator),
                c.g_param_spec_pointer(
                    "allocator",
                    "Allocator",
                    "Pointer to a Zig Allocator used to allocate memory for radar data.",
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT_ONLY,
                ),
            );

            c.g_object_class_install_property(
                @ptrCast(self),
                @intFromEnum(Properties.UpdateInterval),
                c.g_param_spec_uint(
                    "update-interval",
                    "Update Interval",
                    "The amount of time in minutes between checks for new radar data.",
                    1,
                    60,
                    5,
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT,
                ),
            );

            c.g_object_class_install_property(
                @ptrCast(self),
                @intFromEnum(Properties.CacheRoot),
                c.g_param_spec_string(
                    "cache-root",
                    "Cache Root",
                    "The root directory of the structure for storing downloaded radar data.",
                    "",
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT_ONLY,
                ),
            );

            c.g_object_class_install_property(
                @ptrCast(self),
                @intFromEnum(Properties.RadarSite),
                c.g_param_spec_string(
                    "radar-site",
                    "Radar Site",
                    "The call sign of the radar site to fetch data for.",
                    "KTLX",
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT,
                ),
            );

            c.g_object_class_install_property(
                @ptrCast(self),
                @intFromEnum(Properties.RadarProduct),
                c.g_param_spec_string(
                    "radar-product",
                    "Radar Product Code",
                    "The product code of the radar product to request. Defaults to N0Q (Base Reflectivity).",
                    "N0Q",
                    c.G_PARAM_READWRITE | c.G_PARAM_CONSTRUCT,
                ),
            );

            signals[@intFromEnum(Signals.DataUpdated)] = c.g_signal_new(
                "data-updated",
                Self.getType(),
                c.G_SIGNAL_RUN_LAST | c.G_SIGNAL_DETAILED,
                0,
                null,
                null,
                c.g_cclosure_marshal_VOID__OBJECT,
                c.G_TYPE_NONE,
                1,
                c.G_TYPE_POINTER,
            );
        }

        pub inline fn getSignal(signal: Signals) c.guint {
            return signals[@intFromEnum(signal)];
        }
    };

    pub fn new(allocator: *std.mem.Allocator, cache_dir: *c.gchar) *Self {
        return @alignCast(@ptrCast(c.g_object_new(
            Self.getType(),
            "allocator",
            allocator,
            "cache-root",
            cache_dir,
            gobject.end_of_args,
        )));
    }

    /// Gets the currently selected radar site.
    pub fn getRadarSite(self: *Self) *c.gchar {
        return self.radar_site.str;
    }

    /// Sets the currently selected radar site, which should trigger a check for a new radar image.
    pub fn setRadarSite(self: *Self, site: *const c.gchar) void {
        c.g_object_set(
            @ptrCast(self),
            "radar-site",
            site,
            gobject.end_of_args,
        );
    }

    pub fn setRadarProduct(self: *Self, site: *const c.gchar) void {
        c.g_object_set(
            @ptrCast(self),
            "radar-product",
            site,
            gobject.end_of_args,
        );
    }

    pub fn getProperty(self: *Self, property_id: c.guint, value: *c.GValue, _: *c.GParamSpec) void {
        switch (@as(Properties, @enumFromInt(property_id))) {
            .Allocator => c.g_value_set_pointer(value, @ptrCast(self.allocator)),
            .CacheRoot => c.g_value_set_string(value, self.cache_root.str),
            .UpdateInterval => c.g_value_set_uint(value, @as(c.guint, @intFromFloat(self.update_interval_seconds / 60.0))),
            .RadarSite => c.g_value_set_string(value, self.radar_site.str),
            .RadarProduct => c.g_value_set_string(value, self.radar_product.str),
        }
    }

    pub fn setProperty(self: *Self, property_id: c.guint, value: *c.GValue, _: *c.GParamSpec) void {
        switch (@as(Properties, @enumFromInt(property_id))) {
            .Allocator => {
                self.allocator = @alignCast(@ptrCast(c.g_value_get_pointer(value)));
            },
            .CacheRoot => {
                self.cache_root = c.g_string_assign(self.cache_root, c.g_value_get_string(value));
            },
            .UpdateInterval => {
                self.update_interval_seconds = @as(f32, @floatFromInt(c.g_value_get_uint(value))) * 60.0;
            },
            .RadarSite => {
                self.radar_site = c.g_string_assign(self.radar_site, c.g_value_get_string(value));
                self.last_scan_time = 0.0;
            },
            .RadarProduct => {
                self.radar_product = c.g_string_assign(self.radar_product, c.g_value_get_string(value));
            },
        }
    }

    pub fn init(self: *Self) void {
        self.cache_root = c.g_string_new("");
        self.radar_site = c.g_string_new("");
        self.radar_product = c.g_string_new("");
        self.last_scan_time = 0.0;
    }

    pub fn dispose(self: *Self) void {
        self.clearUpdateTimeout();
        c.g_clear_object(@ptrCast(&self.session));
    }

    pub fn finalize(self: *Self) void {
        _ = c.g_string_free(self.cache_root, 1);
        _ = c.g_string_free(self.radar_site, 1);
        _ = c.g_string_free(self.radar_product, 1);
    }

    /// Provides a timeout wrapper for checking radar updates.
    /// May also be called externally to check for updates immediately.
    pub fn checkForRadarUpdates(self: *Self) c.gboolean {
        if (c.g_atomic_int_compare_and_exchange(&self.check_in_progress, 0, 1) == 0) {
            c.g_log("org.rwells.RadarViewer", c.G_LOG_LEVEL_DEBUG, "Check already in progress. Skipping.");
            return 1;
        }

        const task = CheckRadarUpdateTask.runInTaskThread(self, null);
        defer c.g_object_unref(task);
        return 1;
    }

    /// Scheduled checks for radar updates at the configured update interval.
    /// Clears any existing periodic schedule checks. Sets `radar_check_timeout`
    /// to the ID of the timeout.
    pub fn reScheduleUpdateChecks(self: *Self) void {
        self.clearUpdateTimeout();

        self.radar_check_timeout = c.g_timeout_add_seconds(
            @intFromFloat(self.update_interval_seconds),
            @ptrCast(&checkForRadarUpdates),
            @ptrCast(self),
        );
    }

    /// If an existing update check timeout exist, clears the timeout. Otherwise a
    /// no-op.
    fn clearUpdateTimeout(self: *Self) void {
        if (self.radar_check_timeout > 0) {
            _ = c.g_source_remove(self.radar_check_timeout);
        }
    }

    /// Checks to see if the provider should fetch a new radar image by checking the last known scan time.
    /// If the provider should fetch a new radar image, call out to the NWS to get the latest radar data.
    ///
    ///
    /// This method is intended to be run within a GTask thread.
    fn checkRadarHandler(_: *c.GTask, self: *Self, _: c.gpointer, _: *c.GCancellable) !*BoxedRadarData {
        var cache_dir = try self.getCacheDir();
        defer cache_dir.close();

        c.g_log("org.rwells.RadarViewer", c.G_LOG_LEVEL_DEBUG, "Checking radar image for site %s, product %s", self.radar_site.str, self.radar_product.str);

        const current_time: f32 = @floatFromInt(std.time.timestamp());
        var nex_rad_data = try BoxedRadarData.create(
            self.allocator.*,
            nexrad.NexradLevel3.init(self.allocator.*),
        );
        errdefer nex_rad_data.unref();

        var fileByLocationBuf: [64]u8 = undefined;
        @memset(&fileByLocationBuf, 0);
        const radarFile = try std.fmt.bufPrint(&fileByLocationBuf, "radar-{s}-{s}.bin", .{
            gobject.gStringToSlice(self.radar_site),
            gobject.gStringToSlice(self.radar_product),
        });

        const cached_time = blk: {
            const stat = cache_dir.statFile(radarFile) catch break :blk 0.0;
            break :blk @as(f64, @floatFromInt(@divTrunc(stat.mtime, 1000000000)));
        };

        const time_delta = current_time - cached_time;
        if (time_delta >= self.update_interval_seconds) {
            var url_buffer: [1024]u8 = undefined;
            @memset(&url_buffer, 0);
            const radar_url = try nexrad.io.getRadarFileUrl(
                &url_buffer,
                gobject.gStringToSlice(self.radar_site),
                gobject.gStringToSlice(self.radar_product),
            );

            c.g_log(
                "org.rwells.RadarViewer",
                c.G_LOG_LEVEL_DEBUG,
                "Radar image expired. Fetching new image from %s",
                radar_url.ptr,
            );
            const message = c.soup_message_new("GET", radar_url.ptr);
            defer c.g_object_unref(message);
            const response_bytes = c.soup_session_send_and_read(self.session, message, null, null) orelse return error.ConnectionFailed;
            defer c.g_bytes_unref(response_bytes);

            if (c.soup_message_get_status(message) != c.SOUP_STATUS_OK) {
                return error.RadarFetchFailed;
            }

            try cache_dir.writeFile(.{ .sub_path = radarFile, .data = gobject.gBytesToSlice(response_bytes) });
        }

        var radar_data = try cache_dir.openFile(radarFile, .{});
        defer radar_data.close();

        nex_rad_data.value = nexrad.NexradLevel3.init(self.allocator.*);
        try nex_rad_data.value.decodeFile(radar_data.reader());

        self.last_scan_time = current_time;
        return nex_rad_data;
    }

    fn updateCheckFinished(self: *Self, result: *c.GAsyncResult, data: c.gpointer) void {
        _ = data;

        var g_error: ?*c.GError = null;
        const radar_data: ?*BoxedRadarData = @alignCast(@ptrCast(c.g_task_propagate_pointer(@ptrCast(result), &g_error)));
        c.g_atomic_int_set(&self.check_in_progress, 0);

        defer if (radar_data) |rd| rd.unref();

        if (g_error) |error_value| {
            c.g_log(
                null,
                c.G_LOG_LEVEL_WARNING,
                "An error occurred while attempting to fetch radar data: %s\n",
                error_value.message,
            );
            c.g_error_free(g_error);
            return;
        }

        c.g_signal_emit(
            @ptrCast(self),
            Class.getSignal(.DataUpdated),
            0,
            radar_data.?,
        );
    }

    /// Returns a handle to the root application cache directory. Caller responsible for freeing.
    fn getCacheDir(self: *Self) !std.fs.Dir {
        return std.fs.openDirAbsolute(self.cache_root.str[0..self.cache_root.len], .{}) catch |err| switch (err) {
            error.FileNotFound => blk: {
                try std.fs.makeDirAbsolute(self.cache_root.str[0..self.cache_root.len]);
                break :blk try std.fs.openDirAbsolute(self.cache_root.str[0..self.cache_root.len], .{});
            },
            else => return err,
        };
    }

    fn constructed(self: *Self) void {
        self.session = c.soup_session_new();
        c.soup_session_set_user_agent(self.session, "radar-viewer/0.1.dev0");
    }
};
