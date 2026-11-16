# 6. Running Ruby without Asyncify in the Obsidian plugin

- Status: Accepted
- Date: 2026-11-16

## Context

The Obsidian plugin runs Raindown in [ruby.wasm](https://github.com/ruby/ruby.wasm), and [ADR 5](0005-patching-ruby-for-webassembly.md) made Ruby's jumps cheaper there, with a patch to Ruby's C, but left Asyncify as it was. Asyncify instruments most of Ruby's C, so it can unwind and rewind the stack, for three things: `setjmp`, garbage collection reading the locals on the stack, and switching Fibers, which ruby.wasm's `await` and `evalAsync` use to wait for JavaScript. Every call in that C pays for a check after it, whether anything unwinds or not, so Ruby's own code runs 2 to 3 times as slow as native, and the module's bigger.

WebAssembly now has what each of those needs without Asyncify:

- **Exception handling**, which wasi-libc's `setjmp` is built on, in wasi-sdk 24 and later, and without allocating, with LLVM 19 and later.
- **Binaryen's `--spill-pointers`**, which keeps each local that's live across a call on the stack in memory, where Ruby's garbage collection can read it, in Binaryen versions later than rbwasm's 108.
- **JSPI**, JavaScript Promise Integration, which suspends a stack of WebAssembly until a promise settles, in Chrome 137 and later, so Obsidian's desktop app, and Node 26, but not Safari, so not Obsidian on iPhones and iPads, yet.

## Decision

**The plugin's `main.js` has two modules of Ruby**, and the worker uses the one without Asyncify where the engine has JSPI, `WebAssembly.Suspending` and `WebAssembly.promising`, and Asyncify's, with ADR 5's patch, where it hasn't.

**`scripts/ruby_wasm.rb --jspi` builds the one without Asyncify**, with `wasm/patches/jspi/ruby-4.0-jspi.patch` and the shapes patch, rather than the jumps patch, from wasi-sdk 34 and Binaryen 131, which `bin/build` downloads:

1. **`setjmp` is wasi-libc's**, from WebAssembly's exception handling, and `vm_exec` takes Ruby's own path with it.
2. **Garbage collection reads only the stack in memory**, as the configure runs `--flatten`, `--coalesce-locals` and `--spill-pointers` after linking, in place of `--asyncify`, and fails the build if it can't.
3. **Each Fiber is a stack of JSPI's**, which a switch suspends until something switches back to it, so Fibers switch in Ruby the worker called through `WebAssembly.promising`.
4. **Ruby waits for JavaScript with `RbWasmJSPI.wait`**, which suspends the stack until the promise settles, rather than switching to a Fiber that JavaScript resumes, which a stack of JSPI's can't do.

**Neither module's packed with Raindown's files**, as wasi-vfs can't compile exception handling, but `main.js` has them once, compressed together with gzip, and the worker gives them to Ruby in its in-memory folders.

**The smoke test and the jumps suite run with each module**, the one without Asyncify with Node 26's JSPI, and Asyncify's with JSPI hidden, as in Safari.

### Measurements

Each Ruby built without gems, in Node, as milliseconds, the median of rounds after warming up, with Asyncify and the jumps patch from wasi-sdk 24 and Binaryen 108, and without Asyncify from wasi-sdk 34 and Binaryen 131:

| What                      | Asyncify | Without | Faster |
| ------------------------- | -------- | ------- | ------ |
| The benchmarks' sales node | 141     | 82      | 1.73×  |
| `Hash[str]`, 200,000 times | 66      | 37      | 1.76×  |
| `Array#each` of 200,000   | 32       | 22      | 1.44×  |
| A `while` loop of 200,000 | 19       | 9.5     | 2.02×  |
| 300,000 objects allocated | 261      | 162     | 1.61×  |
| `raise` and `rescue`, 20,000 times | 50 | 51  | 0.98×  |
| `catch` and `throw`, 20,000 times | 15 | 36   | 0.42×  |

In the plugin, in raindown-benchmarks' Obsidian benchmark, a note of ten sales nodes takes 861 ms rather than 1448, a line of Ruby written back 5.2 rather than 7.9, and a list rendered 5.8 rather than 9.8. On CI, Raindown starts in 348 ms without Asyncify and 373 with it, and `main.js` is 6.15 MB, from 5.5.

A `longjmp` is a WebAssembly exception, which takes V8 about 0.4 µs, and a `throw` jumps twice, so `catch` and `throw` are slower. Natively, loading Raindown raises once, and writing back or rendering a note of the plugin's test vault raises or throws about once, but for the note that does 20,000 of each to test them.

### Options considered

|               | Without Asyncify, where JSPI is (chosen) | Asyncify only, as ADR 5 left it | Without Asyncify only |
| ------------- | ---------------------------------------- | ------------------------------- | --------------------- |
| Speed         | 1.5 to 2 times as fast on desktop        | As it was                       | The same, everywhere it runs |
| Safari        | Asyncify's, as before                    | The same                        | Doesn't run, without JSPI |
| `main.js`     | 6.15 MB, with both modules               | About 5.5 MB                    | About 3.5 MB          |
| To keep up    | Two patches, and two toolchains          | One patch                       | One patch, two toolchains |

### Tried and left out

**Spilling less, with a Binaryen of the plugin's own.** Spilling costs 20 to 40% on loops over hashes and arrays, and makes the module a quarter bigger with gzip, while `--flatten` and `--coalesce-locals` cost nothing. A `--spill-pointers` changed to skip calls to functions that can't reach garbage collection, of which 2,086 of 9,617 are, values that can't be pointers, and values already spilled, in `wasm/experiments/without-asyncify/binaryen-131-spill-pointers.patch`, is as safe, under `GC.stress`, and 5 to 19% faster on those loops. But in the plugin, a note of ten sales nodes takes 919 ms rather than 937, one of ten loops over a hash 993 rather than 1035, and one of ten `fib(22)` 41.5 rather than 47.7, within what varies between runs, and the module's 60 KB smaller, about 1% of `main.js`. That isn't worth building Binaryen from source in the plugin's build, and on CI.

**Throwing with one jump rather than two**, by letting a `throw` skip a `vm_exec` with nothing to run. It risks an `ensure` that doesn't run, for jumps that Raindown makes about once a note.

**Without `--flatten`**, `--spill-pointers` misses values on WebAssembly's own stack, rather than in a local, across a call, like the Fiber `rb_fiber_new` makes, which garbage collection then frees, so `Enumerator#next` fails under `GC.stress`. **Without `--coalesce-locals`**, each of a function's locals has its own place on the stack, so `vm_exec_core`'s frame is 25 KB rather than 80 bytes, and 300 levels of recursion through C overflow a Fiber's stack.

## Consequences

- Ruby in the plugin is 1.5 to 2 times as fast on desktop, but for `catch` and `throw`, and starts sooner, without a vault's nodes being rewritten.
- `main.js` carries Ruby twice, and is about 0.65 MB bigger, until Safari has JSPI.
- The build downloads wasi-sdk 34 and Binaryen 131, about 190 MB, 640 MB unpacked, and builds Ruby twice when a patch, the script or the gems change. CI caches both.
- The plugin carries a second patch to Ruby, of about 100 lines, beside ADR 5's, and testing needs Node 26, which has JSPI.
- Fibers switch only in Ruby the worker called through `WebAssembly.promising`. The worker answers each request that way, in a Fiber, as `evalAsync` did, so too deep a stack still raises `SystemStackError` before JSPI's stack, of 984 KB, overflows.
- A build that loses `--spill-pointers` would free objects still in use, so the configure fails the build if `wasm-opt` can't run it, and the jumps suite's `GC.stress` cases fail without it.

## Revisit when

- **Safari ships JSPI.** Asyncify's module, and ADR 5's patch, can go, and `main.js` is about 3.5 MB.
- **Raindown's Ruby nodes do more than a note's worth of calculation.** Spilling less is 10 to 20% on loops, with a Binaryen of the plugin's own.
- **Notes throw in loops.** A `throw` with one jump would bring `catch` and `throw` back to Asyncify's speed.
- **WebAssembly's stack switching ships**, which switches Fibers without a promise, so they'd switch in any Ruby, not only what the worker called through `WebAssembly.promising`.
