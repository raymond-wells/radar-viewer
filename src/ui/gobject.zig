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

//! A set of utilities for interoperability between GObject (GLib Object) and Zig. The utilities herein allow callers to
//! register Zig structs as subclasses of GObject types.
const std = @import("std");
const c = @import("../lib.zig").c;
const TypeGetter = *const fn () callconv(.C) c.GType;

/// A workaround for Zig's lack of support regarding `null` in variadic functions.
/// Pass this into `g_object_new` to mark the end of the property list.
///
/// e.g. g_object_new(Self.getType(), "constructor-property", "value", gobject.end_of_args);
pub const end_of_args = @as(c.gpointer, @ptrFromInt(0));

/// Return a pointer to the `GObjectClass` corresponding to the provided instance.
pub fn getGObjectClass(instance: anytype) *c.GObjectClass {
    const type_instance: *c.GTypeInstance = @alignCast(@ptrCast(instance));
    return @ptrCast(type_instance.g_class);
}

/// Return a pointer to the parent GObjectClass corresponding to the instance.
/// This is **not** the same as the `parent` field of a type class, but is the actual
/// parent class within the hierarchy.
///
/// This is required for chaining up methods like `dispose` and `construct` to their
/// respective superclasses.
pub fn getParentClass(type_: c.GType) *c.GObjectClass {
    const object_class = c.g_type_class_peek_static(type_);
    return @alignCast(@ptrCast(c.g_type_class_peek_parent(@ptrCast(object_class))));
}
/// Return a pointer to the `*Interface` instance corresponding to the given interface
/// implemented by the provided type, if any.
pub fn getInterface(comptime I: type, interface_type_id: c.GType, instance: anytype) ?*I {
    return @as(
        ?*I,
        @alignCast(@ptrCast(c.g_type_interface_peek(getGObjectClass(instance), interface_type_id))),
    );
}

/// Given a GLib.String instance, return a corresponding slice. Useful for interfacing
/// with Zig library functions which expect slices. Slices contain approximately the same
/// types of data as GLib.String instances.
pub inline fn gStringToSlice(str: *c.GString) []const u8 {
    return str.str[0..str.len];
}

/// Given a GLib.Bytes instance, return a corresponding slice. Useful for interfacing with
/// Zig library functions which expect slices. Slices contain approximately the same nature
/// of information as GLib.Bytes instances.
pub fn gBytesToSlice(bytes: *c.GBytes) []const u8 {
    var size: c.gsize = 0;
    const data: [*]const u8 = @ptrCast(c.g_bytes_get_data(bytes, &size));
    return data[0..size];
}

/// Registers a Zig struct as a GObject class, returning a struct containing some utility methods to assist with
/// GObject integration. Callers may elect to use the return value either as an embedded struct, or as a mixin via
/// the <code>usingnamespace</code> pattern.
///
/// For proper C integration, T should be an `extern` struct. If C integration is not a concern, then a
/// standard Zig struct is fine.
///
/// T must define the following internal structs:
///
/// * An internal struct named Class, which follows the typical GObjectClass convention. See The GObject library
///   documentation for details. Any properties should be defined within a public `initClass(*Class)` method defined
///   inside of the internal struct.
/// * A pair of `setProperty` and `getProperty` methods. Again, see the GObject library documentation for information
///   about how to build these.
/// * A finalize method; a destructor called when the last reference is released via `g_object_unref`.
///
/// `parent_type_getter` is a pointer to the `*_get_type()` method of the parent class. This is required in order to
/// register the correct parent type with GLib, so that the library knows how to construct new instances.
///
/// `pascal_name` is the `ClassName` in pascal case. Each type must have a unique name.
///
/// GObject subtypes are an important element for the development of GTK applications within Zig.
///
/// Gotchas:
///
///   * Default values in struct items are inconsequential; GObject zeroes memory when it
///     allocates structures.
///
pub fn RegisterType(
    comptime T: type,
    comptime parent_type_getter: TypeGetter,
    comptime pascal_name: []const u8,
    comptime interfaces: []const struct { TypeGetter, c.GInterfaceInfo },
) type {
    return struct {
        const Self = @This();
        var g_type_id: ?c.GType = null;

        pub fn getType() callconv(.C) c.GType {
            if (g_type_id) |type_id| {
                return type_id;
            } else {
                g_type_id = @This().createTypeId();
                return g_type_id.?;
            }
        }

        fn createTypeId() c.GType {
            const type_id = c.g_type_register_static_simple(
                parent_type_getter(),
                c.g_intern_static_string(@ptrCast(pascal_name)),
                @sizeOf(T.Class),
                @ptrCast(&Self.initClass),
                @sizeOf(T),
                @ptrCast(&T.init),
                c.G_TYPE_FLAG_NONE,
            );

            for (interfaces) |entry| {
                c.g_type_add_interface_static(type_id, entry[0](), &entry[1]);
            }

            return type_id;
        }

        fn disposeWrapper(self: *T) callconv(.C) void {
            if (@hasDecl(T, "dispose")) {
                self.dispose();
            }

            const parent_class = getParentClass(g_type_id.?);
            parent_class.dispose.?(@ptrCast(self));
        }

        fn finalizeWrapper(self: *T) callconv(.C) void {
            if (@hasDecl(T, "finalize")) {
                self.finalize();
            }

            getParentClass(g_type_id.?).finalize.?(@ptrCast(self));
        }

        fn initClass(class: *T.Class) callconv(.C) void {
            if (@intFromPtr(class) == 0x0) {
                std.debug.print("Class pointer is null.\n", .{});
            }
            var object_class = @as(*c.GObjectClass, @ptrCast(class));

            if (@hasDecl(T, "setProperty")) {
                object_class.get_property = @ptrCast(&T.getProperty);
            }

            if (@hasDecl(T, "getProperty")) {
                object_class.set_property = @ptrCast(&T.setProperty);
            }

            object_class.finalize = @ptrCast(&finalizeWrapper);
            object_class.dispose = @ptrCast(&disposeWrapper);

            if (@hasDecl(T.Class, "initClass")) {
                class.initClass();
            }
        }
    };
}

test "Get Type Singleton" {
    const CustomType = struct {
        const Self = @This();

        parent: c.GObject,

        pub const Class = extern struct {
            parent_class: c.GObjectClass,
        };

        pub fn finalize(_: *Self) void {}
        pub fn init(_: *Self) void {}

        pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
        pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    };
    const wrapper = RegisterType(CustomType, c.g_object_get_type, "TestType1", &.{});
    const expected = wrapper.getType();
    try std.testing.expectEqual(expected, wrapper.getType());
}

test "Subclasses of Zig types." {
    const Parent = struct {
        const Self = @This();

        parent: c.GObject,

        pub const Class = extern struct {
            parent_class: c.GObjectClass,
        };

        pub usingnamespace RegisterType(Self, &c.g_object_get_type, "Parent1", &.{});

        pub fn finalize(_: *Self) void {}
        pub fn init(_: *Self) void {}

        pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
        pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    };

    const Child = struct {
        const Self = @This();

        parent: Parent,

        pub const Class = extern struct {
            parent_class: Parent.Class,
        };

        pub usingnamespace RegisterType(Self, &Parent.getType, "Child1", &.{});

        pub fn finalize(_: *Self) void {}
        pub fn init(_: *Self) void {}

        pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
        pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    };

    try std.testing.expectEqual(Parent.getType(), c.g_type_parent(Child.getType()));

    const instance: *Child = @ptrCast(c.g_object_new(
        Child.getType(),
        @ptrFromInt(0),
    ));

    try std.testing.expectEqual(c.G_OBJECT_TYPE(instance), Child.getType());

    c.g_object_unref(instance);
}

test "Initialization and Freeing" {
    const CustomType = struct {
        const Self = @This();

        parent: c.GObject,

        pub const Class = extern struct {
            parent_class: c.GObjectClass,
        };

        pub fn finalize(_: *Self) callconv(.C) void {}
        pub fn init(_: *Self) void {}

        pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
        pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    };
    const wrapper = RegisterType(CustomType, c.g_object_get_type, "TestType2", &.{});
    const instance = c.g_object_new(wrapper.getType(), null);
    c.g_object_unref(instance);
}

test "Implementing Interfaces" {
    const CustomType = struct {
        const Self = @This();

        parent: c.GObject,
        model: *c.GListModel,
        pub const Class = extern struct {
            parent_class: c.GObjectClass,
        };

        pub usingnamespace RegisterType(
            Self,
            &c.g_object_get_type,
            "TestInterfaces",
            &.{
                .{
                    &c.g_list_model_get_type, .{
                        .interface_init = @ptrCast(&struct {
                            fn interfaceInit(interface: *c.GListModelInterface) void {
                                interface.get_item = @ptrCast(&Self.getItem);
                                interface.get_item_type = @ptrCast(&Self.getItemType);
                                interface.get_n_items = @ptrCast(&Self.getNItems);
                            }
                        }.interfaceInit),
                        .interface_finalize = null,
                        .interface_data = null,
                    },
                },
            },
        );

        pub fn finalize(_: *Self) void {}
        pub fn init(_: *Self) void {}

        pub fn getItem(_: *Self, _: f64) ?*anyopaque {
            return null;
        }

        pub fn getItemType(_: *Self) c.GType {
            return c.G_TYPE_POINTER;
        }

        pub fn getNItems(_: *Self) c.guint {
            return 0;
        }

        pub fn getProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
        pub fn setProperty(_: *c.GObject, _: c.guint, _: *c.GValue, _: *c.GParamSpec) void {}
    };

    const instance: *CustomType = @alignCast(@ptrCast(c.g_object_new(CustomType.getType(), null)));
    const maybe_iface = getInterface(c.GListModelInterface, c.g_list_model_get_type(), instance);
    try std.testing.expect(maybe_iface != null);

    const iface = maybe_iface.?;
    try std.testing.expectEqual(iface.get_item, @as(@TypeOf(iface.get_item), @ptrCast(&CustomType.getItem)));
    try std.testing.expectEqual(iface.get_item_type, @as(@TypeOf(iface.get_item_type), @ptrCast(&CustomType.getItemType)));
    try std.testing.expectEqual(iface.get_n_items, @as(@TypeOf(iface.get_n_items), @ptrCast(&CustomType.getNItems)));

    try std.testing.expect(iface.get_n_items.?(@ptrCast(instance)) == 0);
    c.g_object_unref(instance);
}
