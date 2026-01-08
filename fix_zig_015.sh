#!/bin/bash

# Fix Zig 0.15 compatibility issues

cd /Users/guillaume.bailleul/perso/volt-plugin

echo "Fixing @fieldParentPtr API (Zig 0.15 uses 2 arguments instead of 3)..."
# In Zig 0.15, @fieldParentPtr changed from @fieldParentPtr(Type, "field", ptr) to @fieldParentPtr("field", ptr)
find src -name "*.zig" -type f -exec sed -i '' 's/@fieldParentPtr(\([^,]*\), "\([^"]*\)", \([^)]*\))/@fieldParentPtr(\1, "\2", \3)/g' {} +

echo "Fixing callconv(.C) to callconv(.c)..."
find src -name "*.zig" -type f -exec sed -i '' 's/callconv(\.C)/callconv(.c)/g' {} +

echo "Done! Now try: zig build-lib -dynamic -lc -I libs/clap/include -OReleaseFast src/root.zig -femit-bin=zig-out/lib/libvolt.dylib"
