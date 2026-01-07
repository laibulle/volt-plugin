const std = @import("std");
const components = @import("components.zig");

/// 12AX7 Triode Model using Dempwolf equations (DAFx-11)
/// Implements pre-computed lookup table for performance
pub const Triode12AX7 = struct {
    base: components.WDFComponent,

    // Tube parameters for 12AX7 (from Dempwolf paper)
    g: f64 = 2.242e-3, // Transconductance parameter
    mu: f64 = 103.2, // Amplification factor
    ex: f64 = 1.4, // Knee parameter
    kg: f64 = 1060.0, // Grid parameter
    kp: f64 = 600.0, // Plate parameter
    kvb: f64 = 300.0, // Saturation voltage

    // Lookup table (256x256 for Vgk x Vpk -> Ip)
    lookup_table: [GRID_SIZE * PLATE_SIZE]f64,

    // Grid voltage range
    vgk_min: f64 = -10.0, // Minimum grid-cathode voltage
    vgk_max: f64 = 5.0, // Maximum grid-cathode voltage

    // Plate voltage range
    vpk_min: f64 = 0.0, // Minimum plate-cathode voltage
    vpk_max: f64 = 500.0, // Maximum plate-cathode voltage

    // Operating point
    cathode_resistance: f64,
    plate_resistance: f64,

    // State
    incident_wave: f64,
    reflected_wave: f64,
    last_vgk: f64,
    last_vpk: f64,

    const GRID_SIZE = 256;
    const PLATE_SIZE = 256;

    const vtable = components.WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(allocator: std.mem.Allocator, cathode_resistance: f64, plate_resistance: f64) !Triode12AX7 {
        _ = allocator;

        var triode = Triode12AX7{
            .base = .{
                .vtable = &vtable,
                .port_resistance = plate_resistance,
            },
            .lookup_table = undefined,
            .cathode_resistance = cathode_resistance,
            .plate_resistance = plate_resistance,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
            .last_vgk = 0.0,
            .last_vpk = 200.0, // Typical operating point
        };

        // Pre-compute lookup table
        triode.computeLookupTable();

        return triode;
    }

    /// Compute lookup table for Ip(Vgk, Vpk) using Dempwolf equations
    fn computeLookupTable(self: *Triode12AX7) void {
        const vgk_step = (self.vgk_max - self.vgk_min) / @as(f64, @floatFromInt(GRID_SIZE));
        const vpk_step = (self.vpk_max - self.vpk_min) / @as(f64, @floatFromInt(PLATE_SIZE));

        var gi: usize = 0;
        while (gi < GRID_SIZE) : (gi += 1) {
            const vgk = self.vgk_min + @as(f64, @floatFromInt(gi)) * vgk_step;

            var pi: usize = 0;
            while (pi < PLATE_SIZE) : (pi += 1) {
                const vpk = self.vpk_min + @as(f64, @floatFromInt(pi)) * vpk_step;

                const ip = self.computePlateCurrent(vgk, vpk);
                self.lookup_table[gi * PLATE_SIZE + pi] = ip;
            }
        }
    }

    /// Dempwolf triode model equation for plate current
    /// Ip = (g * E1 * pow(log(1 + exp(kp * E1)), ex) + kvb) / kg
    /// where E1 = (Vpk / mu) + Vgk
    fn computePlateCurrent(self: *const Triode12AX7, vgk: f64, vpk: f64) f64 {
        // Effective voltage
        const e1 = (vpk / self.mu) + vgk;

        // Cut-off region
        if (e1 < 0.0) return 0.0;

        // Compute plate current using Dempwolf equation
        const kp_e1 = self.kp * e1;

        // Prevent overflow in exp()
        const exp_arg = @min(kp_e1, 50.0);
        const log_arg = 1.0 + @exp(exp_arg);
        const pow_term = std.math.pow(f64, @log(log_arg), self.ex);

        const ip = (self.g * e1 * pow_term + self.kvb) / self.kg;

        // Clamp to reasonable range
        return @max(0.0, @min(ip, 0.020)); // Max 20mA
    }

    /// Lookup plate current from pre-computed table (with bilinear interpolation)
    fn lookupPlateCurrent(self: *const Triode12AX7, vgk: f64, vpk: f64) f64 {
        // Clamp to table range
        const vgk_clamped = @max(self.vgk_min, @min(vgk, self.vgk_max));
        const vpk_clamped = @max(self.vpk_min, @min(vpk, self.vpk_max));

        // Normalize to [0, 1]
        const vgk_norm = (vgk_clamped - self.vgk_min) / (self.vgk_max - self.vgk_min);
        const vpk_norm = (vpk_clamped - self.vpk_min) / (self.vpk_max - self.vpk_min);

        // Convert to table indices
        const gi_f = vgk_norm * @as(f64, @floatFromInt(GRID_SIZE - 1));
        const pi_f = vpk_norm * @as(f64, @floatFromInt(PLATE_SIZE - 1));

        const gi0: usize = @intFromFloat(@floor(gi_f));
        const pi0: usize = @intFromFloat(@floor(pi_f));
        const gi1: usize = @min(gi0 + 1, GRID_SIZE - 1);
        const pi1: usize = @min(pi0 + 1, PLATE_SIZE - 1);

        // Bilinear interpolation weights
        const gi_frac = gi_f - @as(f64, @floatFromInt(gi0));
        const pi_frac = pi_f - @as(f64, @floatFromInt(pi0));

        // Fetch corner values
        const ip00 = self.lookup_table[gi0 * PLATE_SIZE + pi0];
        const ip01 = self.lookup_table[gi0 * PLATE_SIZE + pi1];
        const ip10 = self.lookup_table[gi1 * PLATE_SIZE + pi0];
        const ip11 = self.lookup_table[gi1 * PLATE_SIZE + pi1];

        // Interpolate
        const ip0 = ip00 * (1.0 - pi_frac) + ip01 * pi_frac;
        const ip1 = ip10 * (1.0 - pi_frac) + ip11 * pi_frac;
        const ip = ip0 * (1.0 - gi_frac) + ip1 * gi_frac;

        return ip;
    }

    /// WDF interface implementation
    fn waveUpImpl(base: *components.WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(Triode12AX7, "base", base);
        self.incident_wave = wave_down;

        // Extract voltages from wave variables
        // This is a simplified version - in practice would need iterative solution
        // For now, use previous values as approximation
        const vgk = self.last_vgk;
        const vpk = self.last_vpk;

        // Get plate current from lookup table
        const ip = self.lookupPlateCurrent(vgk, vpk);

        // Compute reflected wave based on current
        // b = a - 2 * R * i
        self.reflected_wave = wave_down - 2.0 * self.plate_resistance * ip;

        // Update state for next iteration
        self.last_vgk = vgk;
        self.last_vpk = (wave_down + self.reflected_wave) / 2.0;

        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *components.WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(Triode12AX7, "base", base);
        self.incident_wave = wave;
    }

    fn getReflectedWaveImpl(base: *components.WDFComponent) f64 {
        const self = @fieldParentPtr(Triode12AX7, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *components.WDFComponent) void {
        const self = @fieldParentPtr(Triode12AX7, "base", base);
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
        self.last_vgk = 0.0;
        self.last_vpk = 200.0;
    }

    pub fn voltage(self: *const Triode12AX7) f64 {
        return (self.incident_wave + self.reflected_wave) / 2.0;
    }

    pub fn current(self: *const Triode12AX7) f64 {
        return (self.incident_wave - self.reflected_wave) / (2.0 * self.plate_resistance);
    }
};
