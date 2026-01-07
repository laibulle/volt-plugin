const std = @import("std");

/// CLAP plugin parameters
pub const ParamId = enum(u32) {
    gain = 0,
    bass = 1,
    treble = 2,
    master = 3,
};

pub const Parameter = struct {
    id: u32,
    name: []const u8,
    module: []const u8,
    min_value: f64,
    max_value: f64,
    default_value: f64,
};

pub const parameters = [_]Parameter{
    .{
        .id = @intFromEnum(ParamId.gain),
        .name = "Gain",
        .module = "Preamp",
        .min_value = 0.0,
        .max_value = 1.0,
        .default_value = 0.5,
    },
    .{
        .id = @intFromEnum(ParamId.bass),
        .name = "Bass",
        .module = "Tonestack",
        .min_value = 0.0,
        .max_value = 1.0,
        .default_value = 0.5,
    },
    .{
        .id = @intFromEnum(ParamId.treble),
        .name = "Treble",
        .module = "Tonestack",
        .min_value = 0.0,
        .max_value = 1.0,
        .default_value = 0.5,
    },
    .{
        .id = @intFromEnum(ParamId.master),
        .name = "Master",
        .module = "Output",
        .min_value = 0.0,
        .max_value = 1.0,
        .default_value = 0.5,
    },
};

pub fn getParameter(id: u32) ?Parameter {
    if (id >= parameters.len) return null;
    return parameters[id];
}

pub fn getParameterCount() u32 {
    return parameters.len;
}
