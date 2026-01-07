const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the CLAP plugin as a shared library
    const plugin = b.addSharedLibrary(.{
        .name = "volt",
        .root_source_file = b.path("src/plugin/plugin.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Add CLAP headers path
    plugin.addIncludePath(b.path("libs/clap/include"));

    // Build artifact
    b.installArtifact(plugin);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmarks
    const bench = b.addExecutable(.{
        .name = "bench",
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Install step (copy to system plugin directory)
    const install_step = b.step("install-plugin", "Install plugin to system directory");
    const install_cmd = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
    });

    const plugin_dir = if (target.result.os.tag == .macos)
        "mkdir -p ~/Library/Audio/Plug-Ins/CLAP && cp zig-out/lib/libvolt.dylib ~/Library/Audio/Plug-Ins/CLAP/volt.clap"
    else
        "mkdir -p ~/.clap && cp zig-out/lib/libvolt.so ~/.clap/volt.clap";

    install_cmd.addArg(plugin_dir);
    install_cmd.step.dependOn(&plugin.step);
    install_step.dependOn(&install_cmd.step);
}
