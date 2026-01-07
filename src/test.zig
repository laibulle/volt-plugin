const std = @import("std");
const wdf = @import("wdf/components.zig");
const tube = @import("wdf/tube.zig");
const preamp = @import("circuits/preamp.zig");
const tonestack = @import("audio/tonestack.zig");
const cabinet = @import("audio/cabinet.zig");

test "Resistor wave functions" {
    var resistor = wdf.Resistor.init(1000.0);

    // Test wave up - resistor should be perfectly matched (reflection = 0)
    const reflected = resistor.base.waveUp(1.0);
    try std.testing.expectApproxEqAbs(0.0, reflected, 0.001);

    // Test voltage calculation
    const voltage = resistor.voltage();
    try std.testing.expectApproxEqAbs(0.5, voltage, 0.001);
}

test "Capacitor state management" {
    const sample_rate = 48000.0;
    var capacitor = wdf.Capacitor.init(1.0e-6, sample_rate);

    // First sample - should reflect 0 (no stored state)
    const reflected1 = capacitor.base.waveUp(1.0);
    try std.testing.expectApproxEqAbs(0.0, reflected1, 0.001);

    // Second sample - should reflect previous input
    const reflected2 = capacitor.base.waveUp(2.0);
    try std.testing.expectApproxEqAbs(1.0, reflected2, 0.001);
}

test "Voltage source" {
    var source = wdf.VoltageSource.init(1000.0);
    source.setVoltage(5.0);

    // Test wave reflection
    const reflected = source.base.waveUp(0.0);
    try std.testing.expectApproxEqAbs(10.0, reflected, 0.001);
}

test "Tube model initialization" {
    const allocator = std.testing.allocator;
    var triode = try tube.Triode12AX7.init(allocator, 1500.0, 100000.0);

    // Verify lookup table is populated
    try std.testing.expect(triode.lookup_table[0] == 0.0); // At cutoff, current should be 0

    // Verify operating point
    try std.testing.expectApproxEqAbs(200.0, triode.last_vpk, 0.001);
}

test "Tube amplifier initialization" {
    const allocator = std.testing.allocator;
    const sample_rate = 48000.0;

    var amp = try preamp.TubeAmplifier.init(allocator, sample_rate);
    defer amp.deinit();

    // Test parameter setting
    amp.setGain(0.7);
    amp.setBass(0.6);
    amp.setTreble(0.8);
    amp.setMaster(0.5);

    try std.testing.expectApproxEqAbs(0.7, amp.preamp.gain, 0.001);
}

test "Amplifier processes signal without crashing" {
    const allocator = std.testing.allocator;
    const sample_rate = 48000.0;

    var amp = try preamp.TubeAmplifier.init(allocator, sample_rate);
    defer amp.deinit();

    amp.setGain(0.5);
    amp.setBass(0.5);
    amp.setTreble(0.5);
    amp.setMaster(0.5);

    // Process some samples
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const input = @sin(@as(f64, @floatFromInt(i)) * 0.01);
        const output = amp.processSample(input);

        // Output should be in reasonable range
        try std.testing.expect(output >= -10.0 and output <= 10.0);
    }
}

test "Tonestack EQ" {
    const sample_rate = 48000.0;
    var tone = tonestack.Tonestack.init(sample_rate);

    // Set bass boost
    tone.setBass(1.0);
    try std.testing.expect(tone.bass_filter.b0 != 1.0); // Filter should be configured

    // Set treble cut
    tone.setTreble(0.0);
    try std.testing.expect(tone.treble_filter.b0 != 1.0);

    // Process a sample
    const output = tone.process(1.0);
    try std.testing.expect(@abs(output) < 10.0);
}

test "Cabinet simulator" {
    const allocator = std.testing.allocator;
    const ir_length = 2048;

    var cab = try cabinet.CabinetSimulator.init(allocator, ir_length);
    defer cab.deinit();

    // Process samples
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const input = if (i == 0) 1.0 else 0.0; // Impulse
        const output = cab.processSample(input);

        // Output should be finite
        try std.testing.expect(std.math.isFinite(output));
    }
}

test "Parameter clamping" {
    const allocator = std.testing.allocator;
    const sample_rate = 48000.0;

    var amp = try preamp.TubeAmplifier.init(allocator, sample_rate);
    defer amp.deinit();

    // Test out-of-range values are clamped
    amp.setGain(-1.0);
    amp.setBass(2.0);
    amp.setTreble(-0.5);
    amp.setMaster(1.5);

    // All should be clamped to valid range
    try std.testing.expect(amp.preamp.gain >= 0.0 and amp.preamp.gain <= 1.0);
    try std.testing.expect(amp.master_volume >= 0.0 and amp.master_volume <= 1.0);
}
