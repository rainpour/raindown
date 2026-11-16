# TODO

## Starting the Obsidian plugin faster

The plugin's `main.js` carries ruby.wasm's module compressed with gzip by zopfli, in Z85, which the browser decompresses itself while compiling it. With JSPI, in Chrome, starting takes about 350–420 ms: decoding and decompressing the module about 50 ms, unpacking Ruby's files about 27, starting Ruby about 97 and loading Raindown 125–180. Without it, as on phones, about 580 ms. The smoke test prints each step's time, and Obsidian's console shows it as `Raindown started`. About half of starting Ruby and loading Raindown is V8 compiling WebAssembly's functions the first time they're called, not Ruby's own work, which is also why the first write-back after starting takes about 115 ms, and the next 2–18. Measured in headless Chrome 157 and Node 26 on 2026-11-17.

**Write back and render a note once as Raindown starts.** A tiny note with front matter, `toc:` and `<{ toc: }>`, written back and rendered at the end of `start` in `src/worker.js`, compiles the functions a write-back needs: the first real write-back takes about 20 ms rather than 115, and the second 2.4 rather than 18. Starting takes about 130 ms longer, but the plugin starts Raindown when Obsidian's layout is ready, so that's usually before a note's opened. About 6 lines. Phones' first write-back, about 263 ms, should gain more, but wasn't measured.

**Start the worker before reading the vault.** The engine reads the vault, then starts the worker, so they don't overlap. Starting the worker first, waiting for it to say it's begun, then reading the vault and sending it as a message of its own, which the worker waits for once Raindown's loaded, saved 100 ms of 597 in a vault of 3,000 notes, and 18 on the test vault. It needs the wait for the worker's message, or the worker doesn't get going while the vault's read. It grows with the vault, up to the 300–400 ms the two take, and helps phones too.

**Send the worker only the module it'll use.** The engine can check for JSPI as the worker does, rather than sending both modules, 2.8 and 1.8 MB, to the worker each time it starts. Under 5 ms on its own.

**Decompress Ruby's files while the module compiles.** In `start`, Ruby's files are decompressed after the module's compiled. Overlapping them saved about 35 ms in Node and 10 in Chrome, where compiling took a little longer. 3 lines.

**Base64 rather than Z85.** `Uint8Array.fromBase64` decodes the module in 3 ms rather than 11, and Ruby's files in about 1 rather than 10–19, but makes `main.js` 6.4% bigger, and needs Chromium 140 or iOS 18.2, or a fallback.

**Raindown's bytecode in one file, with an index, and the standard library first in the load path.** Loading Raindown is 264 requires and about 280 files, with about 3,600 calls into the WASI shim: 1,045 `path_open`, about 760 of them misses searching the load path, 1,095 `path_filestat_get`, for Ruby's realpath, and 1,211 `fd_fdstat_get`. Reading the bytecode from one file with an index, as it's already contiguous in `root.bin`, saved about 10 ms of 122, and pushing the standard library's folders onto the load path rather than unshifting them, in `src/worker.js`, about 6 more. No gem's file shadows one of the standard library's. The biggest pieces loaded are YAML, through front matter, 19–29 ms, Antlers with Lowkey 12–15, JSON 13 and endpoints with curl 7–10, which could load when first used.

**Keep V8's compiled code between launches.** The biggest lever: in Chrome, with the module served from a URL and compiled with `WebAssembly.compileStreaming(fetch(url))`, V8 keeps its compiled code, and from the third launch starting Ruby took 34 ms rather than 93, loading Raindown 55 rather than 120, and starting 235 rather than 430. A `WebAssembly.Module` can't be kept in IndexedDB in Chromium, and V8 didn't keep code compiled from a `blob:` or a made-up `Response` in the Cache API, though that saved decoding and decompressing on later launches. To try in Obsidian: write the decompressed module into the plugin's folder, compile it in the worker from `app.vault.adapter.getResourcePath(...)`, relaunch three or more times, keeping Obsidian open over 2 seconds each time, and see whether starting Ruby and loading Raindown take less. It only works if Obsidian's `app://` scheme has Electron's code cache privilege, which is unknown.

**Snapshot Ruby with Raindown loaded, with Wizer.** Raindown's directives now load when a note first uses them, and garbage collection's paused while it loads, so starting Ruby takes about 90–100 ms and loading Raindown about 100–140 ms. A snapshot taken at build time would skip both, saving about 200 ms, but it keeps Ruby's memory once Raindown's loaded in the module: 11.3 MB in non-zero pages, 2.8 MB gzipped, in place of the module's data, 0.75 MB gzipped, taking `main.js` from 3.94 MB to about 6.1 MB, over 5 MB. Collecting first doesn't shrink it, and Ruby can't compact in WebAssembly. Building it needs a Rust program running Wizer with stand-ins for the js extension's imports, a C function in ruby.wasm that starts Ruby and requires Raindown, the worker not starting Ruby again, as `RubyVM.instantiateModule` does, and `__wasilibc_reset_preopens`, so the vault's folder is found. Worth it only if the size budget grows, or the memory shrinks. Prototyped again on 2026-11-17, restoring Ruby's memory and globals in place of starting Ruby and requiring Raindown: only 9 MB is non-zero, about 1.9 MB gzipped for each module, and it passes the smoke test with both. Starting takes 100–157 ms less, but the first answer only 14–44 ms less in Node, and from 71 ms less to 61 more in Chrome, as V8 compiling functions moves into the first write-back. Worth it with V8's code kept between launches, not without.

## Faster write-backs

Raindown's write-back of a note of 10 Ruby components took about 4 ms in the Obsidian plugin, mostly Raindown's own Ruby, which runs without a JIT in WebAssembly. Compiling its regexes once, reading plain values without Prism, and skipping endpoints and tables a note hasn't got took `write_rb` to about 1.7 ms and `html_rb` to about 2, on 2026-11-17. What's left, profiled natively with stackprof on Ruby 4.0 with YJIT off:

1. **Stop sending every file's front matter to each JavaScript node.** `json_context`, in `lib/raindown/js/js_nodes.rb:140`, sends `metadata.list.map(&:metadata)` with every call of a JavaScript node, so in a vault of 5,000 notes, Ruby in WebAssembly serialises 5,000 files' front matter 10 times for a note of 10 nodes, and JavaScript parses it again: `write_js` takes 175–270 ms rather than 4. Build it once a request, or send it only when a node asks for the vault's files.
2. **Stop keeping every node made.** `Nodes.instances` and `Nodes.list` keep each node instance, by its props, for as long as Ruby runs, so in the plugin, each edit of a prop, like `n: 1` to `12` to `123`, leaves another alive until Ruby starts again.
3. **Read plain values in Lowkey.** Raindown reads whole numbers, and quoted text without `\` or `#`, without Prism, in `NodeBlocks.value`, but Lowkey would do it for everyone, as the pending spec in `prism_loading_spec`, "needs a Lowkey that reads plain values without Prism", says.
4. **Smaller ones, each under 2–3% natively.** `Nodes.call` and `values_problem` call `method(...).parameters` on every call, and `Nodes.instance` hashes a `[klass, args, props]` key on every call.

## The Obsidian plugin's work around each request

Measured with `notes.js`, as each step's median, on 2026-11-17. About 0.9 ms of a 3.7 ms write-back of `write_rb` is outside Ruby, and more in a big vault.

1. **Note what Ruby writes, rather than walking the vault for it.** `writtenFiles`, in `src/worker.js`, walks every file in the vault after each answer, to find those Raindown wrote: 0.7–0.8 ms with 5,000 notes, growing with the vault. Wrapping the root folder's `path_open`, for paths opened to create, truncate or write, and `path_link`, for renames, and noting `services.write`'s paths, then checking only those, gave the same files for a `table:` edit and every note in the test vault. +24 −10 lines. A write that went round `path_open` and `path_link` would be missed, though none does, and `services.write`'s isn't tested.
2. **Evaluate Ruby once a request, not twice.** `evalWaiting`, in `src/worker.js`, evaluates `RbWasmJSPI.entry = -> { ... }` and `RbWasmJSPI.take` as Ruby source each request. Setting the entry only when its code changes, and calling `take` on `RbWasmJSPI`, kept from when Raindown loads, saves about 0.15 ms a request. +8 −2 lines.
3. **Check `.raindown` while Ruby answers.** The engine checks whether a `.raindown` folder changed before each request, 0.4–0.5 ms in 4 rounds of 8 calls to the vault's adapter, one after another. Checking while the request runs, and asking again if it changed, gained nothing in Node, where the worker shares the thread, but should save it all in Obsidian, unmeasured. Or stat the known files in one round, at once, or see whether Obsidian's `raw` vault event reports changes in hidden folders on desktop, which would need no check.
4. **A second write-back right after another takes 18 ms with JSPI, and 4 with Asyncify,** in Chrome, for `bare.md`. Probably the collection after each request, which the next waits for. Not looked into.
5. **`notes.js` times the collection after a heavy note with it,** about 9 ms after `work_rb`, as it runs in the same thread, where in Obsidian it's after the answer's sent. **And its worker's `terminate` does nothing,** so each time Ruby starts again, the old one stays in memory, and the process grows by about 150 MB.

## The Obsidian plugin's Ruby build

Compiler and Binaryen options for the module without Asyncify, measured with `bench/idle.rb` on 2026-11-17. `-O4`, and `-O3` twice, after linking, were no faster than `--flatten --coalesce-locals -O3`.

1. **Drop `--flatten --coalesce-locals` after linking.** They were only for `--spill-pointers`, which collecting between requests dropped. Without them, post-linking takes 26 s rather than 159, in 201 MB of memory rather than 738, for a module 2.5 KB smaller with gzip, as fast, or up to 2% slower, within noise. Check on a quiet machine, then drop them from `wasm/patches/jspi/ruby-4.0-jspi.patch`'s configure.
2. **Clang's options, being measured.** `-O2` makes the module 2.4% smaller, 1.18 MB with gzip rather than 1.21, and gives native Ruby's answers, but isn't timed yet. Also being built and timed: `-msimd128`, Chrome 91 and Safari 16.4, `-mtail-call`, Chrome 112 and Safari 18.2, `-flto`, with wasi-sdk 34's LTO libc, and `-mno-bulk-memory-opt`, as clang makes every `memcpy` and `memset` of a size it doesn't know `memory.copy` and `memory.fill`, 674 and 291 of them, where wasi-libc's `memcpy` loops up to 32 bytes, about 2 ns faster for each copy of 8–32 bytes in V8. And Binaryen's `-ifwl`, `-fimfs 100`, `--low-memory-unused` and `--converge`.
3. **Not worth it:** another allocator, as `dlmalloc` and `dlfree` are under 1% of the time, and wasi-libc only has dlmalloc, or Ruby's dispatch, which is already one jump table, or debug options, which release builds already leave out.

## Shift_JIS CSVs from Japanese Excel

Raindown reads tables' CSVs and charts' data as UTF-8 (`encoding: 'bom|utf-8'` in `table/table_file.rb` and `chart/points.rb`), so a CSV from Japanese Excel, which saves Shift_JIS by default, comes out garbled or fails, in the CLI, the app and Obsidian alike. Japanese, Chinese and Korean text in UTF-8 works everywhere, as Obsidian always saves UTF-8.

**Read Shift_JIS CSVs.** When a data file isn't valid UTF-8, try reading it as Shift_JIS, then EUC-JP, and convert it to UTF-8, writing an edited table back in the file's own encoding. That needs Ruby's Japanese transcoders, which the Obsidian plugin's ruby.wasm leaves out, with the Chinese and Korean ones, as 2.6 MB of tables (`TRANSCODERS_LEFT_OUT` in its `scripts/ruby_wasm.rb`). Taking `japanese`, `japanese_sjis`, `japanese_euc` and `iso2022` off that list adds them back, for about 0.4 MB of `main.js`.

## Endpoint response freshness

A response only refreshes when its code block is emptied, so once written it stays, and a year-old response looks the same as one fetched today. Readers, and agents especially, can't tell whether an example still holds. Responses now record the date they were fetched (`<!-- raindown:fetched 2026-10-14 -->`), but nothing checks they still match.

**Check mode.** `raindown file.rd --check` re-runs every endpoint without writing, and exits non-zero listing the responses that no longer match, for CI. Needs a way to ignore fields that change every request (ids, timestamps), for example an `ignore:` list on the directive or a JSON path list.

## Code feelings

Ideas for the feelings screen, roughly most useful first.

1. **Jump to the next unfelt method.** Felt methods go blank, so late in the week the grid is mostly empty, and the arrows step through cells there's nothing left to do in. `n` and `N` could jump to the next or previous unfelt method in reading order.
2. **Undo the last feeling.** One wrong key, like `1` instead of `2`, notes a feeling straight away, and the only way back is feeling it again. `u` could remove the last row from `feelings.csv` and select its method again.
3. **Click a bin to feel the selected method.** The bins are drawn, but clicking them does nothing, as they have no click events. With hover already working, Code feelings could be used with the mouse alone.
4. **The hovered method's name in the status line.** The code box doesn't follow the mouse, so while hovering, the status line could show `lib/text.rb:62 · Text#segments_between`, and "This week's code to feel" otherwise.
5. **Esc collapses an expanded code box.** Esc only does something while a note's being typed.
6. **How many are left, beside "39% refined".** Like "12 left", which says more near the end of the week.
7. **A scroll hint when an expanded box pushes rows off the grid.** A faint `↑` or `↓` at the grid's edge, so it's clear it's scrolled.
8. **A resize during the celebration** can pick a bigger batch, with unfelt methods, while the rain or waffle carries on. Not picking again until the celebration's over would fix it.

## Tebako boot time

The packed binary is slow to start. A plain note takes about 1.1s, against 0.35s from source. A table or chart adds about 0.5s more.

The cause is macOS's malware scan (XProtect). Each native extension is scanned every time the app starts, because Tebako copies it to a new random folder each time. Each scan takes about 0.4s. Raindown loads three: `commonmarker`, `prism`, and `strscan` (which `csv` loads). Ruby's own loading is fast. See [tamatebako/tebako#1026](https://github.com/tamatebako/tebako/issues/1026).

The fix is [3769344](https://github.com/tamatebako/tebako/commit/3769344). It keeps each extension in the same folder, so macOS only scans it once. It's not in a release yet. 2.8.76 came out just before it, and isn't any faster.

**When a release has the fix:**

1. Download it: `gh release download vX -R tamatebako/tebako -p 'tebako-X-macos-x86_64*' -D tmp/tebako-bin`. Check the `.sha256` file matches, and run `chmod +x` on it.
2. Build with it: `TEBAKO=tmp/tebako-bin/tebako-X-macos-x86_64 mise exec -- bundle exec rake tebako`. The rake task pins runtime 0.16.32. A new Tebako may need a newer one. (Tebako 2.8.76 can't use the 0.17 runtimes, which come with Ruby 3.4.12.)
3. Time `--version`, a plain note, a `chart:` and a `table:` with `--html`. Run each once first, then time a few runs. Compare with `~/.local/bin/raindown`. It should be about 0.4s faster for each extension a note loads.
4. To time each extension, run the binary with `RUBYOPT=-r<script>`, where the script times each `require`. Before the fix, `strscan.so` alone took 0.44s.
5. Check that lazy loading still helps. Loading `csv` and `prism` at startup didn't help with 2.8.76. With the fix, a plain note that doesn't load them should still be fastest.

**Watch out: a rebuild can run old code.** Tebako caches each package's files in `~/.tebako/payloads`, by name. If you rebuild the same version, it keeps using the old cached files, and only says so in `~/.tebako/journal.log`. Delete `~/.tebako/payloads/raindown-*` before timing a rebuild. Or add a hash of the package to `payload_name` in `rakelib/tebako.rake`.
