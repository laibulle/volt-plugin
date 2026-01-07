const std = @import("std");

/// Cabinet impulse response convolver
/// Uses time-domain convolution for simplicity (can upgrade to FFT later)
pub const CabinetSimulator = struct {
    allocator: std.mem.Allocator,
    ir: []f64,
    ir_length: usize,
    buffer: []f64,
    buffer_pos: usize,

    pub fn init(allocator: std.mem.Allocator, ir_length: usize) !CabinetSimulator {
        const ir = try allocator.alloc(f64, ir_length);
        const buffer = try allocator.alloc(f64, ir_length);

        // Initialize with simple cabinet IR (simplified for prototype)
        // In production, this would be loaded from a file or embedded data
        for (0..ir_length) |i| {
            // Simple exponential decay impulse (approximates cabinet resonance)
            const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(ir_length));
            const decay = @exp(-t * 5.0);
            const resonance = @sin(t * std.math.pi * 20.0); // Some resonant frequencies
            ir[i] = decay * resonance * 0.3;
        }

        // Normalize IR
        var sum: f64 = 0.0;
        for (ir) |sample| {
            sum += @abs(sample);
        }
        if (sum > 0.0) {
            for (ir) |*sample| {
                sample.* /= sum;
            }
        }

        // Clear buffer
        @memset(buffer, 0.0);

        return CabinetSimulator{
            .allocator = allocator,
            .ir = ir,
            .ir_length = ir_length,
            .buffer = buffer,
            .buffer_pos = 0,
        };
    }

    pub fn deinit(self: *CabinetSimulator) void {
        self.allocator.free(self.ir);
        self.allocator.free(self.buffer);
    }

    pub fn reset(self: *CabinetSimulator) void {
        @memset(self.buffer, 0.0);
        self.buffer_pos = 0;
    }

    /// Load impulse response from buffer
    pub fn loadIR(self: *CabinetSimulator, ir_data: []const f64) void {
        const copy_len = @min(ir_data.len, self.ir_length);
        @memcpy(self.ir[0..copy_len], ir_data[0..copy_len]);

        // Pad with zeros if IR is shorter
        if (copy_len < self.ir_length) {
            @memset(self.ir[copy_len..], 0.0);
        }
    }

    /// Process a single sample through the convolution
    pub fn processSample(self: *CabinetSimulator, input: f64) f64 {
        // Store input in circular buffer
        self.buffer[self.buffer_pos] = input;

        // Convolve with IR
        var output: f64 = 0.0;
        var buf_idx = self.buffer_pos;

        for (0..self.ir_length) |i| {
            output += self.buffer[buf_idx] * self.ir[i];

            // Circular buffer wraparound
            if (buf_idx == 0) {
                buf_idx = self.ir_length - 1;
            } else {
                buf_idx -= 1;
            }
        }

        // Advance buffer position
        self.buffer_pos = (self.buffer_pos + 1) % self.ir_length;

        return output;
    }

    /// Process a block of samples
    pub fn processBlock(self: *CabinetSimulator, input: []const f64, output: []f64) void {
        for (input, 0..) |sample, i| {
            output[i] = self.processSample(sample);
        }
    }
};

/// Simple default cabinet IR generator
pub fn generateDefaultCabinetIR(allocator: std.mem.Allocator, length: usize, sample_rate: f64) ![]f64 {
    const ir = try allocator.alloc(f64, length);

    // Generate a simple cabinet-like impulse response
    // This approximates a 4x12" closed-back guitar cabinet
    const duration = @as(f64, @floatFromInt(length)) / sample_rate;

    for (0..length) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        const t_norm = t / duration;

        // Main resonance around 80-100Hz (typical cab resonance)
        const resonance1 = @sin(2.0 * std.math.pi * 90.0 * t);

        // Secondary resonance around 200Hz
        const resonance2 = @sin(2.0 * std.math.pi * 200.0 * t) * 0.5;

        // High frequency content
        const resonance3 = @sin(2.0 * std.math.pi * 1000.0 * t) * 0.2;

        // Exponential decay envelope
        const envelope = @exp(-t_norm * 8.0);

        // Add some early reflections
        var early_reflections: f64 = 0.0;
        if (t > 0.001 and t < 0.010) { // 1-10ms
            early_reflections = @exp(-(t - 0.001) * 500.0) * 0.3;
        }

        ir[i] = (resonance1 + resonance2 + resonance3 + early_reflections) * envelope;
    }

    // Normalize
    var max_val: f64 = 0.0;
    for (ir) |sample| {
        max_val = @max(max_val, @abs(sample));
    }
    if (max_val > 0.0) {
        for (ir) |*sample| {
            sample.* /= max_val;
            sample.* *= 0.5; // Scale down to avoid clipping
        }
    }

    return ir;
}
