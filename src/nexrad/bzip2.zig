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

//! Provides a generic Reader implementation for handling BZIP2 compression in streams.
const std = @import("std");
const c = @import("../lib.zig").c;

const default_buffer_size = 256 * 1024;

/// Decompresses raw Bzip2 Data provided by a source stream into a buffer. Requires an allocator to manage the input & output
/// buffers relating to decompression.
///
pub fn Decompress(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        pub const Error = ReaderType.Error || std.mem.Allocator.Error || error{ CorruptedInput, EndOfStream, Overflow };
        pub const Reader = std.io.Reader(*Self, Error, read);

        allocator: std.mem.Allocator,
        compressed_data: []u8,
        source: ReaderType,
        stream: *c.bz_stream,

        pub fn init(allocator: std.mem.Allocator, source: ReaderType) !Self {
            return Self.initWithBufferSize(allocator, source, default_buffer_size);
        }

        fn initWithBufferSize(allocator: std.mem.Allocator, source: ReaderType, buffer_size: usize) !Self {
            var self = Self{
                .allocator = allocator,
                .stream = undefined,
                .compressed_data = undefined,
                .source = source,
            };

            self.compressed_data = try allocator.alloc(u8, buffer_size);
            errdefer allocator.free(self.compressed_data);
            self.stream = try self.allocator.create(c.bz_stream);
            errdefer allocator.destroy(self.stream);

            try self.initStream();

            return self;
        }

        pub fn deinit(self: Self) void {
            _ = c.BZ2_bzDecompressEnd(self.stream);
            self.allocator.free(self.compressed_data);
            self.allocator.destroy(self.stream);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, output: []u8) Error!usize {
            self.stream.next_out = output.ptr;
            self.stream.avail_out = @as(c_uint, @intCast(output.len));

            while (self.stream.avail_out > 0) {
                if (self.stream.avail_in == 0) {
                    self.stream.next_in = self.compressed_data.ptr;
                    self.stream.avail_in = @as(c_uint, @intCast(try self.source.read(self.compressed_data)));

                    // If we've reached the end of the stream, then there is no more compressed data to read, so we can safely break here.
                    if (self.stream.avail_in == 0) {
                        break;
                    }
                }

                const result = c.BZ2_bzDecompress(self.stream);
                switch (result) {
                    c.BZ_PARAM_ERROR => return error.CorruptedInput,
                    c.BZ_DATA_ERROR => return error.CorruptedInput,
                    c.BZ_DATA_ERROR_MAGIC => return error.CorruptedInput,
                    c.BZ_MEM_ERROR => return error.Overflow,
                    else => {},
                }
            }

            return output.len - self.stream.avail_out;
        }

        fn initStream(self: *Self) !void {
            // TODO: Support for Zig allocators using custom allocation methods is planned for
            // TODO: later. So we'll move to that once this is done.
            self.stream.* = std.mem.zeroes(c.bz_stream);

            if (c.BZ2_bzDecompressInit(self.stream, 0, 0) != c.BZ_OK) {
                self.allocator.destroy(self.stream);
                return error.Bzip2InitializationFailure;
            }
        }
    };
}

///
/// Provides a developer-friendly facade over `Decompress(...).init(...)` method calls.
///
pub fn decompressReader(allocator: std.mem.Allocator, reader: anytype) !Decompress(@TypeOf(reader)) {
    return try Decompress(@TypeOf(reader)).init(allocator, reader);
}

test "Init" {
    var sourceBuffer = std.io.fixedBufferStream("Test 123");
    const source = sourceBuffer.reader();
    var decompressor = try Decompress(@TypeOf(source)).init(std.testing.allocator, source);
    defer decompressor.deinit();
}

test "Decompress Reader" {
    var sourceBuffer = std.io.fixedBufferStream("Test 123");
    var decompressor = try decompressReader(std.testing.allocator, sourceBuffer.reader());
    defer decompressor.deinit();
}

test "Decompress Known Data" {
    var testData = try std.fs.cwd().openFile("assets/example.bz2", .{});
    defer testData.close();

    const testDataReader = testData.reader();
    var bzip2Stream = try Decompress(@TypeOf(testDataReader)).init(std.testing.allocator, testDataReader);
    defer bzip2Stream.deinit();

    var buffer = try std.testing.allocator.alloc(u8, 256);
    defer std.testing.allocator.free(buffer);

    const bytesRead = try bzip2Stream.read(buffer);
    try std.testing.expectEqual(bytesRead, 12);
    try std.testing.expectEqualStrings(buffer[0..bytesRead], "HELLO WORLD\n");
}

test "Partial Reads Supported" {
    var testData = try std.fs.cwd().openFile("assets/example.bz2", .{});
    defer testData.close();

    const testDataReader = testData.reader();
    var bzip2Stream = try Decompress(@TypeOf(testDataReader)).init(std.testing.allocator, testDataReader);
    defer bzip2Stream.deinit();

    var buffer = try std.testing.allocator.alloc(u8, 256);
    defer std.testing.allocator.free(buffer);

    var bytesRead = try bzip2Stream.read(buffer[0..5]);
    bytesRead += try bzip2Stream.read(buffer[5..]);
    try std.testing.expectEqualStrings(buffer[0..bytesRead], "HELLO WORLD\n");
}

test "Re-populating compressed data" {
    var testData = try std.fs.cwd().openFile("assets/example.bz2", .{});
    defer testData.close();

    const testDataReader = testData.reader();
    var bzip2Stream = try Decompress(@TypeOf(testDataReader)).initWithBufferSize(std.testing.allocator, testDataReader, 12);
    defer bzip2Stream.deinit();

    var buffer = try std.testing.allocator.alloc(u8, 256);
    defer std.testing.allocator.free(buffer);

    const bytesRead = try bzip2Stream.read(buffer);
    try std.testing.expectEqual(bytesRead, 12);
    try std.testing.expectEqualStrings(buffer[0..bytesRead], "HELLO WORLD\n");
}

test "Detects bad Bzip2 Data" {
    var sourceBuffer = std.io.fixedBufferStream("OOPS");
    const sourceReader = sourceBuffer.reader();
    var bzip2Stream = try Decompress(@TypeOf(sourceReader)).init(std.testing.allocator, sourceReader);
    defer bzip2Stream.deinit();

    const buf: []u8 = try std.testing.allocator.alloc(u8, 256);
    defer std.testing.allocator.free(buf);

    try std.testing.expectError(error.CorruptedInput, bzip2Stream.read(buf));
}
