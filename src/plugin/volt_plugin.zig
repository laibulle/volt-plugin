const std = @import("std");
const preamp = @import("../circuits/preamp.zig");
const params = @import("parameters.zig");

// Import CLAP headers (C)
const c = @cImport({
    @cInclude("clap/clap.h");
});

/// Plugin instance state
pub const VoltPlugin = struct {
    allocator: std.mem.Allocator,
    host: *const c.clap_host_t,
    amplifier: preamp.TubeAmplifier,
    sample_rate: f64,

    // Parameter values
    param_gain: f64,
    param_bass: f64,
    param_treble: f64,
    param_master: f64,

    pub fn init(allocator: std.mem.Allocator, host: *const c.clap_host_t) !*VoltPlugin {
        const plugin = try allocator.create(VoltPlugin);

        plugin.* = VoltPlugin{
            .allocator = allocator,
            .host = host,
            .amplifier = undefined, // Will be initialized in activate()
            .sample_rate = 48000.0, // Default, will be set in activate()
            .param_gain = 0.5,
            .param_bass = 0.5,
            .param_treble = 0.5,
            .param_master = 0.5,
        };

        return plugin;
    }

    pub fn deinit(self: *VoltPlugin) void {
        self.amplifier.deinit();
        self.allocator.destroy(self);
    }

    pub fn activate(self: *VoltPlugin, sample_rate: f64) !void {
        self.sample_rate = sample_rate;
        self.amplifier = try preamp.TubeAmplifier.init(self.allocator, sample_rate);

        // Set initial parameter values
        self.amplifier.setGain(self.param_gain);
        self.amplifier.setBass(self.param_bass);
        self.amplifier.setTreble(self.param_treble);
        self.amplifier.setMaster(self.param_master);
    }

    pub fn deactivate(self: *VoltPlugin) void {
        self.amplifier.deinit();
    }

    pub fn setParameter(self: *VoltPlugin, param_id: u32, value: f64) void {
        switch (param_id) {
            @intFromEnum(params.ParamId.gain) => {
                self.param_gain = value;
                self.amplifier.setGain(value);
            },
            @intFromEnum(params.ParamId.bass) => {
                self.param_bass = value;
                self.amplifier.setBass(value);
            },
            @intFromEnum(params.ParamId.treble) => {
                self.param_treble = value;
                self.amplifier.setTreble(value);
            },
            @intFromEnum(params.ParamId.master) => {
                self.param_master = value;
                self.amplifier.setMaster(value);
            },
            else => {},
        }
    }

    pub fn getParameter(self: *const VoltPlugin, param_id: u32) f64 {
        return switch (param_id) {
            @intFromEnum(params.ParamId.gain) => self.param_gain,
            @intFromEnum(params.ParamId.bass) => self.param_bass,
            @intFromEnum(params.ParamId.treble) => self.param_treble,
            @intFromEnum(params.ParamId.master) => self.param_master,
            else => 0.0,
        };
    }

    pub fn process(self: *VoltPlugin, process_data: *const c.clap_process_t) c.clap_process_status {
        // Handle parameter changes from events
        if (process_data.in_events) |in_events| {
            const event_count = in_events.*.size.?(in_events);

            var i: u32 = 0;
            while (i < event_count) : (i += 1) {
                const event_header = in_events.*.get.?(in_events, i);

                if (event_header.*.space_id == c.CLAP_CORE_EVENT_SPACE_ID) {
                    if (event_header.*.type == c.CLAP_EVENT_PARAM_VALUE) {
                        const param_event: *const c.clap_event_param_value_t = @ptrCast(@alignCast(event_header));
                        self.setParameter(param_event.param_id, param_event.value);
                    }
                }
            }
        }

        // Get audio buffers
        const frame_count = process_data.frames_count;

        // Process audio (mono input, stereo output)
        if (process_data.audio_inputs_count > 0 and process_data.audio_outputs_count > 0) {
            const input = process_data.audio_inputs[0];
            const output = process_data.audio_outputs[0];

            if (input.channel_count > 0 and output.channel_count >= 2) {
                const in_buffer = input.data32[0]; // First channel
                const out_left = output.data32[0];
                const out_right = output.data32[1];

                var frame: u32 = 0;
                while (frame < frame_count) : (frame += 1) {
                    const in_sample = in_buffer[frame];
                    const out_sample = self.amplifier.processSample(in_sample);

                    out_left[frame] = @floatCast(out_sample);
                    out_right[frame] = @floatCast(out_sample); // Mono to stereo
                }
            }
        }

        return c.CLAP_PROCESS_CONTINUE;
    }
};
