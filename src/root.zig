// Root module file for the Volt plugin
// This file is used as the entry point for building the plugin

pub const wdf = struct {
    pub const components = @import("wdf/components.zig");
    pub const tube = @import("wdf/tube.zig");
};

pub const circuits = struct {
    pub const preamp = @import("circuits/preamp.zig");
};

pub const audio = struct {
    pub const tonestack = @import("audio/tonestack.zig");
    pub const cabinet = @import("audio/cabinet.zig");
};

pub const plugin = struct {
    pub const parameters = @import("plugin/parameters.zig");
    pub const volt_plugin = @import("plugin/volt_plugin.zig");
    pub const main = @import("plugin/plugin.zig");
};

// Exports for CLAP plugin
comptime {
    _ = @import("plugin/plugin.zig");
}
