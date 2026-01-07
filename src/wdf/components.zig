const std = @import("std");

/// Wave Digital Filter component interface
pub const WDFComponent = struct {
    vtable: *const VTable,
    port_resistance: f64,

    pub const VTable = struct {
        // Wave up (incident wave) - returns reflected wave
        waveUp: *const fn (self: *WDFComponent, wave_down: f64) f64,
        // Set incident wave (from parent adaptor)
        setIncidentWave: *const fn (self: *WDFComponent, wave: f64) void,
        // Get reflected wave
        getReflectedWave: *const fn (self: *WDFComponent) f64,
        // Reset state
        reset: *const fn (self: *WDFComponent) void,
    };

    pub fn waveUp(self: *WDFComponent, wave_down: f64) f64 {
        return self.vtable.waveUp(self, wave_down);
    }

    pub fn setIncidentWave(self: *WDFComponent, wave: f64) void {
        self.vtable.setIncidentWave(self, wave);
    }

    pub fn getReflectedWave(self: *WDFComponent) f64 {
        return self.vtable.getReflectedWave(self);
    }

    pub fn reset(self: *WDFComponent) void {
        self.vtable.reset(self);
    }
};

/// Resistor - linear, memoryless component
pub const Resistor = struct {
    base: WDFComponent,
    resistance: f64,
    incident_wave: f64,
    reflected_wave: f64,

    const vtable = WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(resistance: f64) Resistor {
        return .{
            .base = .{
                .vtable = &vtable,
                .port_resistance = resistance,
            },
            .resistance = resistance,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
        };
    }

    fn waveUpImpl(base: *WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(Resistor, "base", base);
        self.incident_wave = wave_down;
        self.reflected_wave = 0.0; // Resistor is perfectly matched (Gamma = 0)
        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(Resistor, "base", base);
        self.incident_wave = wave;
        self.reflected_wave = 0.0;
    }

    fn getReflectedWaveImpl(base: *WDFComponent) f64 {
        const self = @fieldParentPtr(Resistor, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *WDFComponent) void {
        const self = @fieldParentPtr(Resistor, "base", base);
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
    }

    pub fn voltage(self: *const Resistor) f64 {
        return (self.incident_wave + self.reflected_wave) / 2.0;
    }

    pub fn current(self: *const Resistor) f64 {
        return (self.incident_wave - self.reflected_wave) / (2.0 * self.resistance);
    }
};

/// Capacitor - stateful component (stores charge)
pub const Capacitor = struct {
    base: WDFComponent,
    capacitance: f64,
    sample_rate: f64,
    state: f64, // Previous reflected wave
    incident_wave: f64,
    reflected_wave: f64,

    const vtable = WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(capacitance: f64, sample_rate: f64) Capacitor {
        const resistance = 1.0 / (2.0 * capacitance * sample_rate);
        return .{
            .base = .{
                .vtable = &vtable,
                .port_resistance = resistance,
            },
            .capacitance = capacitance,
            .sample_rate = sample_rate,
            .state = 0.0,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
        };
    }

    fn waveUpImpl(base: *WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(Capacitor, "base", base);
        self.incident_wave = wave_down;
        self.reflected_wave = self.state;
        self.state = wave_down; // Store for next sample
        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(Capacitor, "base", base);
        self.incident_wave = wave;
        self.reflected_wave = self.state;
    }

    fn getReflectedWaveImpl(base: *WDFComponent) f64 {
        const self = @fieldParentPtr(Capacitor, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *WDFComponent) void {
        const self = @fieldParentPtr(Capacitor, "base", base);
        self.state = 0.0;
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
    }

    pub fn voltage(self: *const Capacitor) f64 {
        return (self.incident_wave + self.reflected_wave) / 2.0;
    }

    pub fn current(self: *const Capacitor) f64 {
        return (self.incident_wave - self.reflected_wave) / (2.0 * self.base.port_resistance);
    }
};

/// Voltage Source - ideal source for input signal
pub const VoltageSource = struct {
    base: WDFComponent,
    voltage_value: f64,
    source_resistance: f64,
    incident_wave: f64,
    reflected_wave: f64,

    const vtable = WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(source_resistance: f64) VoltageSource {
        return .{
            .base = .{
                .vtable = &vtable,
                .port_resistance = source_resistance,
            },
            .voltage_value = 0.0,
            .source_resistance = source_resistance,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
        };
    }

    pub fn setVoltage(self: *VoltageSource, voltage: f64) void {
        self.voltage_value = voltage;
    }

    fn waveUpImpl(base: *WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(VoltageSource, "base", base);
        self.incident_wave = wave_down;
        self.reflected_wave = 2.0 * self.voltage_value - wave_down;
        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(VoltageSource, "base", base);
        self.incident_wave = wave;
        self.reflected_wave = 2.0 * self.voltage_value - wave;
    }

    fn getReflectedWaveImpl(base: *WDFComponent) f64 {
        const self = @fieldParentPtr(VoltageSource, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *WDFComponent) void {
        const self = @fieldParentPtr(VoltageSource, "base", base);
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
    }

    pub fn voltage(self: *const VoltageSource) f64 {
        return (self.incident_wave + self.reflected_wave) / 2.0;
    }

    pub fn current(self: *const VoltageSource) f64 {
        return (self.incident_wave - self.reflected_wave) / (2.0 * self.source_resistance);
    }
};

/// Series Adaptor - connects two components in series
pub const SeriesAdaptor = struct {
    base: WDFComponent,
    left: *WDFComponent,
    right: *WDFComponent,
    incident_wave: f64,
    reflected_wave: f64,

    const vtable = WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(left: *WDFComponent, right: *WDFComponent) SeriesAdaptor {
        const port_r = left.port_resistance + right.port_resistance;
        return .{
            .base = .{
                .vtable = &vtable,
                .port_resistance = port_r,
            },
            .left = left,
            .right = right,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
        };
    }

    fn waveUpImpl(base: *WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(SeriesAdaptor, "base", base);
        self.incident_wave = wave_down;

        const r_left = self.left.port_resistance;
        const r_right = self.right.port_resistance;
        const r_total = r_left + r_right;

        // Scatter waves to children
        const b_left = self.left.waveUp(-self.right.getReflectedWave() + (r_left / r_total) * (wave_down + self.left.getReflectedWave() + self.right.getReflectedWave()));
        const b_right = self.right.waveUp(-self.left.getReflectedWave() + (r_right / r_total) * (wave_down + self.left.getReflectedWave() + self.right.getReflectedWave()));

        self.reflected_wave = -(b_left + b_right);
        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(SeriesAdaptor, "base", base);
        self.incident_wave = wave;
    }

    fn getReflectedWaveImpl(base: *WDFComponent) f64 {
        const self = @fieldParentPtr(SeriesAdaptor, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *WDFComponent) void {
        const self = @fieldParentPtr(SeriesAdaptor, "base", base);
        self.left.reset();
        self.right.reset();
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
    }
};

/// Parallel Adaptor - connects two components in parallel
pub const ParallelAdaptor = struct {
    base: WDFComponent,
    left: *WDFComponent,
    right: *WDFComponent,
    incident_wave: f64,
    reflected_wave: f64,

    const vtable = WDFComponent.VTable{
        .waveUp = waveUpImpl,
        .setIncidentWave = setIncidentWaveImpl,
        .getReflectedWave = getReflectedWaveImpl,
        .reset = resetImpl,
    };

    pub fn init(left: *WDFComponent, right: *WDFComponent) ParallelAdaptor {
        const g_left = 1.0 / left.port_resistance;
        const g_right = 1.0 / right.port_resistance;
        const port_r = 1.0 / (g_left + g_right);
        return .{
            .base = .{
                .vtable = &vtable,
                .port_resistance = port_r,
            },
            .left = left,
            .right = right,
            .incident_wave = 0.0,
            .reflected_wave = 0.0,
        };
    }

    fn waveUpImpl(base: *WDFComponent, wave_down: f64) f64 {
        const self = @fieldParentPtr(ParallelAdaptor, "base", base);
        self.incident_wave = wave_down;

        const g_left = 1.0 / self.left.port_resistance;
        const g_right = 1.0 / self.right.port_resistance;
        const g_total = g_left + g_right;

        // Scatter waves to children
        const gamma_left = g_left / g_total;
        const gamma_right = g_right / g_total;

        const b_left = self.left.waveUp(gamma_left * wave_down + (1.0 - gamma_left) * self.left.getReflectedWave() - gamma_left * self.right.getReflectedWave());
        const b_right = self.right.waveUp(gamma_right * wave_down + (1.0 - gamma_right) * self.right.getReflectedWave() - gamma_right * self.left.getReflectedWave());

        self.reflected_wave = -(b_left + b_right - wave_down);
        return self.reflected_wave;
    }

    fn setIncidentWaveImpl(base: *WDFComponent, wave: f64) void {
        const self = @fieldParentPtr(ParallelAdaptor, "base", base);
        self.incident_wave = wave;
    }

    fn getReflectedWaveImpl(base: *WDFComponent) f64 {
        const self = @fieldParentPtr(ParallelAdaptor, "base", base);
        return self.reflected_wave;
    }

    fn resetImpl(base: *WDFComponent) void {
        const self = @fieldParentPtr(ParallelAdaptor, "base", base);
        self.left.reset();
        self.right.reset();
        self.incident_wave = 0.0;
        self.reflected_wave = 0.0;
    }
};
