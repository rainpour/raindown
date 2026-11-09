#!/bin/sh
# Writes config.json for the spike plugin: where Ruby compiled to WebAssembly is, and each folder Ruby needs, from its
# path inside WebAssembly to its path on this computer, as run.sh maps them.
#   RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full spike/wasm/obsidian/setup.sh
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
GEMS=$(cd "$ROOT" && mise exec -- ruby -e 'print Gem.dir')/gems
WORK="$ROOT/spike/wasm/obsidian/work"
mkdir -p "$WORK"
cat > "$ROOT/spike/wasm/obsidian/config.json" <<JSON
{
  "ruby": "$RUBY_WASI/usr/local/bin/ruby",
  "dirs": {
    "/usr": "$RUBY_WASI/usr",
    "/stubs": "$ROOT/spike/wasm/stubs",
    "/spike": "$ROOT/spike/wasm",
    "/work": "$WORK",
    "/raindown": "$ROOT",
    "/antlers": "$HOME/dev/antlers",
    "/lowkey": "$HOME/dev/lowkey",
    "/plugs": "$HOME/dev/plugs",
    "/csv": "$GEMS/csv-3.3.7",
    "/display_width": "$GEMS/unicode-display_width-3.3.0",
    "/emoji": "$GEMS/unicode-emoji-4.3.0"
  },
  "includes": ["/stubs", "/raindown/lib", "/antlers/lib", "/lowkey/lib", "/plugs/lib", "/csv/lib", "/display_width/lib",
    "/emoji/lib"]
}
JSON
echo "Wrote $ROOT/spike/wasm/obsidian/config.json"
