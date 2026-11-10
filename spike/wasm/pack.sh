#!/bin/sh
# Packs ruby.wasm's JavaScript build with Ruby's standard library and the Ruby a write-back needs into one module, with
# rbwasm, from the ruby_wasm gem, so nothing's read from disk or sent to Ruby: what the Obsidian plugin, and mobile,
# would need. The standard library is the WASI build's, the same Ruby version's, but only the files a write-back loads,
# which stdlib.rb lists in stdlib.txt, 0.5 MB of its 18 MB, and the JavaScript build is npm's. With WASMTIME, each of
# those Ruby files is compiled to bytecode, by the WASI build's Ruby, with compile.rb, and packed at /bytecode too, in
# raindown-bytecode.wasm, for bytecode.rb to load rather than parsing and compiling them.
#   gem install ruby_wasm
#   RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full RUBY_NPM=path/to/package/dist [WASMTIME=path/to/wasmtime] \
#     spike/wasm/pack.sh
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GEMS=$(cd "$ROOT" && mise exec -- ruby -e 'print Gem.dir')/gems
RUNTIME="$ROOT/spike/wasm/runtime"
STDLIB="$RUNTIME/stdlib/usr/local/lib/ruby"
BYTECODE="$RUNTIME/bytecode"

# Only the standard library files in stdlib.txt, in their folders, under usr/ as in Ruby's.
rm -rf "$RUNTIME/stdlib"
while read -r file; do
  mkdir -p "$STDLIB/3.4.0/$(dirname "$file")"
  cp "$RUBY_WASI/usr/local/lib/ruby/3.4.0/$file" "$STDLIB/3.4.0/$file"
done < "$ROOT/spike/wasm/stdlib.txt"

# Each folder packed, as host::guest, and its path inside Ruby.
FOLDERS="$STDLIB::/usr/local/lib/ruby
$ROOT/spike/wasm/stubs::/stubs
$ROOT/lib::/raindown/lib
$HOME/dev/antlers/lib::/antlers/lib
$HOME/dev/lowkey/lib::/lowkey/lib
$HOME/dev/plugs/lib::/plugs/lib
$GEMS/csv-3.3.7/lib::/csv/lib
$GEMS/unicode-display_width-3.3.0/lib::/display_width/lib
$GEMS/unicode-display_width-3.3.0/data::/display_width/data
$GEMS/unicode-emoji-4.3.0/lib::/emoji/lib
$GEMS/unicode-emoji-4.3.0/data::/emoji/data"
DIRS=""; GUESTS=""
for folder in $FOLDERS; do
  DIRS="$DIRS --dir $folder"; GUESTS="$GUESTS ${folder#*::}"
done
OUTPUT="$RUNTIME/raindown.wasm"

if [ -n "$WASMTIME" ]; then
  rm -rf "$BYTECODE" && mkdir -p "$BYTECODE"
  # Ruby looks at the folders a file's in, finding its real path, compiling it as loading it, and wasmtime only has the
  # folders packed ones are in, like /raindown for /raindown/lib, if they're mounted, so empty ones are, and /usr.
  PARENTS="--dir $RUNTIME/stdlib/usr::/usr"
  for guest in $GUESTS; do
    parent=$(dirname "$guest")
    case "$parent" in /|/usr*) continue ;; esac
    mkdir -p "$RUNTIME/parents$parent"
    case "$PARENTS" in *"::$parent "*|*"::$parent") ;; *) PARENTS="$PARENTS --dir $RUNTIME/parents$parent::$parent" ;; esac
  done
  # shellcheck disable=SC2086
  "$WASMTIME" run $PARENTS $DIRS --dir "$ROOT/spike/wasm::/spike" --dir "$BYTECODE::/bytecode" \
    "$RUBY_WASI/usr/local/bin/ruby" \
    --disable-gems /spike/compile.rb /bytecode $GUESTS
  DIRS="$DIRS --dir $BYTECODE::/bytecode"
  OUTPUT="$RUNTIME/raindown-bytecode.wasm"
fi

# shellcheck disable=SC2086
rbwasm pack "$RUBY_NPM/ruby.wasm" -o "$OUTPUT" $DIRS
ls -l "$OUTPUT" | awk '{ printf "Packed %s: %.1f MB\n", $NF, $5 / 1e6 }'
