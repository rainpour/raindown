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

1. Extract ruby.wasm's WASI build into `runtime/`, which git ignores, and the `dist` folder of the npm package
   `@ruby/3.4-wasm-wasi` into `runtime/npm`, then write the plugin's `config.json`:
   `RUBY_WASI=spike/wasm/runtime/ruby-3.4-wasm32-unknown-wasip1-full RUBY_NPM=spike/wasm/runtime/npm spike/wasm/obsidian/setup.sh`
2. Link `obsidian/` into a vault's `.obsidian/plugins/` as `raindown-wasm-spike`, and turn it on.
3. Run **Raindown WebAssembly spike: Run the WebAssembly write-back** from the command palette.

**Run the write-back in a worker, keeping Ruby running** runs it in a Web Worker instead, with ruby.wasm's JavaScript
build, so Obsidian doesn't wait for it. Ruby's files are sent to the worker, to an in-memory folder, rather than read
from disk, and it starts Ruby once, then runs the write-back five times on the Ruby it kept running.

**Run the write-back packed into the module, without RubyGems** does the same with Ruby's files packed into the
module, so nothing's read from disk or sent but the scenario, as mobile would need, and Ruby started without RubyGems,
which Raindown doesn't need there. `pack.sh` packs it, with rbwasm, from the ruby_wasm gem:
`gem install ruby_wasm`, then
`RUBY_WASI=spike/wasm/runtime/ruby-3.4-wasm32-unknown-wasip1-full RUBY_NPM=spike/wasm/runtime/npm spike/wasm/pack.sh`.

rbwasm can't snapshot a module after Ruby's started and Raindown's loaded, which would skip both when it's run, so
that would need Wizer, and Ruby built for it.

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

### Results in a worker

Ruby kept running in a Web Worker, so Obsidian didn't wait, with the 30.6 MB npm module and 278 files (1.5 MB) sent to
it, then the write-back run five times on it. Each wrote the same note and CSV as native Ruby's.

| | In a worker |
| --- | --- |
| Reading the files | 123 ms |
| Compiling the module | 85 ms |
| Starting Ruby | 707 ms |
| Adding the files | 4 ms |
| Loading Raindown | 801 ms |
| Each write-back, 4 steps | 67 to 118 ms, the first slowest |

About 1.7 s to the first write-back, in the background, then about 16 to 36 ms a step.

### Results packed, without RubyGems

The plugin's third command, with Raindown packed into the module by `pack.sh` and Ruby started without RubyGems. With
the whole standard library packed, then only the 73 files a write-back loads, which `stdlib.rb` lists in `stdlib.txt`:

| | Whole standard library | Only what's loaded |
| --- | --- | --- |
| Module | 32.1 MB, 9.3 MB gzipped | 18.6 MB, 5.4 MB gzipped |
| Starting Ruby | 294 ms | 269 ms |
| Loading Raindown | 840 ms | 689 ms |
| Each write-back, 4 steps | 83 to 159 ms | 68 to 113 ms |

Leaving out RubyGems took starting Ruby from 707 ms to under 300 ms. The module's now mostly Ruby itself, 16.7 MB:
11.7 MB of code and 4.9 MB of data, without debug names, so making it smaller would take building Ruby with fewer
extensions. Loading Raindown, about 200 files, is most of what's left of starting up: about 150 ms natively.

## Bytecode

Most of starting up is loading Raindown, about 200 files, which Ruby parses and compiles. With `WASMTIME`, `pack.sh`
compiles each Ruby file it packs to bytecode with `compile.rb`, in the WASI build's Ruby, the JavaScript build's version
and platform, as bytecode only loads in the Ruby that compiled it, and packs it at `/bytecode` too, in
`raindown-bytecode.wasm`. `bytecode.rb` loads it rather than the source, through `RubyVM::InstructionSequence.load_iseq`,
as Bootsnap does, which the plugin's fourth command, **Run the write-back packed, loading bytecode**, requires first.
Natively, it takes loading Raindown from about 145 ms to 95 ms, and adds 1.4 MB, 0.7 MB gzipped.

### Results with bytecode

Run one after the other in Obsidian, the same note and CSV from both:

| | Source | Bytecode |
| --- | --- | --- |
| Module | 18.6 MB, 5.4 MB gzipped | 20.7 MB, 6.3 MB gzipped |
| Reading and compiling it | 106 ms | 136 ms |
| Starting Ruby | 201 ms | 223 ms |
| Loading Raindown | 670 ms | 360 ms |
| Each write-back, 4 steps | 81 to 113 ms | 67 to 119 ms |

Bytecode compiled by the WASI build loads in the JavaScript build. About 0.7 s to the first write-back, from 1.7 s with
the files sent and RubyGems, and 1.3 s from wasmtime.

## To do

- Test on a phone: load the module without Node, embedded in `main.js` and unpacked with `DecompressionStream`, with
  the vault, through Obsidian's API, as Ruby's filesystem, and time starting up and writing back, and its memory.
- Load Commonmarker only when rendering HTML, as endpoints do sockets, so no stub's needed. Render reading view's
  `<{ }>` sections with Obsidian's own Markdown renderer, or build Commonmarker into Ruby.
- Pack `dirload` and `lownode`, to load a project's `.raindown` nodes, sent from the vault, and run its JavaScript nodes
  in the plugin rather than NodeJS.
- Make the standard library list from every directive's write-back, not just `table:` and `toc:`.
- Compile only the files a write-back loads to bytecode, to shrink it.
- Turn `pack.sh` into the plugin's build step, embedding the compressed module in `main.js`.
- Ask the Obsidian team about a large embedded module before submitting, and explain it in the README.
