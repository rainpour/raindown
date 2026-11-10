#!/bin/sh
# Runs a table: write-back in Ruby compiled to WebAssembly, with wasmtime, then natively with the same load path, to
# compare. Only the Ruby a write-back loads is mapped in, with Commonmarker stubbed, as it's native code.
#   WASMTIME=path/to/wasmtime RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full spike/wasm/run.sh
# wasmtime is from github.com/bytecodealliance/wasmtime/releases, and RUBY_WASI is the extracted
# ruby-3.4-wasm32-unknown-wasip1-full.tar.gz from github.com/ruby/ruby.wasm/releases: Ruby as a WASI command, in
# usr/local/bin/ruby, with its standard library beside it, mapped in at /usr. npm's builds are for JavaScript.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GEMS=$(cd "$ROOT" && mise exec -- ruby -e 'print Gem.dir')/gems
WORK=$(mktemp -d)

# Each gem's folder as host::guest, for wasmtime's --dir, with its lib folder for Ruby's -I, as gems can read files
# beside their code, like unicode-display_width's data. The stubs are a lib folder of their own.
GEM_DIRS="$ROOT::/raindown $HOME/dev/antlers::/antlers $HOME/dev/lowkey::/lowkey $HOME/dev/plugs::/plugs
$GEMS/csv-3.3.7::/csv $GEMS/unicode-display_width-3.3.0::/display_width $GEMS/unicode-emoji-4.3.0::/emoji"
MAPS="--dir $ROOT/spike/wasm/stubs::/stubs"; INCLUDES="-I/stubs"; NATIVE="-I$ROOT/spike/wasm/stubs"
for dir in $GEM_DIRS; do
  MAPS="$MAPS --dir $dir"; INCLUDES="$INCLUDES -I${dir#*::}/lib"; NATIVE="$NATIVE -I${dir%%::*}/lib"
done

RUBY_WASM="$RUBY_WASI/usr/local/bin/ruby"
ls -l "$RUBY_WASM" | awk '{ printf "ruby.wasm: %.1f MB\n", $5 / 1e6 }'
echo "== WebAssembly"
# shellcheck disable=SC2086
time "$WASMTIME" run $MAPS --dir "$RUBY_WASI/usr::/usr" --dir "$ROOT/spike/wasm::/spike" --dir "$WORK::/work" "$RUBY_WASM" \
  --disable-gems -rrbconfig $INCLUDES /spike/writeback.rb /work

rm -f "$WORK"/*
echo "== Native"
# shellcheck disable=SC2086
time mise exec -- ruby --disable-gems -rrbconfig $NATIVE "$ROOT/spike/wasm/writeback.rb" "$WORK"
