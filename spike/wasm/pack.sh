#!/bin/sh
# Packs ruby.wasm's JavaScript build with Ruby's standard library and the Ruby a write-back needs into one module, with
# rbwasm, from the ruby_wasm gem, so nothing's read from disk or sent to Ruby: what the Obsidian plugin, and mobile,
# would need. The standard library is the WASI build's, the same Ruby version's, but only the files a write-back loads,
# which stdlib.rb lists in stdlib.txt, 0.5 MB of its 18 MB, and the JavaScript build is npm's.
#   gem install ruby_wasm
#   RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full RUBY_NPM=path/to/package/dist spike/wasm/pack.sh
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GEMS=$(cd "$ROOT" && mise exec -- ruby -e 'print Gem.dir')/gems
OUTPUT="$ROOT/spike/wasm/runtime/raindown.wasm"
STDLIB="$ROOT/spike/wasm/runtime/stdlib"

# Only the standard library files in stdlib.txt, in their folders.
rm -rf "$STDLIB"
while read -r file; do
  mkdir -p "$STDLIB/3.4.0/$(dirname "$file")"
  cp "$RUBY_WASI/usr/local/lib/ruby/3.4.0/$file" "$STDLIB/3.4.0/$file"
done < "$ROOT/spike/wasm/stdlib.txt"

rbwasm pack "$RUBY_NPM/ruby.wasm" -o "$OUTPUT" \
  --dir "$STDLIB::/usr/local/lib/ruby" \
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
