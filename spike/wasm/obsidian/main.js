'use strict';

// Times Raindown's write-back in Ruby compiled to WebAssembly, run by Obsidian's own engine, with Node's WASI, which
// Obsidian's desktop app has. config.json, which setup.sh writes, says where Ruby is and maps the folders it needs in.
const fs = require('fs');
const path = require('path');
const { Notice, Plugin } = require('obsidian');

module.exports = class RaindownWasmSpike extends Plugin {
  onload() {
    this.addCommand({ id: 'run', name: 'Run the WebAssembly write-back', callback: () => this.run() });
    this.addCommand({ id: 'worker', name: 'Run the write-back in a worker, keeping Ruby running', callback: () => this.runInWorker() });
    this.addCommand({
      id: 'packed', name: 'Run the write-back packed into the module, without RubyGems', callback: () => this.runPacked()
    });
  }

  config() {
    const here = path.join(this.app.vault.adapter.getBasePath(), this.manifest.dir);
    return { here, ...JSON.parse(fs.readFileSync(path.join(here, 'config.json'), 'utf8')) };
  }

  async run() {
    const { WASI } = require('wasi');
    const config = this.config();
    const work = config.dirs['/work'];
    fs.readdirSync(work).forEach((file) => fs.rmSync(path.join(work, file)));
    const outputPath = path.join(work, 'output.txt');
    const output = fs.openSync(outputPath, 'w');
    new Notice('Running Raindown in WebAssembly…');
    await new Promise((resolve) => { setTimeout(resolve, 50); }); // So the notice shows before Ruby blocks.

    const times = {};
    const time = async (name, step) => {
      const started = performance.now();
      const result = await step();
      times[name] = Math.round(performance.now() - started);
      return result;
    };

    const bytes = await time('read', () => fs.readFileSync(config.ruby));
    const module = await time('compile', () => WebAssembly.compile(bytes));
    const wasi = new WASI({
      version: 'preview1',
      args: ['ruby', '--disable-gems', '-rrbconfig', ...config.includes.map((dir) => `-I${dir}`), '/spike/writeback.rb', '/work'],
      env: {},
      preopens: config.dirs,
      stdout: output,
      stderr: output,
      returnOnExit: true
    });
    const instance = await time('instantiate', () => WebAssembly.instantiate(module, wasi.getImportObject()));
    const status = await time('run', () => wasi.start(instance));
    fs.closeSync(output);

    const text = fs.readFileSync(outputPath, 'utf8');
    const summary = `${(bytes.length / 1e6).toFixed(1)} MB: read ${times.read} ms, compile ${times.compile} ms, ` +
      `instantiate ${times.instantiate} ms, run ${times.run} ms${status ? `, exit ${status}` : ''}`;
    console.log(`Raindown WebAssembly spike\n${summary}\n\n${text}`);
    new Notice(`${summary}\n\n${text.trim().split('\n').at(-1)}`, 0);
  }

  // Runs the write-back in a Web Worker, with ruby.wasm's JavaScript build and Ruby's files sent to it in memory, rather
  // than read from disk.
  runInWorker() {
    const config = this.config();
    const files = {};
    Object.entries(config.pack).forEach(([inside, outside]) => this.pack(files, inside, outside));
    return this.runWorker({ config, wasmPath: config.stdlibWasm, files });
  }

  // Runs the write-back in a Web Worker, with Ruby's files packed into the module by pack.sh, so only the scenario's sent,
  // and Ruby started without RubyGems, which Raindown doesn't need, as its files are found on its load path.
  runPacked() {
    const config = this.config();
    const files = {};
    this.pack(files, '/spike/scenario.rb', config.pack['/spike/scenario.rb']);
    const args = ['ruby.wasm', '--disable-gems', '-EUTF-8', '-e_=0'];
    return this.runWorker({ config, wasmPath: config.packedWasm, files, args, packed: config.packedDirs });
  }

  // Starts Ruby once in a Web Worker, then runs the write-back several times on the Ruby it kept running.
  async runWorker({ config, wasmPath, files, args, packed }) {
    new Notice('Running Raindown in a worker…');
    const started = performance.now();
    const wasm = new Uint8Array(fs.readFileSync(wasmPath));
    const megabytes = (wasm.length / 1e6).toFixed(1); // Sending its bytes to the worker empties it.
    const read = Math.round(performance.now() - started);
    // The bundle only gives DefaultRubyVM, which can't take Ruby's arguments, so it gives RubyVM and the WASI classes too.
    const bundle = fs.readFileSync(config.browserBundle, 'utf8').replace('exports.DefaultRubyVM = DefaultRubyVM;',
      'exports.DefaultRubyVM = DefaultRubyVM; Object.assign(exports, { RubyVM, WASI, OpenFile, File, PreopenDirectory, Directory });');
    const code = `${bundle}\n${fs.readFileSync(path.join(config.here, 'worker.js'), 'utf8')}`;
    const worker = new Worker(URL.createObjectURL(new Blob([code], { type: 'text/javascript' })));

    const result = await new Promise((resolve) => {
      worker.onmessage = ({ data }) => resolve(data);
      worker.onerror = (event) => resolve({ error: event.message });
      worker.postMessage({ wasm: wasm.buffer, files, includes: config.includes, rounds: 5, args, packed }, [wasm.buffer]);
    });
    worker.terminate();
    if (result.error) {
      console.error(`Raindown WebAssembly spike\n${result.error}`);
      new Notice(`Raindown in a worker failed: ${result.error.split('\n')[0]}`, 0);
      return;
    }

    const size = Object.values(files).reduce((sum, bytes) => sum + bytes.length, 0);
    const steps = Object.entries(result.times).map(([name, ms]) => `${name} ${ms} ms`).join(', ');
    const rounds = result.runs.map(({ total }, round) => `${round + 1}: ${total} ms`).join(', ');
    const summary = `${megabytes} MB, read in ${read} ms, and ${Object.keys(files).length} files (${(size / 1e6).toFixed(1)} MB)\n` +
      `${steps}\nwrite-backs, 4 steps each: ${rounds}`;
    const last = result.runs.at(-1);
    console.log(`Raindown WebAssembly spike\n${summary}\n${JSON.stringify(last.times)}\n\n${last.text}\n${last.csv}`);
    new Notice(summary, 0);
  }

  // The file, or the files in the folder and its folders, by their path inside Ruby.
  pack(files, inside, outside) {
    if (!fs.statSync(outside).isDirectory()) {
      files[inside] = new Uint8Array(fs.readFileSync(outside));
      return;
    }
    fs.readdirSync(outside).forEach((name) => this.pack(files, `${inside}/${name}`, path.join(outside, name)));
  }
};
