'use strict';

// Times Raindown's write-back in Ruby compiled to WebAssembly, run by Obsidian's own engine, with Node's WASI, which
// Obsidian's desktop app has. config.json, which setup.sh writes, says where Ruby is and maps the folders it needs in.
const fs = require('fs');
const path = require('path');
const { Notice, Plugin } = require('obsidian');

module.exports = class RaindownWasmSpike extends Plugin {
  onload() {
    this.addCommand({ id: 'run', name: 'Run the WebAssembly write-back', callback: () => this.run() });
  }

  async run() {
    const { WASI } = require('wasi');
    const here = path.join(this.app.vault.adapter.getBasePath(), this.manifest.dir);
    const config = JSON.parse(fs.readFileSync(path.join(here, 'config.json'), 'utf8'));
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
};
