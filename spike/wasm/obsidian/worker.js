'use strict';

// Runs in a Web Worker, after ruby.wasm's browser bundle, which gives it ruby-wasm-wasi: starts Ruby once, with the
// files it's sent in Ruby's in-memory / folder, loads Raindown, then runs the write-back again and again on the Ruby it
// kept running, so Obsidian never waits for it.
self.onmessage = async ({ data: { wasm, files, includes, rounds } }) => {
  try {
    const times = {};
    const time = async (name, step) => {
      const started = performance.now();
      const result = await step();
      times[name] = Math.round(performance.now() - started);
      return result;
    };

    const module = await time('compile', () => WebAssembly.compile(wasm));
    const { vm, wasi } = await time('start Ruby', () => self['ruby-wasm-wasi'].DefaultRubyVM(module, { consolePrint: false }));
    await time('add files', () => addFiles(wasi, files));
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

// The files, by their path inside Ruby, like /raindown/lib/raindown.rb, in the in-memory folder ruby.wasm's WASI gives
// Ruby at /, with the folders they're in, and /work, for the note and its CSV.
function addFiles(wasi, files) {
  const root = wasi.fds[3].dir;
  const Directory = root.constructor;
  const File = wasi.fds[0].file.constructor;
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
