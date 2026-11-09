#!/bin/sh
# Packs ruby.wasm's JavaScript build with Ruby's standard library and the Ruby a write-back needs into one module, with
# rbwasm, from the ruby_wasm gem, so nothing's read from disk or sent to Ruby: what the Obsidian plugin, and mobile,
# would need. The standard library is the WASI build's, the same Ruby version's, without its own ruby program, and
# the JavaScript build is npm's.
#   gem install ruby_wasm
#   RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full RUBY_NPM=path/to/package/dist spike/wasm/pack.sh
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GEMS=$(cd "$ROOT" && mise exec -- ruby -e 'print Gem.dir')/gems
OUTPUT="$ROOT/spike/wasm/runtime/raindown.wasm"

rbwasm pack "$RUBY_NPM/ruby.wasm" -o "$OUTPUT" \
  --dir "$RUBY_WASI/usr/local/lib/ruby::/usr/local/lib/ruby" \
  --dir "$ROOT/spike/wasm/stubs::/stubs" \
  --dir "$ROOT/lib::/raindown/lib" \
  --dir "$HOME/dev/antlers/lib::/antlers/lib" \
  --dir "$HOME/dev/lowkey/lib::/lowkey/lib" \
  --dir "$HOME/dev/plugs/lib::/plugs/lib" \
  --dir "$GEMS/csv-3.3.7/lib::/csv/lib" \
  --dir "$GEMS/unicode-display_width-3.3.0/lib::/display_width/lib" \
  --dir "$GEMS/unicode-display_width-3.3.0/data::/display_width/data" \
  --dir "$GEMS/unicode-emoji-4.3.0/lib::/emoji/lib" \
  --dir "$GEMS/unicode-emoji-4.3.0/data::/emoji/data"

ls -l "$OUTPUT" | awk '{ printf "Packed %s: %.1f MB\n", $NF, $5 / 1e6 }'
