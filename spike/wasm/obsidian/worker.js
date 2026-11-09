'use strict';

// Runs in a Web Worker, after ruby.wasm's browser bundle, which gives it ruby-wasm-wasi, with RubyVM and the WASI
// classes the plugin adds to it: starts Ruby once, with its arguments, like --disable-gems, and the files it's sent in
// Ruby's in-memory / folder, loads Raindown, then runs the write-back again and again on the Ruby it kept running, so
// Obsidian never waits for it.
const { RubyVM, WASI, OpenFile, File, PreopenDirectory, Directory } = self['ruby-wasm-wasi'];

self.onmessage = async ({ data: { wasm, files, includes, rounds, args } }) => {
  try {
    const times = {};
    const time = async (name, step) => {
      const started = performance.now();
      const result = await step();
      times[name] = Math.round(performance.now() - started);
      return result;
    };

    const module = await time('compile', () => WebAssembly.compile(wasm));
    const root = new PreopenDirectory('/', new Map());
    const wasi = new WASI([], [], [...[0, 1, 2].map(() => new OpenFile(new File([]))), root], { debug: false });
    const { vm } = await time('start Ruby', () => RubyVM.instantiateModule({ module, wasip1: wasi, args }));
    await time('add files', () => addFiles(root.dir, files));
    await time('load Raindown', () => vm.eval([
      "require 'rbconfig'",
      `$LOAD_PATH.unshift(*${JSON.stringify(includes)})`,
      "require 'raindown/rewriter'",
      "require '/spike/scenario'"
    ].join('\n')));

    const runs = [];
    for (let round = 0; round < rounds; round++) {
      const started = performance.now();
      const result = JSON.parse(vm.eval("RaindownSpike.run('/work')").toString());
      runs.push({ ...result, total: Math.round(performance.now() - started) });
    }
    self.postMessage({ times, runs });
  } catch (error) {
    self.postMessage({ error: `${error.message}\n${error.stack}` });
  }
};

// The files, by their path inside Ruby, like /raindown/lib/raindown.rb, in the in-memory folder Ruby has at /, with the
// folders they're in, and /work, for the note and its CSV.
function addFiles(root, files) {
  const folder = (parts) => parts.reduce((dir, part) => {
    if (!dir.contents.has(part)) {
      const child = new Directory(new Map());
      child.parent = dir;
      dir.contents.set(part, child);
    }
    return dir.contents.get(part);
  }, root);

  folder(['work']);
  for (const [file, bytes] of Object.entries(files)) {
    const parts = file.split('/').filter(Boolean);
    folder(parts.slice(0, -1)).contents.set(parts.at(-1), new File(bytes));
  }
}
