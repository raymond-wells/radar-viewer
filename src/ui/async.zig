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

//! A collection of utilities for dealing with GIO Async constructs in a zig-friendly way.

const std = @import("std");
const c = @import("../lib.zig").c;

///
/// Wraps a Zig function, which may return errors, in a Gio.Task object with proper error handling.
///
/// Useful for translating between the standard Zig functions and Gio tasks.
///
/// * `thread_func`: The Zig function to wrap. Must conform to the Gio.ThreadFunc spec.
/// * `finish_callback`: The function to call when the task completes, must conform to the Gio.AsyncReadyCallback spec.
///                      `null` values will be supported when I have a use case for them.
///
pub fn asyncTaskWrapper(comptime thread_func: anytype, comptime finish_callback: anytype) type {
    return struct {
        /// Launches the wrapped function in a Gio.Task thread, returning a `Gio.Task` object.
        ///
        /// The caller is responsible for calling `g_object_unref` upon the `Gio.Task` object to free it.
        /// An optional `data` parameter may contain data to send along to the task. May be `null`.
        ///
        pub fn runInTaskThread(sender: anytype, data: c.gpointer) ?*c.GTask {
            return genericRunTask(sender, data, c.g_task_run_in_thread);
        }

        /// Launches the task in a separate thread, and blocks the current thread until the task is
        /// complete.
        ///
        /// The caller is responsible for calling `g_object_unref` upon the `Gio.Task` object to free it.
        /// An optional `data` parameter may contain data to send along to the task. May be `null`.
        ///
        pub fn runInTaskThreadSync(sender: anytype, data: c.gpointer) ?*c.GTask {
            return genericRunTask(sender, data, c.g_task_run_in_thread_sync);
        }

        fn genericRunTask(sender: anytype, data: c.gpointer, runner: anytype) ?*c.GTask {
            const task = c.g_task_new(
                sender,
                null,
                @ptrCast(&finish_callback),
                null,
            );
            c.g_task_set_task_data(task, data, null);
            runner(task, @ptrCast(&@This().threadFunc));

            return task;
        }

        fn threadFunc(task: *c.GTask, self: *anyopaque, data: *anyopaque, cancellable: *c.GCancellable) callconv(.C) void {
            const return_value = thread_func(
                task,
                @alignCast(@ptrCast(self)),
                @alignCast(@ptrCast(data)),
                cancellable,
            ) catch |err| {
                c.g_task_return_new_error(
                    task,
                    c.g_resource_error_quark(),
                    @intFromError(err),
                    @errorName(err),
                );
                return;
            };

            switch (@typeInfo(@TypeOf(return_value))) {
                .bool => c.g_task_return_boolean(task, if (return_value) 1 else 0),
                .int => c.g_task_return_int(task, @intCast(return_value)),
                .void => c.g_task_return_boolean(task, 1),
                .pointer => c.g_task_return_pointer(task, @ptrCast(return_value), null),
                inline else => @compileError("Unrecognized return type " ++ @typeName(@TypeOf(return_value))),
            }
        }
    };
}
