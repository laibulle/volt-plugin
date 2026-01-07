# Volt Tube Amp - WDF CLAP Plugin

A component-level Wave Digital Filter tube amplifier plugin built with Zig. Features a physically-modeled 12AX7 triode preamp stage, tonestack EQ, and cabinet simulation.

## Features

- **WDF Tube Modeling**: 12AX7 triode using Dempwolf equations with 256×256 lookup table
- **Complete Signal Chain**: Preamp → Tonestack (Bass/Treble) → Cabinet IR → Master
- **High Performance**: Optimized for <10% CPU usage at 48kHz
- **4 Parameters**: Gain, Bass, Treble, Master
- **CLAP Plugin**: Compatible with Bitwig, Reaper, and other CLAP hosts

## Build Requirements

- Zig (latest stable)
- macOS or Linux

## Building

```bash
# Build the plugin
zig build

# Run tests
zig build test

# Run benchmark
zig build bench -- run

# Install to system plugin directory
zig build install-plugin
```

## Installation

### macOS
```bash
zig build install-plugin
# Plugin will be installed to: ~/Library/Audio/Plug-Ins/CLAP/volt.clap
```

### Linux
```bash
zig build install-plugin
# Plugin will be installed to: ~/.clap/volt.clap
```

## Architecture

```
src/
├── wdf/              # Wave Digital Filter components
│   ├── components.zig    # R, C, L, adaptors, voltage source
│   └── tube.zig          # 12AX7 triode model (Dempwolf)
├── circuits/         # Circuit assemblies
│   └── preamp.zig        # Tube preamp + complete amplifier
├── audio/           # Audio processing
│   ├── tonestack.zig     # Biquad EQ filters
│   └── cabinet.zig       # IR convolution
└── plugin/          # CLAP wrapper
    ├── parameters.zig    # Parameter definitions
    ├── volt_plugin.zig   # Plugin state + processing
    └── plugin.zig        # CLAP entry points
```

## Technical Details

### WDF Components

- **Resistor, Capacitor**: Linear components with wave scattering
- **Series/Parallel Adaptors**: Connect components in WDF topology
- **Voltage Source**: Input signal injection

### 12AX7 Tube Model

Based on Dempwolf et al. "A Physically-Motivated Triode Model for Circuit Simulations" (DAFx-11):

```
Ip = (g × E1 × log(1 + exp(kp × E1))^ex + kvb) / kg
where E1 = (Vpk / μ) + Vgk
```

Parameters for 12AX7:
- μ = 103.2 (amplification factor)
- g = 2.242×10⁻³ (transconductance)
- ex = 1.4 (knee parameter)

Lookup table: 256×256 (Vgk: -10V to +5V, Vpk: 0V to 500V)

### Tonestack

- **Bass**: Low-shelf filter at 200Hz (±12dB)
- **Treble**: High-shelf filter at 2kHz (±12dB)
- **Implementation**: Biquad IIR filters

### Cabinet Simulation

- **Algorithm**: Time-domain convolution
- **IR Length**: 2048 samples (43ms @ 48kHz)
- **Default IR**: Synthetic 4×12" closed-back cabinet

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| Gain      | 0-1   | 0.5     | Preamp input gain (1-20x) |
| Bass      | 0-1   | 0.5     | Low-shelf EQ (-12dB to +12dB) |
| Treble    | 0-1   | 0.5     | High-shelf EQ (-12dB to +12dB) |
| Master    | 0-1   | 0.5     | Output volume |

## Performance

Target: <10% CPU on modern hardware @ 48kHz/128 samples

Run benchmark:
```bash
zig build bench
./zig-out/bin/bench
```

Expected results:
- ~50-200 cycles/sample
- <5% single-core CPU usage @ 48kHz
- <10% single-core CPU usage @ 96kHz

## References

### WDF Theory
- Fettweis, A. "Wave digital filters: Theory and practice" (1986)
- Werner, K. "Virtual Analog Modeling of Audio Circuitry Using Wave Digital Filters" (PhD, 2016)

### Tube Modeling
- Dempwolf, K. et al. "A Physically-Motivated Triode Model" (DAFx-11)
- Pakarinen, J. "Computational Modeling of Analog Circuits" (PhD, 2011)

### Optimization
- Välimäki, V. et al. "Efficient Antialiasing Oscillators and Filters" (2012)
- Esqueda, F. "Virtual Analog Modeling of Audio Effects" (PhD, 2019)

## Testing

```bash
# Unit tests
zig build test

# Manual testing
zig build
# Load volt.clap in your DAW
# Test with guitar input or sine wave generator
```

## License

MIT

## Contributing

This is a prototype/demonstration project. For production use, consider:

- Full Newton-Raphson solver for tube nonlinearity
- FFT convolution for cabinet (longer IRs)
- Additional tube stages (power amp, phase inverter)
- Oversampling for antialiasing
- Proper CLAP state save/restore
- GUI with parameter controls

## Credits

- Wave Digital Filter theory: Alfred Fettweis, Kurt Werner
- Tube modeling: Kristjan Dempwolf, Jyri Pakarinen
- CLAP plugin format: Free Audio
