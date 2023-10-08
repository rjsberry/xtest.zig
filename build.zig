const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rtt_dep = b.dependency("rtt", .{
        .target = target,
        .optimize = optimize,
    });

    _ = b.addModule("xtest", .{
        .source_file = .{ .path = "xtest.zig" },
        .dependencies = &.{
            .{ .name = "rtt", .module = rtt_dep.module("rtt") },
        },
    });
}
