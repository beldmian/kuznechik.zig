const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const libModule = b.addModule("kuznechik", .{
        .root_source_file = b.path("src/kuznechik.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Main library artifact
    const lib = b.addLibrary(.{
        .name = "kuznechik",
        .root_module = libModule,
    });

    b.installArtifact(lib);

    // Library Unit Tests
    const lib_unit_tests = b.addTest(.{
        .root_module = libModule,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const benchmarkModule = b.addModule("kuznechik", .{
        .root_source_file = b.path("test/benchmarks.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Benchmark executable
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_module = benchmarkModule,
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

    // === Fuzzing Infrastructure ===
    // To build instrumented binaries for AFL++:
    //   AFL_CC=afl-clang-fast AFL_CXX=afl-clang-fast++ zig build fuzz
    // This uses AFL++'s compiler wrappers for instrumentation.

    // Import kuznechik module for all fuzz harnesses
    const kuznechik_fuzz_module = b.createModule(.{
        .root_source_file = b.path("src/kuznechik.zig"),
    });

    // Round-trip encryption/decryption fuzzer
    const roundtrip_module = b.createModule(.{
        .root_source_file = b.path("test/fuzz/roundtrip.zig"),
        .target = target,
        .optimize = .Debug,
    });
    roundtrip_module.addImport("kuznechik", kuznechik_fuzz_module);

    const roundtrip_fuzzer = b.addExecutable(.{
        .name = "roundtrip",
        .root_module = roundtrip_module,
    });

    const install_roundtrip = b.addInstallArtifact(roundtrip_fuzzer, .{});
    const build_roundtrip_step = b.step("fuzz-round-trip", "Build round-trip encryption/decryption fuzzer");
    build_roundtrip_step.dependOn(&install_roundtrip.step);

    const run_roundtrip = b.addRunArtifact(roundtrip_fuzzer);
    const run_roundtrip_step = b.step("test-fuzz-round-trip", "Run round-trip fuzzer test");
    run_roundtrip_step.dependOn(&run_roundtrip.step);

    // Key schedule validation fuzzer
    const key_schedule_module = b.createModule(.{
        .root_source_file = b.path("test/fuzz/key_schedule.zig"),
        .target = target,
        .optimize = .Debug,
    });
    key_schedule_module.addImport("kuznechik", kuznechik_fuzz_module);

    const key_schedule_fuzzer = b.addExecutable(.{
        .name = "key_schedule",
        .root_module = key_schedule_module,
    });

    const install_key_schedule = b.addInstallArtifact(key_schedule_fuzzer, .{});
    const build_key_schedule_step = b.step("fuzz-key-schedule", "Build key schedule validation fuzzer");
    build_key_schedule_step.dependOn(&install_key_schedule.step);

    const run_key_schedule = b.addRunArtifact(key_schedule_fuzzer);
    const run_key_schedule_step = b.step("test-fuzz-key-schedule", "Run key schedule fuzzer test");
    run_key_schedule_step.dependOn(&run_key_schedule.step);

    // LS round-trip fuzzer
    const ls_roundtrip_module = b.createModule(.{
        .root_source_file = b.path("test/fuzz/ls_roundtrip.zig"),
        .target = target,
        .optimize = .Debug,
    });
    ls_roundtrip_module.addImport("kuznechik", kuznechik_fuzz_module);

    const ls_roundtrip_fuzzer = b.addExecutable(.{
        .name = "ls_roundtrip",
        .root_module = ls_roundtrip_module,
    });

    const install_ls_roundtrip = b.addInstallArtifact(ls_roundtrip_fuzzer, .{});
    const build_ls_roundtrip_step = b.step("fuzz-ls-roundtrip", "Build LS round-trip fuzzer");
    build_ls_roundtrip_step.dependOn(&install_ls_roundtrip.step);

    const run_ls_roundtrip = b.addRunArtifact(ls_roundtrip_fuzzer);
    const run_ls_roundtrip_step = b.step("test-fuzz-ls-roundtrip", "Run LS round-trip fuzzer test");
    run_ls_roundtrip_step.dependOn(&run_ls_roundtrip.step);

    // Build all fuzzers
    const build_fuzz_step = b.step("fuzz-build", "Build all fuzzers");
    build_fuzz_step.dependOn(&install_roundtrip.step);
    build_fuzz_step.dependOn(&install_key_schedule.step);
    build_fuzz_step.dependOn(&install_ls_roundtrip.step);

    // Test all fuzzers (standalone validation)
    const test_fuzz_step = b.step("fuzz-test", "Test all fuzzers (standalone)");
    test_fuzz_step.dependOn(&run_roundtrip.step);
    test_fuzz_step.dependOn(&run_key_schedule.step);
    test_fuzz_step.dependOn(&run_ls_roundtrip.step);

    // Main fuzz step - builds all fuzzers (can be run with AFL++)
    const fuzz_step = b.step("fuzz", "Build all fuzzers for use with AFL++");
    fuzz_step.dependOn(&install_roundtrip.step);
    fuzz_step.dependOn(&install_key_schedule.step);
    fuzz_step.dependOn(&install_ls_roundtrip.step);

    // Corpus generation - creates seed corpus files from test vectors
    const corpus_step = b.step("fuzz-corpus", "Generate seed corpus files from test vectors");
    corpus_step.dependOn(&install_roundtrip.step);
    corpus_step.dependOn(&install_key_schedule.step);
    corpus_step.dependOn(&install_ls_roundtrip.step);

    // Run each fuzzer with corpus to ensure files are valid
    const run_corpus_roundtrip = b.addRunArtifact(roundtrip_fuzzer);
    run_corpus_roundtrip.addFileArg(b.path("test/fuzz/corpus/round_trip/rfc7801_test_vector"));
    corpus_step.dependOn(&run_corpus_roundtrip.step);

    const run_corpus_key_schedule = b.addRunArtifact(key_schedule_fuzzer);
    run_corpus_key_schedule.addFileArg(b.path("test/fuzz/corpus/key_schedule/rfc7801_test_vector"));
    corpus_step.dependOn(&run_corpus_key_schedule.step);

    const run_corpus_ls_roundtrip = b.addRunArtifact(ls_roundtrip_fuzzer);
    run_corpus_ls_roundtrip.addFileArg(b.path("test/fuzz/corpus/ls_roundtrip/ls_test_vector"));
    corpus_step.dependOn(&run_corpus_ls_roundtrip.step);
}
