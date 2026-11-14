# 5. Patching Ruby's jumps for WebAssembly in the Obsidian plugin

- Status: Accepted
- Date: 2026-11-14

## Context

The Obsidian plugin runs Raindown in [ruby.wasm](https://github.com/ruby/ruby.wasm), Ruby 4.0 compiled to WebAssembly, which the plugin builds itself, with `scripts/ruby_wasm.rb`. A benchmark of a vault's Ruby nodes against its JavaScript ones had Ruby several times slower than native Ruby, and three ways to close the gap were on the table: write hot loops with Ruby's C methods, build ruby.wasm for speed, and limit Asyncify to the functions that wait on JavaScript.

Measuring each, in the plugin's worker run by Node, showed the gap wasn't where those three looked:

- **Ruby's own code is 2 to 3 times slower than native, but anything that sets up a jump in C is 10 to 50 times slower.** WebAssembly has no `setjmp`, so Ruby's is Asyncify's: it unwinds every call frame to the root and rewinds them, to capture where it is, each time it's called. Ruby's `vm_exec` avoids that, catching a jump as it unwinds past, but the rest of Ruby calls `setjmp` for each `rb_ensure`, `rb_protect`, `rb_rescue` and `rb_block_call`, each `catch`, `require` and `raise`, each `==` or `inspect` of an array or hash, and each time a file's read, written or looked for.
- **Ruby allocates 24 KB for each call of a block from C**, for a jump buffer that `vm_exec` never fills, and frees it when the block returns.
- **The module's already built for speed.** Clang and Binaryen's `wasm-opt` both run at `-O3`. A newer Binaryen than rbwasm's, and `-O4`, measured the same on every benchmark.
- **Asyncify can't be limited to a list of functions.** Ruby uses it for exceptions, Fibers and garbage collection, which reads the stack through it, not only to wait on JavaScript, so an unwind can start almost anywhere. A function left out that an unwind passes through carries on running, and corrupts memory.

Ruby 4.0 had already fixed what would have made this worse: Ruby 3.4 kept the stack of each rescued exception until its method returned, and leaked the jump buffer of each `break`, `return`, `throw` or `raise` out of a block called from C. So moving the plugin to Ruby 4.0 came first, and the patch is only for speed.

## Decision

**The plugin runs Ruby 4.0**, as ruby.wasm 2.10.1 builds it, from Ruby 4.0.0's source. Its build traces which standard library files load in the same Ruby, 4.0.0, in the plugin's `.ruby-version`, rather than in Raindown's own, 4.0.9, as it packs only those files, from ruby.wasm's, and a later patch release loads different ones.

**The plugin patches Ruby's source as it builds ruby.wasm**, with `wasm/patches/ruby-4.0-wasm-jumps.patch`, which rbwasm applies with `--patch`. Each change is inside `#if defined(__wasm__) && !defined(__EMSCRIPTEN__)`, beside Ruby's own code, so it's Ruby as it was for any other build:

1. **A tag's function is run without `setjmp`**, by `rb_wasm_ec_tag_run`, which catches a jump as `vm_exec` does, with `rb_wasm_try_catch_loop_run`. It's used by `rb_ec_ensure`, `rb_protect`, `rb_vrescue2`, `setup_exception`, `rb_iterate0`, `vm_catch_protect`, `exec_recursive`, `rb_thread_io_blocking_call` and `require_internal`.
2. **A blocking call doesn't save the registers with `setjmp`**, which is for another thread's garbage collection, as WebAssembly runs one thread.
3. **Tags' buffers are kept to use again**, up to 64, rather than allocated for each call of a block from C.

**The module's built again when a patch changes**, as `bin/build` and CI's cache name it by its patches too, and Ruby's source is extracted again, as rbwasm only patches it as it's extracted.

**The smoke test checks it**, with `test/vault/jumps.md`, which rescues, breaks and throws 20,000 times each in one request. Then `scripts/jumps.js` runs the suite below in the module, and fails the build unless each case is native Ruby's.

**Nothing else changes in the build.** The optimisation flags and Binaryen stay as rbwasm sets them, and Asyncify still instruments all it did.

### Measurements

In the plugin's worker, in Node 22, on an M-series Mac, as milliseconds, with ruby.wasm's Ruby 4.0.0 built without the patch and with it, and native Ruby 4.0.0 without YJIT:

| What                              | Without | With | Native |
| --------------------------------- | ------- | ---- | ------ |
| `Hash#each`, 30,000 times         | 111     | 12   | 3.3    |
| `Mutex#synchronize`, 50,000 times | 160     | 12.5 | 3.3    |
| `catch`, 2,000 times              | 6.1     | 0.5  | 0.1    |
| `raise` and `rescue`, 2,000 times | 11.4    | 3.2  | 0.8    |
| `Range#map` of 10, 20,000 times   | 97      | 27   | 9.4    |
| `File.read`, 2,000 times          | 71      | 8.2  |        |
| JSON, made and parsed 20 times    | 172     | 26   | 6.6    |
| `jumps.md`                        | 308     | 56   |        |
| Ten Ruby nodes counting primes    | 379     | 271  | 77     |
| The same, in `while` loops        | 143     | 142  | 80     |
| Ten Ruby nodes writing a line     | 2.1     | 1.4  |        |
| Ten JavaScript nodes writing one  | 4.4     | 2.1  |        |
| Loading Raindown                  | 115     | 73   |        |

With the patch, a write-back calls `setjmp` twice at most, and starting Raindown 21 times.

A suite of 95 cases, of exceptions, `break`, `throw`, `ensure`, `retry`, Fibers, enumerators, `require` and file errors, some under `GC.stress`, gives what native Ruby 4.0.0 gives, with the patch and without, run directly and in a Fiber, as the plugin answers each request.

### Options considered

|                 | Patch Ruby's C (chosen)              | Only write Ruby around it                        | An Asyncify list of functions            | A newer Binaryen, or `-O4` |
| --------------- | ------------------------------------ | ------------------------------------------------ | ---------------------------------------- | -------------------------- |
| Speed           | 3 to 13 times faster where C jumps   | Only where Raindown's own code is changed        | Perhaps 10 to 20% everywhere, unmeasured | None measured              |
| A vault's nodes | Faster as they're written            | As slow, unless their authors know which methods | Faster                                   | The same                   |
| When it's wrong | A test fails, or a jump isn't caught | Nothing breaks                                   | Memory's corrupted, anywhere             | Nothing breaks             |
| To keep up      | A patch to carry to each Ruby        | Nothing                                          | A list to check against each Ruby        | A tool to install in CI    |

**Avoiding C methods with blocks in Ruby would have hidden the cost, not removed it**, and only in Raindown's own code. It's also the opposite of what's faster natively, and what a vault's nodes are written for.

## Consequences

- A vault's Ruby nodes are faster without being rewritten, and so are its JavaScript ones, as Ruby waits for each in a Fiber, and Raindown loads sooner, as loading it is mostly `require`.
- The plugin carries a patch of about 750 lines to Ruby's interpreter. It applies to Ruby 4.0.0's tarball, which rbwasm 2.10.1 builds, and a new Ruby or rbwasm may not take it, which fails the build rather than the plugin.
- The module can't be ruby.wasm's own release, though it already wasn't, as it leaves out extensions and transcoders.
- A mistake in it would show as a wrong jump, like an `ensure` that doesn't run, in any Ruby the plugin runs. The suite above, `test/ruby/jumps.rb`, runs in each build, after the smoke test.
- The plugin's build needs two Rubies' worth of care: its own, 4.0.0, with Raindown's gems installed in it, and whatever Raindown's developed on. CI installs the plugin's.
- Ruby 4.0 is a larger module than 3.4, so `main.js` is about 0.15 MB bigger, and Ruby itself takes about 50 ms longer to start, which loading Raindown sooner makes up for.
- In WebAssembly, a `while` loop is nearly twice as fast as the same loop in blocks called from C, like `Integer#step`, which are the same speed natively. What's left is the plain cost of calling a block from C, which the patch doesn't change.
- Building the module downloads and extracts Ruby's source each time, which only happens when the script, the gems or a patch change.
- Raindown is on Ruby 4.0 everywhere, though not one patch release: it's developed on 4.0.9, its binaries carry 4.0.7, the latest their tebako runtime has, and the plugin runs 4.0.0, as ruby.wasm builds it.

## Revisit when

- **ruby.wasm builds a later Ruby 4.0.** The plugin's `.ruby-version` follows it, and the patch is applied to the new source, or carried over where it doesn't.
- **The patch could go upstream.** Part 1 is the same pattern Ruby already uses in `vm_exec`, and parts 2 and 3 are small.
- **WebAssembly's exception handling or stack switching reaches Ruby's build.** Either replaces Asyncify's `setjmp`, and most of this with it.
- **Ruby nodes that loop are still too slow.** The cost left is calling a block from C, and Asyncify's checks around every call, which a list of functions would cut, with the risk above.
