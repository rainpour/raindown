# 10. Editions as plugs

- Status: Accepted
- Date: 2026-11-17

## Context

`Raindown::Edition` says what a product built on Raindown has: `FULL`, Raindown itself, or `COMPONENTS`, the Obsidian plugin for beginners, with only Markdown Components. It does it with one boolean, `full?`, which three places check:

- **`Nodes.load_folder`** loads only Markdown Components unless it's full.
- **`Nodes.node_class`** finds Raindown's own nodes, like `toc:`, only when it's full.
- **`Rewriter.rewrite`** returns before endpoints and lining up tables unless it's full.

A third edition, or a feature one edition has and another hasn't, would mean another boolean and more checks of it.

The Obsidian plugin packs only the Ruby that loads while `bin/build` writes back its test vault, which `scripts/trace.rb` lists. Both plugins are built from that one trace, so Components packs everything Raindown's plugin does, like `toc:`, `table:`, endpoints and Ruby and JavaScript nodes, which it never runs: its `main.js` is 6 bytes bigger than Raindown's, at 5.78 MB. It can't be traced on its own yet, as Raindown loads all of it, whatever the edition, from `require`s at the top of `raindown.rb`, `nodes.rb` and `rewriter.rb`.

Raindown already has [Plugs](https://github.com/raindeer-rb/plugs), in `Elements`, which names features, each with what it loads, and slices them by key, and its `lazy` blocks only load a feature's files when it's asked for.

## Decision

**An edition is a set of features, as plugs, and loads only theirs, so tracing each edition packs only what it runs.**

`Raindown::Features`, in `lib/raindown/features.rb`, has each feature as a plug, each requiring its files in a `lazy` block, so a file loads the first time an edition that has its feature asks for it:

- **`write_in`:** write-in nodes' lexeme and nodes, which were `Elements`, now gone.
- **`code_components`:** `RubyNodes`, a project's Ruby nodes, which `Nodes` loaded itself before, and `JSNodes`.
- **`markdown_components`:** `MarkdownNodes`.
- **`built_ins`:** Raindown's own nodes, like `toc:`, which already autoload as a note names them.
- **`pages`:** a project's notes, which `list:` lists and wiki links link to, listed with Dirload, which `Edition#metadata` gives, or `NoMetadata`.
- **`endpoints`:** `EndpointRunner`, and the endpoint lexeme and node for Antlers.
- **`schemas`:** `SchemaBlock`, which bare directives read `schema:` blocks with.
- **`tables`:** `TableFormatter`.

```ruby
FULL = new(folder: '.raindown', features: %i[write_in code_components markdown_components built_ins endpoints schemas tables])
COMPONENTS = new(folder: 'Components', features: %i[write_in markdown_components])
```

- **`full?` goes.** Each place asks the edition for what its features have, with `Edition#plugs(key)`, which is kept, as bare directives ask on each line:
  - `Nodes.load_folder` loads with each of its `components`, in order, and `Nodes.loaded_class` finds a node in the first that has it.
  - `Nodes.node_class` finds a built-in in its `built_ins`.
  - `Rewriter.rewrite` runs its `endpoint_runner`, then each `table_formatter`.
  - `BareDirectives` reads a `schema:` block with its `schema_block`.
  - `PreRenderer` gives Antlers its `elements`, its lexemes and nodes.
- **The `require`s moved into the plugs**, from the tops of `raindown.rb`, `nodes.rb`, `rewriter.rb`, `bare_directives.rb` and `elements.rb`. What only the app and the terminal use, like `Projects.node?`, requires what it needs itself.
- **A spec guards it:** writing back and rendering a note with `Edition::COMPONENTS`, in a fresh Ruby, loads none of the other features' files, so a `require` added back at the top of a file fails a spec, not a release.
- **The plugin traces each edition apart.** `scripts/trace.rb` takes the edition, writing back the test vault as that plugin does, with its Markdown Components in Components' folder, and `bin/build` stages, compiles and packs each one's Ruby on its own, sharing the modules. The plugin's worker connects endpoints' requests and JavaScript Components only for Raindown, with `RaindownWorker.connect_raindown`.

## Consequences

- **An edition is a list of features**, so a new one, like Components with tables, is a line, and a new feature is one plug, not a check in each place that would need one.
- **Components loads and packs only what it runs.** Its trace packs 44 standard library files rather than 67, and Antlers, Lowkey, Plugs and Raindown, rather than 18 gems, without Dirload, FileUtils or tmpdir, which the trace no longer loads for itself. Its `main.js` is 5.16 MB rather than 6.01 MB, compressed with Zlib, about 4.96 MB with zopfli, as CI compresses it, and it starts in about the same time, using about 20 MB less memory: most of it's ruby.wasm, which both need.
- **The trace still decides what's packed**, so a file that loads only on a path the test vault never takes is still left out. Plugs makes it plain which features each edition should run, so the vault can be checked against them.
- **A build traces and packs twice.** Each edition's Ruby is compiled to bytecode and packed on its own, though the ruby.wasm modules, which take longest, are built once and shared.
