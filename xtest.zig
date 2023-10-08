// The contents of this file is dual-licensed under the MIT or 0BSD license.

const std = @import("std");
const builtin = @import("builtin");
const rtt = @import("rtt");

const meta = std.meta;

/// The `xtest` runner.
///
/// You will need to create your own test runner with an entry point to your
/// MCU that calls this function.
///
/// An example for the Raspberry Pi Pico H is shown below:
///
/// ```zig
/// usingnamespace @import("rp2040");
///
/// const xtest = @import("xtest");
///
/// export fn main() callconv(.C) noreturn {
///     xtest.main();
/// }
/// ```
pub fn main() noreturn {
    if (builtin.is_test) {
        for (builtin.test_functions) |test_function| {
            rtt.print("executing \x1b[36m{s}\x1b[0m... ", .{test_function.name});
            test_function.func() catch |err| {
                fail("{}", .{err});
            };
            rtt.println("\x1b[32mok\x1b[0m", .{});
        }

        rtt.println("all tests passed", .{});

        while (true) {
            @breakpoint();
        }
    }

    @panic("cannot call `xtest.main` outside of test runners");
}

/// Reports a test failure then panics.
fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    rtt.print("\x1b[1;31merror:\x1b[0m ", .{});
    rtt.println(fmt, args);
    @panic("test suite failed");
}

/// Fails the test when the two values are not equal.
pub fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    switch (@typeInfo(@TypeOf(actual))) {
        .NoReturn,
        .Opaque,
        .Frame,
        .AnyFrame,
        => @compileError(
            "value of type " ++ @typeName(@TypeOf(actual)) ++ " encountered",
        ),

        .Undefined,
        .Null,
        .Void,
        => return,

        .Type => {
            if (actual != expected) {
                fail(
                    "expected type {s}, found type {s}",
                    .{ @typeName(expected), @typeName(actual) },
                );
            }
        },

        .Bool,
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        .EnumLiteral,
        .Enum,
        .Fn,
        .ErrorSet,
        => {
            if (actual != expected) {
                fail("expected {}, found {}", .{ expected, actual });
            }
        },

        .Pointer => |pointer| {
            switch (pointer.size) {
                .One, .Many, .C => {
                    if (actual != expected) {
                        fail(
                            "expected {*}, found {*}",
                            .{ expected, actual },
                        );
                    }
                },
                .Slice => {
                    if (actual.ptr != expected.ptr) {
                        fail(
                            "expected slice ptr {*}, found {*}",
                            .{ expected.ptr, actual.ptr },
                        );
                    }
                    if (actual.len != expected.len) {
                        fail(
                            "expected slice len {}, found {}",
                            .{ expected.len, actual.len },
                        );
                    }
                },
            }
        },

        .Array => |array| try expectEqualSlices(
            array.child,
            &expected,
            &actual,
        ),

        .Vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                if (!meta.eql(expected[i], actual[i])) {
                    fail("index {} incorrect. expected {}, found {}", .{
                        i, expected[i], actual[i],
                    });
                }
            }
        },

        .Struct => |structType| {
            inline for (structType.fields) |field| {
                try expectEqual(
                    @field(expected, field.name),
                    @field(actual, field.name),
                );
            }
        },

        .Union => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("Unable to compare untagged union values");
            }

            const Tag = meta.Tag(@TypeOf(expected));

            const expectedTag = @as(Tag, expected);
            const actualTag = @as(Tag, actual);

            try expectEqual(expectedTag, actualTag);

            // we only reach this loop if the tags are equal

            inline for (meta.fields(@TypeOf(actual))) |fld| {
                if (std.mem.eql(u8, fld.name, @tagName(actualTag))) {
                    try expectEqual(
                        @field(expected, fld.name),
                        @field(actual, fld.name),
                    );
                    return;
                }
            }

            // we iterate over *all* union fields

            // => we should never get here as the loop above is

            //    including all possible values.

            unreachable;
        },

        .Optional => {
            if (expected) |expected_payload| {
                if (actual) |actual_payload| {
                    try expectEqual(expected_payload, actual_payload);
                } else {
                    fail(
                        "expected {any}, found null",
                        .{expected_payload},
                    );
                }
            } else {
                if (actual) |actual_payload| {
                    fail(
                        "expected null, found {any}",
                        .{actual_payload},
                    );
                }
            }
        },

        .ErrorUnion => {
            if (expected) |expected_payload| {
                if (actual) |actual_payload| {
                    try expectEqual(expected_payload, actual_payload);
                } else |actual_err| {
                    fail(
                        "expected {any}, found {}",
                        .{ expected_payload, actual_err },
                    );
                }
            } else |expected_err| {
                if (actual) |actual_payload| {
                    fail(
                        "expected {}, found {any}",
                        .{ expected_err, actual_payload },
                    );
                } else |actual_err| {
                    try expectEqual(expected_err, actual_err);
                }
            }
        },
    }
}

/// Fails the test when the two slices are not equal.
pub fn expectEqualSlices(
    comptime T: type,
    expected: []const T,
    actual: []const T,
) !void {
    try expectEqual(expected.len, actual.len);

    for (expected.items, actual.items) |expected_item, actual_item| {
        try expectEqual(expected_item, actual_item);
    }
}
