# Raindown in WebAssembly

Whether Raindown's write-back can run in Ruby compiled to WebAssembly, so the Obsidian plugin could run it without
Raindown installed. `run.sh` runs a `table:` write-back, with a `toc:`, in [ruby.wasm](https://github.com/ruby/ruby.wasm)'s
WASI build with [wasmtime](https://wasmtime.dev), then natively with the same load path, to compare:

```sh
WASMTIME=path/to/wasmtime RUBY_WASI=path/to/ruby-3.4-wasm32-unknown-wasip1-full spike/wasm/run.sh
```

Only the Ruby a write-back loads is mapped in: Raindown, antlers, lowkey, plugs, csv, unicode-display_width and
unicode-emoji. Commonmarker, a native Rust gem, is stubbed, as only HTML needs it. The results below also stubbed
socket, which WASI doesn't have, until endpoints, which needed it for ipaddr, only loaded it when one runs.

## Results

Ruby 3.4, ruby.wasm 2.10.1, wasmtime 50.0.1, on an x86_64 Mac. The note and CSV it wrote matched native Ruby's exactly.

| | WebAssembly | Native |
| --- | --- | --- |
| Whole run | 1.31 s | 0.25 s |
| Loading Raindown | 643 ms | 168 ms |
| Writing the table and TOC | 23 ms | 6.4 ms |
| Fixing a column | 8.1 ms | 3.8 ms |
| Expanding a cell | 11.7 ms | 2.1 ms |
| Saving an edit | 10.9 ms | 2.7 ms |

`ruby` is a 34.7 MB module. About 0.6 s of the run is wasmtime compiling it, before Ruby starts.

Still to try: running it in Obsidian, with V8 and a JavaScript WASI shim, the files packed into the module and the vault
as its filesystem, and a custom Ruby build with only the extensions Raindown needs.

## In Obsidian

`obsidian/` is a desktop-only plugin with one command, **Run the WebAssembly write-back**, that runs the same write-back
in Obsidian's own WebAssembly engine, with Node's WASI, and shows how long reading, compiling and running Ruby took.
Ruby's files are read from disk, as with wasmtime, so it doesn't yet try packing them into the module, or mobile.

1. Extract ruby.wasm's WASI build into `runtime/`, which git ignores, then write the plugin's `config.json`:
   `RUBY_WASI=spike/wasm/runtime/ruby-3.4-wasm32-unknown-wasip1-full spike/wasm/obsidian/setup.sh`
2. Link `obsidian/` into a vault's `.obsidian/plugins/` as `raindown-wasm-spike`, and turn it on.
3. Run **Raindown WebAssembly spike: Run the WebAssembly write-back** from the command palette.

### Results in Obsidian

Obsidian's desktop app, on the same Mac, with the same note and CSV as native Ruby's.

| | Obsidian |
| --- | --- |
| Reading the module | 24 ms |
| Compiling it | 60 ms, as V8 compiles each function lazily, the first time it runs |
| Instantiating it | 41 ms |
| Loading Raindown | 783 ms |
| Writing the table and TOC | 32 ms |
| Fixing a column | 17.5 ms |
| Expanding a cell | 10.1 ms |
| Saving an edit | 21.5 ms |

About 1.2 s to the first write-back, once a session, then 10 to 32 ms each. Next: keeping Ruby running between
write-backs, with ruby.wasm's JavaScript build, in a Web Worker so Obsidian doesn't wait for it, with Raindown packed
into the module and the vault as its filesystem, then on a phone.
