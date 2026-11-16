# 7. Collecting garbage between requests in the Obsidian plugin

- Status: Accepted
- Date: 2026-11-16

## Context

[ADR 6](0006-ruby-without-asyncify.md) runs Ruby without Asyncify in the Obsidian plugin where the engine has JSPI, as on desktop. Ruby's garbage collection finds the objects still in use by reading the stack, but WebAssembly keeps a function's locals where nothing else can read them, so ADR 6 builds Ruby with Binaryen's `--spill-pointers`, which copies each local that's live across a call to the stack in memory, around nearly every call in Ruby's C, in case a collection happens inside it.

That copying costs time on every call, whether a collection happens or not: without it, Ruby's loops over arrays and hashes take 15 to 30% less time, allocating takes a fifth less, and garbage collection itself half as long, while Ruby code in its VM, like a `while` loop, takes the same. The plugin answers one request at a time, a note's write-back or render, and each of a note's nodes answers and is done, so when it's answered, no Ruby's on the stack, and there's nothing for a collection to find there.

## Decision

**The module without Asyncify collects garbage only between requests, and spills nothing.** `wasm/patches/jspi/ruby-4.0-jspi-idle-gc.patch` makes Ruby refuse to collect anywhere else, `GC.start` too, as `GC.disable` does, so its heap grows during a request, and notes that it wanted to. The worker calls `rb_wasm_jspi_gc` after each answer, which collects if Ruby wanted to, a minor or major collection as Ruby would. The configure runs `--flatten` and `--coalesce-locals` after linking, but not `--spill-pointers`.

**It doesn't collect while a Fiber's suspended**, as the Fiber's stack might hold an object only in a local. Raindown uses none, and a request's own Fiber has finished by then.

**The engine starts Ruby again once its memory's past 512 MB.** WebAssembly's memory never shrinks, so it stays as big as the heaviest request made it, about 330 MB after a few notes, as Ruby keeps 280 MB for its shapes, and more after a heavy note, or with each request while a node's left a Fiber suspended. Each answer gives Ruby's memory's size, and once nothing's waiting for an answer, the engine stops the worker and starts it again, which takes about 400 ms, while idle.

### Measurements

In the plugin, in Node 26, on raindown-benchmarks' vault, of a year of 2,000 orders, with its note of ten sales nodes, and that note again on 20,000, in milliseconds, against ADR 6's module:

| What                                   | Spilled       | Collecting between requests |
| -------------------------------------- | ------------- | --------------------------- |
| `main.js`                              | 6.40 MB       | 5.99 MB                     |
| Raindown started                       | 472–547       | 411–423                     |
| Ten sales nodes, 2,000 orders          | 102–119       | 78–80                       |
| The benchmarks' vault, all of it       | 2838–2931     | 2129–2147                   |
| The test vault, all of it              | 3925–4088     | 3383–3482                   |
| Ten sales nodes, 20,000 orders         | 843–933       | 697–728, then 72 collecting |
| The process's peak memory, 20,000 orders | 288–335 MB  | 432–480 MB                  |

### Options considered

|                 | Between requests (chosen) | Spilling everything, as ADR 6 did | At interrupt checks |
| --------------- | ------------------------- | --------------------------------- | ------------------- |
| Speed           | 15 to 25% faster          | As it was                         | 5 to 15% faster on a note's usual data, none on heavy |
| Memory          | As much as the heaviest request, up to 512 MB | As it was     | As it was           |
| `main.js`       | 0.4 MB smaller            | As it was                         | 0.1 MB smaller      |
| To keep up      | A patch of 100 lines      | Nothing more                      | A patch, and a Binaryen built from source |

### Tried and left out

**Collecting at interrupt checks**, with a Binaryen of the plugin's own, whose `--spill-pointers` spills only at calls that can reach a collection there and return, keeps memory bounded, and a suspended Fiber's safe, but nearly every function in Ruby's C can still reach one, as raising runs Ruby, allocating runs garbage collection's event hooks, and an indirect call reaches every function of its type, so it spills nearly as much. In `wasm/experiments/without-asyncify` in the plugin's repo, with how it was timed.

## Consequences

- Notes write back 15 to 25% faster on desktop, and Raindown starts sooner, as the module's smaller.
- A request's garbage stays until it's answered, so a heavy note can take a few hundred MB more, until the engine starts Ruby again.
- `GC.start` in a vault's Ruby node only collects once the note's answered, and `GC.stress` doesn't collect in the plugin, so the jumps suite's cases under it no longer test garbage collection there.
- A node that keeps a Fiber suspended between requests, like an `Enumerator` part way through `next`, stops garbage collection until Ruby starts again.
- The module without Asyncify can't run where memory's scarce, as on phones, without starting Ruby again sooner, or spilling as ADR 6 did.

## Revisit when

- **Safari ships JSPI**, so phones run the module without Asyncify, with less memory to spare: start Ruby again sooner, or build it for them as ADR 6 did.
- **Notes allocate more than 512 MB in one request**, as Ruby's heap can't shrink until it's answered.
- **WebAssembly's stack switching or GC proposals let Ruby find its locals**, which would make spilling unnecessary.
