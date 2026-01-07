const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create output directory
    const mkdir_cmd = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", "zig-out/lib" });

    // Build plugin as a shared library
    const opt_flag = switch (optimize) {
        .Debug => "-ODebug",
        .ReleaseSafe => "-OReleaseSafe",
        .ReleaseFast => "-OReleaseFast",
        .ReleaseSmall => "-OReleaseSmall",
    };

    const compile_cmd = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build-lib",
        "-dynamic",
        "-lc",
        "-I",
        "libs/clap/include",
        opt_flag,
        "src/plugin/plugin.zig",
        "-femit-bin=zig-out/lib/libvolt.dylib",
    });

    compile_cmd.step.dependOn(&mkdir_cmd.step);
    b.default_step.dependOn(&compile_cmd.step);

    // Tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmarks
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = bench_mod,
    });

    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Install step
    const install_step = b.step("install-plugin", "Install plugin to system directory");
    const install_cmd = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "mkdir -p ~/Library/Audio/Plug-Ins/CLAP && cp zig-out/lib/libvolt.dylib ~/Library/Audio/Plug-Ins/CLAP/volt.clap",
    });
    install_cmd.step.dependOn(&compile_cmd.step);
    install_step.dependOn(&install_cmd.step);
}
