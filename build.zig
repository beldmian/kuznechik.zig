const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opts = .{ .target = target, .optimize = optimize };

    // Main library artifact
    const lib = b.addStaticLibrary(.{
        .name = "kuznechik",
        .root_source_file = b.path("src/kuznechik.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    // Library Unit Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/kuznechik.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Benchmark executable
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("test/benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    benchmark.root_module.addImport("kuznechik", &lib.root_module);

    const zbench_module = b.dependency("zbench", opts).module("zbench");
    benchmark.root_module.addImport("zbench", zbench_module);

    const run_lib_benchmark = b.addRunArtifact(benchmark);
    const benchmark_step = b.step("bench", "Run lib benchmark");
    benchmark_step.dependOn(&run_lib_benchmark.step);
}
