const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    // Create module for our library to be used by the benchmark
    const kuznechik_module = b.createModule(.{
        .root_source_file = b.path("src/kuznechik.zig"),
    });

    // Add module imports
    benchmark.root_module.addImport("kuznechik", kuznechik_module);

    const run_lib_benchmark = b.addRunArtifact(benchmark);
    const run_benchmark_step = b.step("bench", "Run lib benchmark");
    run_benchmark_step.dependOn(&run_lib_benchmark.step);

    const build_benchmark = b.addInstallArtifact(benchmark, .{});
    const build_benchmark_step = b.step("build_bench", "Build lib benchmark executable");
    build_benchmark_step.dependOn(&build_benchmark.step);
}
