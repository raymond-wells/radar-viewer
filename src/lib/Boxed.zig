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

//! Boxed pointers provide a way to encapsulate arbitrary pointers and Zig allocators
//! with reference counting capabilities. This is useful for passing pointers to Zig structs
//! through GObject signal handlers, where reference counting is a must to ensure that objects
//! are not freed prematurely.
const c = @import("c.zig");
const std = @import("std");

/// Provides a convenience method to create a `Boxed` subtype
/// for types which follow the typical Zig `deinit(Self)`/`deinit(*Self)`
/// pattern for destructor naming.
///
pub fn AutoBoxed(comptime T: type) type {
    return Boxed(T, T.deinit);
}

///
/// Initializes a new `Boxed` container for pointers to the provided `type`.
/// A Boxed provides reference counting for types which are not bound to
/// the GObject type system, making it easy to interact with bog-standard structs
/// from within a Gtk application.
///
/// A Boxed type may optionally be associated with a `destructor` method, which it will
/// call upon the release of the final reference (via `unref`). The destructor method is
/// a method, returning `void`, which may accept either the value type or the pointer to
/// the value type as its sole argument. To specify "no destructor", use an instance of
/// `void` (`{}` or `void{}`).
///
/// Beyond handling memory management, the ability to specify arbitrary destructors
/// makes `Boxed` useful in other contexts. Wrapping a file descriptor such that the
/// final call to `unref` will close the file is one (perhaps bad) example.
///
/// Under the hood, `Boxed` uses the GLib standard `grefcount` functionality to
/// implement reference counting and registers unique `GType` instances, making it
/// compatible with the GLib type system.
///
pub fn Boxed(comptime T: type, comptime destructor: anytype) type {
    return struct {
        var g_type: ?c.GType = null;
        const Self = @This();

        allocator: std.mem.Allocator,
        ref_count: c.grefcount,
        value: T,

        /// Fetches, and upon the first call creates, the unique `GType` ID corresponding to the
        /// the given `Boxed` struct. Only one `GType` ID per Boxed variant will
        /// exist globally within the scope of the application process. IDs are **not** guaranteed
        /// to be consistent across processes.
        ///
        /// Naming
        /// ------
        ///
        /// This method will automatically generate a compatible and unique, but not aesthetically
        /// appealing, name for the new type. While callers should *never* need to interact with the
        /// type name directly, the naming convention is as follows:
        ///
        /// lib_Boxed_Boxed_namespace_SomeType_void__
        ///
        /// Assuming the contained type is `namespace.SomeType`. The conversion of non-alphanumeric
        /// characters to `_` is required unfortunately as the GLib type system forbids certain special
        /// characters in type names. This **should** not cause any namespace conflicts for well-structured
        /// projects.
        pub fn getType() c.GType {
            if (g_type) |type_| {
                return type_;
            }

            var type_name_buf = std.mem.zeroes([@typeName(@This()).len + 1:0]u8);
            std.mem.copyForwards(u8, &type_name_buf, @typeName(@This()));
            for (type_name_buf[0 .. type_name_buf.len - 1]) |*char| {
                if (!std.ascii.isAlphanumeric(char.*)) {
                    char.* = '_';
                }
            }

            g_type = c.g_boxed_type_register_static(
                &type_name_buf,
                @ptrCast(&copyFunc),
                @ptrCast(&freeFunc),
            );

            return g_type.?;
        }

        /// Initializes a new container with a pointer to an existing value. The container will take ownership of
        /// the provided pointer. Callers should **never** attempt to free the resulting `Boxed` instance
        /// with the given allocator. Instead, use the `unref` method to allow the reference counting logic to
        /// decide the appropriate time to free the instance.
        pub fn create(allocator: std.mem.Allocator, initial_value: T) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = Self{
                .allocator = allocator,
                .ref_count = 0,
                .value = initial_value,
            };

            c.g_ref_count_init(&self.ref_count);
            return self;
        }

        /// Increases the reference count, returning new container. Callers should treat
        /// the return value as a new container instance, even though in practice it may
        /// not be.
        pub fn ref(self: *Self) *Self {
            const ptr = c.g_boxed_copy(getType(), self);
            return @alignCast(@ptrCast(ptr));
        }

        /// Releases a reference to the contained value. Callers should use caution to
        /// match calls to `unref` with a corresponding call to `ref`.
        ///
        /// After calling unref, callers *must* consider the instance to be invalid and
        /// not attempt to re-use. Upon the release of the final reference, the memory
        /// allocated to the container and to the object therein will be released.
        pub fn unref(self: *Self) void {
            c.g_boxed_free(getType(), self);
        }

        fn copyFunc(self: *Self) *Self {
            c.g_ref_count_inc(&self.ref_count);
            return self;
        }

        fn freeFunc(self: *Self) void {
            if (c.g_ref_count_dec(&self.ref_count) == 1) {
                switch (@typeInfo(@TypeOf(destructor))) {
                    .Fn => |t| switch (@typeInfo(t.params[0].type.?)) {
                        .Pointer => destructor(&self.value),
                        else => destructor(self.value),
                    },
                    .Void => {},
                    else => @compileError("Unrecognized destructor type: " ++ @typeName(@TypeOf(destructor))),
                }

                self.allocator.destroy(self);
            }
        }
    };
}

test "Init and De-Init" {
    var boxed = try Boxed(u8, {}).create(std.testing.allocator, 32);
    try std.testing.expectEqual(boxed.value, 32);
    defer boxed.unref();
}

test "Destructors Called" {
    const boxed = try Boxed(
        std.ArrayList(u8),
        std.ArrayList(u8).deinit,
    ).create(
        std.testing.allocator,
        std.ArrayList(u8).init(std.testing.allocator),
    );

    // If the destructor is **not** called, this test will fail
    // on a memory leak.
    _ = try boxed.value.addOne();
    defer boxed.unref();
}

test "Pointer destructors called" {
    var destroyed = false;

    const Test = struct {
        p_destroyed: *bool,

        fn deinit(self: *@This()) void {
            self.p_destroyed.* = true;
        }
    };

    const box = try AutoBoxed(Test).create(std.testing.allocator, .{
        .p_destroyed = &destroyed,
    });
    box.unref();

    try std.testing.expect(destroyed);
}

test "Reference Counting" {
    var destroyed = false;

    const Test = struct {
        p_destroyed: *bool,

        fn deinit(self: @This()) void {
            self.p_destroyed.* = true;
        }
    };

    const box = try AutoBoxed(Test).create(
        std.testing.allocator,
        .{
            .p_destroyed = &destroyed,
        },
    );

    const box_ref = box.ref();
    try std.testing.expectEqual(box_ref, box);
    try std.testing.expect(c.g_ref_count_compare(&box.ref_count, 2) == 1);

    box_ref.unref();
    try std.testing.expect(!destroyed);
    try std.testing.expect(c.g_ref_count_compare(&box.ref_count, 1) == 1);

    box_ref.unref();
    try std.testing.expect(destroyed);
}

test "Create errors on allocation failure" {
    var failing_allocator = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 0 },
    );
    const alloc = failing_allocator.allocator();

    try std.testing.expectError(error.OutOfMemory, Boxed(u8, {}).create(alloc, 0));
}

test "Type Naming" {
    try std.testing.expectEqualStrings(
        std.mem.sliceTo(c.g_type_name(AutoBoxed(std.ArrayList(u8)).getType()), 0),
        "lib_Boxed_Boxed_array_list_ArrayListAligned_u8_null___function__deinit___",
    );
}
