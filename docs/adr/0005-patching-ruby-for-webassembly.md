# 5. Patching Ruby's jumps for WebAssembly in the Obsidian plugin

- Status: Accepted
- Date: 2026-11-14

## Context

The Obsidian plugin runs Raindown in [ruby.wasm](https://github.com/ruby/ruby.wasm), Ruby 3.4.1 compiled to WebAssembly, which the plugin builds itself, with `scripts/ruby_wasm.rb`. A benchmark of a vault's Ruby nodes against its JavaScript ones had Ruby several times slower than native Ruby, and three ways to close the gap were on the table: write hot loops with Ruby's C methods, build ruby.wasm for speed, and limit Asyncify to the functions that wait on JavaScript.

Measuring each, in the plugin's worker run by Node, showed the gap wasn't where those three looked:

- **Ruby's own code was 2 to 3 times slower than native, but anything that set up a jump in C was 10 to 35 times slower.** WebAssembly has no `setjmp`, so Ruby's is Asyncify's: it unwinds every call frame to the root and rewinds them, to capture where it is, each time it's called. Ruby's `vm_exec` avoids that, catching a jump as it unwinds past, but the rest of Ruby called `setjmp` for each `rb_ensure`, `rb_protect`, `rb_rescue` and `rb_block_call`, each `catch`, `require` and `raise`, each `==` or `inspect` of an array or hash, and each time a file's read, written or looked for. A write-back called it 13 to 155 times, and starting Raindown about 4,400 times.
- **Ruby 3.4.1 leaked 24 KB for each jump out of a block or method called from C.** A tag's buffer is allocated in WebAssembly, and `vm_exec` popped its tag without freeing it. A loop of `break`, `return`, `throw` or `raise` through a C method, like `Range#each`, slowed as it ran, to hundreds of microseconds each.
- **Each rescued exception leaked stack.** The frames a caught jump unwinds never run their epilogues, which restore the stack pointer, so their stack was kept until the method returned. The plugin answers each request in a Fiber, whose stack is small, so a few thousand in one method failed with `SystemStackError`, or took minutes.
- **The module was already built for speed.** Clang and Binaryen's `wasm-opt` both run at `-O3`. Binaryen 133, in place of rbwasm's 108, and `-O4`, measured the same on every benchmark.
- **Asyncify can't be limited to a list of functions.** Ruby uses it for exceptions, Fibers and garbage collection, which reads the stack through it, not only to wait on JavaScript, so an unwind can start almost anywhere. A function left out that an unwind passes through carries on running, and corrupts memory.

## Decision

**The plugin patches Ruby's source as it builds ruby.wasm**, with `wasm/patches/ruby-3.4-wasm-jumps.patch`, which rbwasm applies with `--patch`. Each change is inside `#if defined(__wasm__) && !defined(__EMSCRIPTEN__)`, so it's Ruby as it was for any other build:

1. **A tag's function is run without `setjmp`**, by `rb_wasm_ec_tag_run`, which catches a jump as `vm_exec` does, with `rb_wasm_try_catch_loop_run`. It's used by `rb_ensure`, `rb_protect`, `rb_vrescue2`, `setup_exception`, `rb_iterate0`, `vm_catch_protect`, `exec_recursive`, `rb_thread_io_blocking_call` and `require_internal`.
2. **A blocking call doesn't save the registers with `setjmp`**, which is for another thread's garbage collection, as WebAssembly runs one thread.
3. **A jump out of `vm_exec` frees its tag's buffer.**
4. **The stack pointer's restored when a jump's caught.**
5. **Tags' buffers are kept to use again**, up to 64, rather than allocated for each call of a block from C.

**The module's built again when a patch changes**, as `bin/build` and CI's cache name it by its patches too, and Ruby's source is extracted again, as rbwasm only patches it as it's extracted.

**The smoke test checks it**, with `test/vault/jumps.md`, which rescues, breaks and throws 20,000 times each in one request. It takes 77 ms with the patch, and fails with `SystemStackError` without it.

**Nothing else changes in the build.** The optimisation flags and Binaryen stay as rbwasm sets them, and Asyncify still instruments all it did.

### Measurements

In the plugin's worker, in Node 22, on an M-series Mac, as milliseconds, with the module built without the patch and with it:

| What                              | Before | After | Native |
| --------------------------------- | ------ | ----- | ------ |
| `Hash#each`, 30,000 times         | 87     | 9.9   | 3.5    |
| `Mutex#synchronize`, 50,000 times | 133    | 10.5  | 3.9    |
| `Array#find`, 20,000 times        | 109    | 12.9  | 4.5    |
| `File.read`, 2,000 times          | 61     | 8     |        |
| JSON, made and parsed 20 times    | 141    | 23    | 8.3    |
| `break` from `Range#each`         | 0.3    | 0.0007 |       |
| Ten Ruby nodes counting primes    | 350    | 268   | 78     |
| The same, in `while` loops        | 148    | 143   | 79     |
| Ten Ruby nodes writing a line     | 3.5    | 2.3   |        |
| A note with a `toc:`              | 1.5    | 0.5   | 0.1    |

A write-back calls `setjmp` no times, and starting Raindown 19 times.

A suite of 95 cases, of exceptions, `break`, `throw`, `ensure`, `retry`, Fibers, enumerators, `require` and file errors, some under `GC.stress`, gives what native Ruby gives, run directly and in a Fiber. Ruby without the patch can't finish it.

### Options considered

|                   | Patch Ruby's C (chosen)                 | Only write Ruby around it                         | An Asyncify list of functions            | A newer Binaryen, or `-O4` |
| ----------------- | --------------------------------------- | ------------------------------------------------- | ---------------------------------------- | -------------------------- |
| Speed             | 3 to 13 times faster where C jumps      | Only where Raindown's own code is changed         | Perhaps 10 to 20% everywhere, unmeasured | None measured              |
| A vault's nodes   | Faster as they're written               | As slow, unless their authors know which methods  | Faster                                   | The same                   |
| The leaks         | Fixed                                   | Still there                                       | Still there                              | Still there                |
| When it's wrong   | A test fails, or a jump isn't caught    | Nothing breaks                                    | Memory's corrupted, anywhere             | Nothing breaks             |
| To keep up        | A patch to carry to each Ruby           | Nothing                                           | A list to check against each Ruby        | A tool to install in CI    |

**Avoiding C methods with blocks in Ruby would have hidden the cost, not removed it**, and only in Raindown's own code. It's also the opposite of what's faster natively, and what a vault's nodes are written for.

## Consequences

- A vault's Ruby nodes are faster without being rewritten, and Raindown starts sooner, as loading it is mostly `require`.
- A node that rescues, breaks or throws in a long loop works, where it failed or stalled.
- The plugin carries a patch of about 800 lines to Ruby's interpreter. It applies to Ruby 3.4.1's tarball, which rbwasm 2.10.1 builds, and a new Ruby or rbwasm may not take it, which fails the build rather than the plugin.
- The module can't be ruby.wasm's own release any more, though it already wasn't, as it leaves out extensions and transcoders.
- A mistake in it would show as a wrong jump, like an `ensure` that doesn't run, in any Ruby the plugin runs. The suite above isn't in the repo, only `jumps.md` is.
- In WebAssembly, a `while` loop is now nearly twice as fast as the same loop in blocks called from C, like `Integer#step`, which are the same speed natively. What's left is the plain cost of calling a block from C, which the patch doesn't change.
- Building the module downloads and extracts Ruby's source each time, which only happens when the script, the gems or a patch change.

## Revisit when

- **ruby.wasm moves to a Ruby that fixes these.** The leak in `vm_exec` and the stack pointer look like bugs upstream would take, so check each part against the new source, and drop what it has.
- **The patch could go upstream.** Parts 3 and 4 are fixes on their own, and part 1 is the same pattern Ruby already uses in `vm_exec`.
- **WebAssembly's exception handling or stack switching reaches Ruby's build.** Either replaces Asyncify's `setjmp`, and most of this with it.
- **Ruby nodes that loop are still too slow.** The cost left is calling a block from C, and Asyncify's checks around every call, which a list of functions would cut, with the risk above.
