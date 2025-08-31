const std = @import("std");

pub const friendly_names: []const [:0]const u8 = &.{
    "Base Reflectivity",
    "Base Velocity",
    "Correlation Coefficient",
    "Enhanced Echo Tops",
    "Differential Reflectivity",
};

pub const Product = struct {
    friendly_name_id: usize,
    code_name: [3:0]u8,
    tilt_digit_index: usize,
    tilt_levels: u8,

    pub inline fn getProductName(self: @This()) [:0]const u8 {
        return friendly_names[self.friendly_name_id];
    }
};

pub const standard_products: []const Product = &.{ .{
    .friendly_name_id = 0,
    .code_name = "N0Q".*,
    .tilt_digit_index = 1,
    .tilt_levels = 4,
}, .{
    .friendly_name_id = 1,
    .code_name = "NOU".*,
    .tilt_digit_index = 1,
    .tilt_levels = 4,
}, .{
    .friendly_name_id = 2,
    .code_name = "N0C".*,
    .tilt_digit_index = 1,
    .tilt_levels = 4,
}, .{
    .friendly_name_id = 3,
    .code_name = "EET".*,
    .tilt_digit_index = 0,
    .tilt_levels = 1,
}, .{
    .friendly_name_id = 4,
    .code_name = "N0X".*,
    .tilt_digit_index = 1,
    .tilt_levels = 4,
} };

pub const tdwr_products: []const Product = &.{
    .{
        .friendly_name_id = 0,
        .code_name = "TZ0".*,
        .tilt_digit_index = 2,
        .tilt_levels = 3,
    },
    .{
        .friendly_name_id = 1,
        .code_name = "TV0".*,
        .tilt_digit_index = 2,
        .tilt_levels = 4,
    },
};

pub fn getProductsForSite(site_name: []const u8) ?[]const Product {
    if (site_name.len == 0) {
        return null;
    }

    if (site_name[0] == 'T') {
        return tdwr_products;
    }

    return standard_products;
}

test "Get products for radar site known" {
    try std.testing.expectEqual(standard_products, getProductsForSite("KDGX"));
    try std.testing.expectEqual(tdwr_products, getProductsForSite("TOKC"));
    try std.testing.expectEqual(null, getProductsForSite(""));
}
