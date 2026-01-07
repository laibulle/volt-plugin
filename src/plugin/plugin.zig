const std = @import("std");
const volt_plugin = @import("volt_plugin.zig");
const params = @import("parameters.zig");

// Import CLAP headers (C)
const c = @cImport({
    @cInclude("clap/clap.h");
});

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Plugin descriptor
const plugin_id = "com.volt.tube-amp";
const plugin_name = "Volt Tube Amp";
const plugin_vendor = "Volt Audio";
const plugin_version = "1.0.0";
const plugin_description = "Wave Digital Filter tube amplifier with 12AX7 preamp";

// Features
const features = [_][*c]const u8{
    c.CLAP_PLUGIN_FEATURE_AUDIO_EFFECT,
    c.CLAP_PLUGIN_FEATURE_DISTORTION,
    c.CLAP_PLUGIN_FEATURE_GUITAR,
    null,
};

// Plugin descriptor
export const clap_plugin_descriptor = c.clap_plugin_descriptor_t{
    .clap_version = c.CLAP_VERSION,
    .id = plugin_id,
    .name = plugin_name,
    .vendor = plugin_vendor,
    .url = "https://github.com/volt-audio/volt-plugin",
    .manual_url = "",
    .support_url = "",
    .version = plugin_version,
    .description = plugin_description,
    .features = &features,
};

// CLAP plugin callbacks
fn plugin_init(plugin: *const c.clap_plugin_t) callconv(.C) bool {
    _ = plugin;
    return true;
}

fn plugin_destroy(plugin: *const c.clap_plugin_t) callconv(.C) void {
    const volt = getPluginData(plugin);
    volt.deinit();
}

fn plugin_activate(plugin: *const c.clap_plugin_t, sample_rate: f64, min_frames: u32, max_frames: u32) callconv(.C) bool {
    _ = min_frames;
    _ = max_frames;

    const volt = getPluginData(plugin);
    volt.activate(sample_rate) catch return false;
    return true;
}

fn plugin_deactivate(plugin: *const c.clap_plugin_t) callconv(.C) void {
    const volt = getPluginData(plugin);
    volt.deactivate();
}

fn plugin_start_processing(plugin: *const c.clap_plugin_t) callconv(.C) bool {
    _ = plugin;
    return true;
}

fn plugin_stop_processing(plugin: *const c.clap_plugin_t) callconv(.C) void {
    _ = plugin;
}

fn plugin_reset(plugin: *const c.clap_plugin_t) callconv(.C) void {
    const volt = getPluginData(plugin);
    volt.amplifier.reset();
}

fn plugin_process(plugin: *const c.clap_plugin_t, process: *const c.clap_process_t) callconv(.C) c.clap_process_status {
    const volt = getPluginData(plugin);
    return volt.process(process);
}

fn plugin_get_extension(plugin: *const c.clap_plugin_t, id: [*c]const u8) callconv(.C) ?*const anyopaque {
    _ = plugin;

    if (std.mem.orderZ(u8, id, c.CLAP_EXT_PARAMS) == .eq) {
        return &params_extension;
    }

    return null;
}

fn plugin_on_main_thread(plugin: *const c.clap_plugin_t) callconv(.C) void {
    _ = plugin;
}

// Helper to get plugin data
fn getPluginData(plugin: *const c.clap_plugin_t) *volt_plugin.VoltPlugin {
    return @ptrCast(@alignCast(plugin.plugin_data));
}

// Plugin vtable
const plugin_class = c.clap_plugin_t{
    .desc = &clap_plugin_descriptor,
    .plugin_data = null, // Set during instantiation
    .init = plugin_init,
    .destroy = plugin_destroy,
    .activate = plugin_activate,
    .deactivate = plugin_deactivate,
    .start_processing = plugin_start_processing,
    .stop_processing = plugin_stop_processing,
    .reset = plugin_reset,
    .process = plugin_process,
    .get_extension = plugin_get_extension,
    .on_main_thread = plugin_on_main_thread,
};

// Parameters extension
fn params_count(plugin: *const c.clap_plugin_t) callconv(.C) u32 {
    _ = plugin;
    return params.getParameterCount();
}

fn params_get_info(plugin: *const c.clap_plugin_t, param_index: u32, param_info: *c.clap_param_info_t) callconv(.C) bool {
    _ = plugin;

    const param = params.getParameter(param_index) orelse return false;

    param_info.id = param.id;
    param_info.flags = c.CLAP_PARAM_IS_AUTOMATABLE | c.CLAP_PARAM_IS_MODULATABLE;
    param_info.cookie = null;

    // Copy name
    const name_len = @min(param.name.len, c.CLAP_NAME_SIZE - 1);
    @memcpy(param_info.name[0..name_len], param.name[0..name_len]);
    param_info.name[name_len] = 0;

    // Copy module
    const module_len = @min(param.module.len, c.CLAP_NAME_SIZE - 1);
    @memcpy(param_info.module[0..module_len], param.module[0..module_len]);
    param_info.module[module_len] = 0;

    param_info.min_value = param.min_value;
    param_info.max_value = param.max_value;
    param_info.default_value = param.default_value;

    return true;
}

fn params_get_value(plugin: *const c.clap_plugin_t, param_id: c.clap_id, value: *f64) callconv(.C) bool {
    const volt = getPluginData(plugin);
    value.* = volt.getParameter(param_id);
    return true;
}

fn params_value_to_text(plugin: *const c.clap_plugin_t, param_id: c.clap_id, value: f64, display: [*c]u8, size: u32) callconv(.C) bool {
    _ = plugin;
    _ = param_id;

    // Format as percentage
    const text = std.fmt.bufPrintZ(display[0..size], "{d:.1}%", .{value * 100.0}) catch return false;
    _ = text;
    return true;
}

fn params_text_to_value(plugin: *const c.clap_plugin_t, param_id: c.clap_id, display: [*c]const u8, value: *f64) callconv(.C) bool {
    _ = plugin;
    _ = param_id;
    _ = display;
    _ = value;
    return false; // Not implemented
}

fn params_flush(plugin: *const c.clap_plugin_t, in: *const c.clap_input_events_t, out: *const c.clap_output_events_t) callconv(.C) void {
    _ = plugin;
    _ = in;
    _ = out;
}

const params_extension = c.clap_plugin_params_t{
    .count = params_count,
    .get_info = params_get_info,
    .get_value = params_get_value,
    .value_to_text = params_value_to_text,
    .text_to_value = params_text_to_value,
    .flush = params_flush,
};

// Plugin factory
fn factory_get_plugin_count(factory: *const c.clap_plugin_factory_t) callconv(.C) u32 {
    _ = factory;
    return 1;
}

fn factory_get_plugin_descriptor(factory: *const c.clap_plugin_factory_t, index: u32) callconv(.C) ?*const c.clap_plugin_descriptor_t {
    _ = factory;
    if (index != 0) return null;
    return &clap_plugin_descriptor;
}

fn factory_create_plugin(factory: *const c.clap_plugin_factory_t, host: *const c.clap_host_t, plugin_id_arg: [*c]const u8) callconv(.C) ?*const c.clap_plugin_t {
    _ = factory;

    if (std.mem.orderZ(u8, plugin_id_arg, plugin_id) != .eq) {
        return null;
    }

    const allocator = gpa.allocator();
    const volt = volt_plugin.VoltPlugin.init(allocator, host) catch return null;

    // Create plugin instance
    const plugin_instance = allocator.create(c.clap_plugin_t) catch return null;
    plugin_instance.* = plugin_class;
    plugin_instance.plugin_data = volt;

    return plugin_instance;
}

const plugin_factory = c.clap_plugin_factory_t{
    .get_plugin_count = factory_get_plugin_count,
    .get_plugin_descriptor = factory_get_plugin_descriptor,
    .create_plugin = factory_create_plugin,
};

// CLAP entry point
export fn clap_entry_init(plugin_path: [*c]const u8) callconv(.C) bool {
    _ = plugin_path;
    return true;
}

export fn clap_entry_deinit() callconv(.C) void {}

export fn clap_entry_get_factory(factory_id: [*c]const u8) callconv(.C) ?*const anyopaque {
    if (std.mem.orderZ(u8, factory_id, c.CLAP_PLUGIN_FACTORY_ID) == .eq) {
        return &plugin_factory;
    }
    return null;
}

// CLAP entry structure
export const clap_entry = c.clap_plugin_entry_t{
    .clap_version = c.CLAP_VERSION,
    .init = clap_entry_init,
    .deinit = clap_entry_deinit,
    .get_factory = clap_entry_get_factory,
};
