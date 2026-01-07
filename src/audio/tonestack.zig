const std = @import("std");

/// Biquad filter for EQ (bass and treble controls)
pub const Biquad = struct {
    // Coefficients
    b0: f64,
    b1: f64,
    b2: f64,
    a1: f64,
    a2: f64,

    // State
    x1: f64,
    x2: f64,
    y1: f64,
    y2: f64,

    pub fn init() Biquad {
        return .{
            .b0 = 1.0,
            .b1 = 0.0,
            .b2 = 0.0,
            .a1 = 0.0,
            .a2 = 0.0,
            .x1 = 0.0,
            .x2 = 0.0,
            .y1 = 0.0,
            .y2 = 0.0,
        };
    }

    pub fn reset(self: *Biquad) void {
        self.x1 = 0.0;
        self.x2 = 0.0;
        self.y1 = 0.0;
        self.y2 = 0.0;
    }

    /// Design a low-shelf filter (for bass control)
    pub fn makeLowShelf(self: *Biquad, sample_rate: f64, freq: f64, gain_db: f64) void {
        const a = std.math.pow(f64, 10.0, gain_db / 40.0);
        const omega = 2.0 * std.math.pi * freq / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / 2.0 * @sqrt((a + 1.0 / a) * (1.0 / 0.7 - 1.0) + 2.0);

        const a0 = (a + 1.0) + (a - 1.0) * cos_omega + 2.0 * @sqrt(a) * alpha;
        self.b0 = (a * ((a + 1.0) - (a - 1.0) * cos_omega + 2.0 * @sqrt(a) * alpha)) / a0;
        self.b1 = (2.0 * a * ((a - 1.0) - (a + 1.0) * cos_omega)) / a0;
        self.b2 = (a * ((a + 1.0) - (a - 1.0) * cos_omega - 2.0 * @sqrt(a) * alpha)) / a0;
        self.a1 = (-2.0 * ((a - 1.0) + (a + 1.0) * cos_omega)) / a0;
        self.a2 = ((a + 1.0) + (a - 1.0) * cos_omega - 2.0 * @sqrt(a) * alpha) / a0;
    }

    /// Design a high-shelf filter (for treble control)
    pub fn makeHighShelf(self: *Biquad, sample_rate: f64, freq: f64, gain_db: f64) void {
        const a = std.math.pow(f64, 10.0, gain_db / 40.0);
        const omega = 2.0 * std.math.pi * freq / sample_rate;
        const sin_omega = @sin(omega);
        const cos_omega = @cos(omega);
        const alpha = sin_omega / 2.0 * @sqrt((a + 1.0 / a) * (1.0 / 0.7 - 1.0) + 2.0);

        const a0 = (a + 1.0) - (a - 1.0) * cos_omega + 2.0 * @sqrt(a) * alpha;
        self.b0 = (a * ((a + 1.0) + (a - 1.0) * cos_omega + 2.0 * @sqrt(a) * alpha)) / a0;
        self.b1 = (-2.0 * a * ((a - 1.0) + (a + 1.0) * cos_omega)) / a0;
        self.b2 = (a * ((a + 1.0) + (a - 1.0) * cos_omega - 2.0 * @sqrt(a) * alpha)) / a0;
        self.a1 = (2.0 * ((a - 1.0) - (a + 1.0) * cos_omega)) / a0;
        self.a2 = ((a + 1.0) - (a - 1.0) * cos_omega - 2.0 * @sqrt(a) * alpha) / a0;
    }

    pub fn process(self: *Biquad, input: f64) f64 {
        const output = self.b0 * input + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2;

        self.x2 = self.x1;
        self.x1 = input;
        self.y2 = self.y1;
        self.y1 = output;

        return output;
    }
};

/// Simple tonestack with bass and treble controls
pub const Tonestack = struct {
    bass_filter: Biquad,
    treble_filter: Biquad,
    sample_rate: f64,

    pub fn init(sample_rate: f64) Tonestack {
        var tonestack = Tonestack{
            .bass_filter = Biquad.init(),
            .treble_filter = Biquad.init(),
            .sample_rate = sample_rate,
        };

        // Initialize with neutral settings
        tonestack.setBass(0.5);
        tonestack.setTreble(0.5);

        return tonestack;
    }

    pub fn reset(self: *Tonestack) void {
        self.bass_filter.reset();
        self.treble_filter.reset();
    }

    /// Set bass control (0.0 = -12dB, 0.5 = 0dB, 1.0 = +12dB)
    pub fn setBass(self: *Tonestack, value: f64) void {
        const gain_db = (value - 0.5) * 24.0; // -12dB to +12dB
        self.bass_filter.makeLowShelf(self.sample_rate, 200.0, gain_db);
    }

    /// Set treble control (0.0 = -12dB, 0.5 = 0dB, 1.0 = +12dB)
    pub fn setTreble(self: *Tonestack, value: f64) void {
        const gain_db = (value - 0.5) * 24.0; // -12dB to +12dB
        self.treble_filter.makeHighShelf(self.sample_rate, 2000.0, gain_db);
    }

    pub fn process(self: *Tonestack, input: f64) f64 {
        var output = self.bass_filter.process(input);
        output = self.treble_filter.process(output);
        return output;
    }
};
