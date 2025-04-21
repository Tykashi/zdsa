const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const serpent_mod = b.dependency("serpent", .{}).module("serpent");
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/mpmc.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zdsa",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .test_runner = .{ .path = serpent_mod.root_source_file.?, .mode = .simple },
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    b.modules.put("zdsa", lib_mod) catch unreachable;
}
