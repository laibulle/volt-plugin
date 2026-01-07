const std = @import("std");
const preamp = @import("circuits/preamp.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== Volt Tube Amp Performance Benchmark ===\n\n", .{});

    const sample_rate = 48000.0;
    const test_iterations = 100_000;

    // Initialize amplifier
    var amp = try preamp.TubeAmplifier.init(allocator, sample_rate);
    defer amp.deinit();

    amp.setGain(0.7);
    amp.setBass(0.6);
    amp.setTreble(0.8);
    amp.setMaster(0.5);

    // Warm up
    try stdout.print("Warming up...\n", .{});
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const input = @sin(@as(f64, @floatFromInt(i)) * 0.01);
        _ = amp.processSample(input);
    }

    // Benchmark
    try stdout.print("Running benchmark ({} iterations)...\n", .{test_iterations});

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    i = 0;
    var sum: f64 = 0.0;
    while (i < test_iterations) : (i += 1) {
        const input = @sin(@as(f64, @floatFromInt(i)) * 0.001);
        const output = amp.processSample(input);
        sum += output; // Prevent optimization
    }

    const elapsed = timer.read() - start;

    // Calculate metrics
    const elapsed_sec = @as(f64, @floatFromInt(elapsed)) / 1_000_000_000.0;
    const samples_per_sec = @as(f64, @floatFromInt(test_iterations)) / elapsed_sec;
    const cpu_percent = (sample_rate / samples_per_sec) * 100.0;
    const ns_per_sample = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(test_iterations));

    // Estimate cycles per sample (assuming 3GHz CPU)
    const assumed_cpu_freq = 3.0e9;
    const cycles_per_sample = (ns_per_sample / 1e9) * assumed_cpu_freq;

    try stdout.print("\n=== Results ===\n", .{});
    try stdout.print("Total time: {d:.3} seconds\n", .{elapsed_sec});
    try stdout.print("Samples per second: {d:.0}\n", .{samples_per_sec});
    try stdout.print("Nanoseconds per sample: {d:.2}\n", .{ns_per_sample});
    try stdout.print("Estimated cycles per sample: {d:.0}\n", .{cycles_per_sample});
    try stdout.print("CPU usage @ 48kHz: {d:.2}%\n", .{cpu_percent});
    try stdout.print("CPU usage @ 96kHz: {d:.2}%\n", .{cpu_percent * 2.0});
    try stdout.print("\n", .{});

    // Verify output
    try stdout.print("Sanity check (sum): {d:.6}\n", .{sum});

    // Performance targets
    try stdout.print("\n=== Target Comparison ===\n", .{});
    if (cpu_percent < 10.0) {
        try stdout.print("✅ CPU usage target met (<10%)\n", .{});
    } else {
        try stdout.print("❌ CPU usage target NOT met (target: <10%, actual: {d:.2}%)\n", .{cpu_percent});
    }

    if (cycles_per_sample < 100.0) {
        try stdout.print("✅ Cycles/sample excellent (<100)\n", .{});
    } else if (cycles_per_sample < 1000.0) {
        try stdout.print("⚠️  Cycles/sample acceptable (<1000)\n", .{});
    } else {
        try stdout.print("❌ Cycles/sample high (>{d:.0})\n", .{cycles_per_sample});
    }

    try stdout.print("\n", .{});
}
