const std = @import("std");
const wdf = @import("../wdf/components.zig");
const tube = @import("../wdf/tube.zig");
const tonestack = @import("../audio/tonestack.zig");
const cabinet = @import("../audio/cabinet.zig");

/// Simple 12AX7 triode preamp stage
/// Circuit topology: Input -> Grid resistor -> Tube -> Plate resistor -> Output
///                                    |-> Grid cap to ground
///                                    |-> Cathode resistor + bypass cap
pub const TubePreamp = struct {
    allocator: std.mem.Allocator,
    sample_rate: f64,

    // Input
    input_source: wdf.VoltageSource,

    // Grid circuit
    grid_resistor: wdf.Resistor, // 1M grid leak resistor
    coupling_cap: wdf.Capacitor, // 0.1uF coupling capacitor

    // Tube
    tube_stage: tube.Triode12AX7,

    // Cathode circuit
    cathode_resistor: wdf.Resistor, // 1.5k cathode resistor
    cathode_bypass_cap: wdf.Capacitor, // 25uF bypass capacitor

    // Plate circuit
    plate_resistor: wdf.Resistor, // 100k plate resistor

    // Output
    output_voltage: f64,

    // Gain control
    gain: f64,

    pub fn init(allocator: std.mem.Allocator, sample_rate: f64) !TubePreamp {
        // Component values (typical 12AX7 preamp)
        const input_impedance = 1.0e6; // 1M input impedance
        const grid_resistance = 1.0e6; // 1M grid leak
        const coupling_capacitance = 0.1e-6; // 0.1uF
        const cathode_resistance = 1.5e3; // 1.5k
        const cathode_capacitance = 25.0e-6; // 25uF bypass cap
        const plate_resistance = 100.0e3; // 100k plate load

        var preamp = TubePreamp{
            .allocator = allocator,
            .sample_rate = sample_rate,
            .input_source = wdf.VoltageSource.init(input_impedance),
            .grid_resistor = wdf.Resistor.init(grid_resistance),
            .coupling_cap = wdf.Capacitor.init(coupling_capacitance, sample_rate),
            .tube_stage = try tube.Triode12AX7.init(allocator, cathode_resistance, plate_resistance),
            .cathode_resistor = wdf.Resistor.init(cathode_resistance),
            .cathode_bypass_cap = wdf.Capacitor.init(cathode_capacitance, sample_rate),
            .plate_resistor = wdf.Resistor.init(plate_resistance),
            .output_voltage = 0.0,
            .gain = 0.5, // Default 50% gain
        };

        return preamp;
    }

    pub fn deinit(self: *TubePreamp) void {
        _ = self;
        // No dynamic allocations to free in current implementation
    }

    pub fn setGain(self: *TubePreamp, gain: f64) void {
        self.gain = @max(0.0, @min(1.0, gain));
    }

    pub fn reset(self: *TubePreamp) void {
        self.input_source.base.reset();
        self.grid_resistor.base.reset();
        self.coupling_cap.base.reset();
        self.tube_stage.base.reset();
        self.cathode_resistor.base.reset();
        self.cathode_bypass_cap.base.reset();
        self.plate_resistor.base.reset();
        self.output_voltage = 0.0;
    }

    /// Process a single sample through the tube preamp
    pub fn processSample(self: *TubePreamp, input: f64) f64 {
        // Apply gain to input (scales the input signal)
        const gained_input = input * (1.0 + self.gain * 20.0); // 0-20x gain range

        // Set input voltage source
        self.input_source.setVoltage(gained_input);

        // Simplified WDF processing:
        // In a full implementation, we would properly connect all components
        // with adaptors and solve the wave scattering network

        // For now, use a simplified approach:
        // 1. Input passes through coupling cap
        const cap_wave = self.coupling_cap.base.waveUp(self.input_source.base.waveUp(0.0));

        // 2. Signal to grid through grid resistor
        const grid_wave = self.grid_resistor.base.waveUp(cap_wave);

        // 3. Tube processes the signal
        const tube_wave = self.tube_stage.base.waveUp(grid_wave);

        // 4. Plate resistor to output
        const plate_wave = self.plate_resistor.base.waveUp(tube_wave);

        // Extract output voltage
        self.output_voltage = (plate_wave) / (2.0 * self.plate_resistor.resistance);

        // Soft clipping for safety
        const output = self.softClip(self.output_voltage * 0.1); // Scale down

        return output;
    }

    /// Soft clipping using tanh
    fn softClip(self: *const TubePreamp, x: f64) f64 {
        _ = self;
        // Tanh soft clipper with some extra drive
        const drive = 1.5;
        return std.math.tanh(x * drive) / drive;
    }
};

/// Complete tube amplifier with preamp, tonestack, cabinet sim, and master volume
pub const TubeAmplifier = struct {
    allocator: std.mem.Allocator,
    preamp: TubePreamp,
    tone: tonestack.Tonestack,
    cabinet_sim: cabinet.CabinetSimulator,

    // Master volume
    master_volume: f64,

    pub fn init(allocator: std.mem.Allocator, sample_rate: f64) !TubeAmplifier {
        const cab_ir_length = 2048; // 43ms @ 48kHz

        return TubeAmplifier{
            .allocator = allocator,
            .preamp = try TubePreamp.init(allocator, sample_rate),
            .tone = tonestack.Tonestack.init(sample_rate),
            .cabinet_sim = try cabinet.CabinetSimulator.init(allocator, cab_ir_length),
            .master_volume = 0.5,
        };
    }

    pub fn deinit(self: *TubeAmplifier) void {
        self.preamp.deinit();
        self.cabinet_sim.deinit();
    }

    pub fn setGain(self: *TubeAmplifier, gain: f64) void {
        self.preamp.setGain(gain);
    }

    pub fn setBass(self: *TubeAmplifier, bass: f64) void {
        self.tone.setBass(@max(0.0, @min(1.0, bass)));
    }

    pub fn setTreble(self: *TubeAmplifier, treble: f64) void {
        self.tone.setTreble(@max(0.0, @min(1.0, treble)));
    }

    pub fn setMaster(self: *TubeAmplifier, master: f64) void {
        self.master_volume = @max(0.0, @min(1.0, master));
    }

    pub fn reset(self: *TubeAmplifier) void {
        self.preamp.reset();
        self.tone.reset();
        self.cabinet_sim.reset();
    }

    pub fn processSample(self: *TubeAmplifier, input: f64) f64 {
        // Preamp stage
        var output = self.preamp.processSample(input);

        // Tonestack (EQ)
        output = self.tone.process(output);

        // Cabinet simulation
        output = self.cabinet_sim.processSample(output);

        // Master volume
        output *= self.master_volume;

        return output;
    }
};
