'use strict';

const childProcess = require('child_process');
const vscode = require('vscode');

const TIMEOUT = 10000;
const MAX_BUFFER = 32 * 1024 * 1024;

function command() {
  return vscode.workspace.getConfiguration('raindown').get('path') || 'raindown';
}

// "raindown FILE --stdin" renders the Markdown it's given without touching FILE, which only decides whether
// bare directives are allowed. --bare allows them for any document in the Raindown language, saved or not.
function args(filePath, { bare }) {
  return [filePath, '--stdin', ...(bare ? ['--bare'] : [])];
}

const OPTIONS = { timeout: TIMEOUT, maxBuffer: MAX_BUFFER };

function errorMessage(error, stderr) {
  if (error.code === 'ENOENT') {
    return `Couldn't run "${command()}". Install the raindown gem or a standalone binary, or set "raindown.path".`;
  }

  return (stderr && stderr.trim()) || error.message;
}

// "raindown server" keeps Raindown loaded, so a render doesn't start Ruby again each time, like the Obsidian plugin's.
// It starts when it's first asked something, and again after it stops. A Raindown without it, from before it, or one
// that doesn't start, isn't asked again, and requests answer null, for running Raindown once each instead.
class RaindownServer {
  constructor(command) {
    this.command = command;
    this.pending = new Map();
    this.nextId = 1;
  }

  // Resolves with Raindown's answer, like { output }, or null without a server, or rejects with its error.
  async request(message) {
    if (!await this.start()) return null;

    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        this.stop(); // Stuck, so the next request starts it again.
        reject(new Error(`Raindown didn't answer within ${TIMEOUT / 1000} seconds`));
      }, TIMEOUT);
      this.pending.set(id, { resolve, reject, timer });
      this.child.stdin.write(`${JSON.stringify({ id, ...message })}\n`);
    });
  }

  start() {
    if (this.unsupported) return Promise.resolve(false);

    this.starting ??= new Promise((ready) => {
      this.ready = false;
      const child = childProcess.spawn(this.command, ['server'], { stdio: 'pipe' });
      const unsupported = () => {
        this.unsupported = true;
        ready(false);
      };
      const timer = setTimeout(() => { unsupported(); child.kill(); }, TIMEOUT);
      let buffer = '';

      child.stdout.setEncoding('utf8').on('data', (chunk) => {
        buffer += chunk;
        for (let end = buffer.indexOf('\n'); end !== -1; end = buffer.indexOf('\n')) {
          this.receive(buffer.slice(0, end), () => { clearTimeout(timer); ready(true); });
          buffer = buffer.slice(end + 1);
        }
      });
      child.stdin.on('error', () => {}); // Its exit says why it stopped.
      child.on('error', () => { clearTimeout(timer); unsupported(); });
      child.on('exit', () => {
        clearTimeout(timer);
        if (this.child === child) Object.assign(this, { child: null, starting: null });
        this.pending.forEach(({ reject, timer: waiting }) => { clearTimeout(waiting); reject(new Error('Raindown stopped')); });
        this.pending.clear();
        if (!this.ready) unsupported(); // Stopping before it was ready means it can't serve.
      });
      this.child = child;
    });

    return this.starting;
  }

  receive(line, ready) {
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      return; // Not an answer.
    }
    if (message.ready) {
      this.ready = true;
      return ready();
    }

    const request = this.pending.get(message.id);
    if (!request) return;
    this.pending.delete(message.id);
    clearTimeout(request.timer);
    if (message.error) request.reject(new Error(message.error));
    else request.resolve(message);
  }

  stop() {
    this.child?.kill();
  }
}

let server = null;

// The server for the raindown.path set now, started again when it changes.
function serverFor() {
  if (server?.command !== command()) {
    server?.stop();
    server = new RaindownServer(command());
  }

  return server;
}

// Whether renders can go through the server now, without waiting, as the Markdown preview's can't.
function serving() {
  serverFor().start();
  return server.ready === true && !server.unsupported;
}

// For the Markdown preview, whose plugins render synchronously, so it can't wait for the server.
function renderSync(markdown, filePath, { bare = false } = {}) {
  try {
    return childProcess.execFileSync(command(), args(filePath, { bare }), {
      ...OPTIONS, input: markdown, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe']
    });
  } catch (error) {
    throw new Error(errorMessage(error, error.stderr && error.stderr.toString()));
  }
}

async function render(markdown, filePath, { bare = false } = {}) {
  const answer = await serverFor().request({ path: filePath, markdown, bare });
  if (answer) return answer.output;

  return new Promise((resolve, reject) => {
    const child = childProcess.execFile(command(), args(filePath, { bare }), OPTIONS, (error, stdout, stderr) => {
      error ? reject(new Error(errorMessage(error, stderr))) : resolve(stdout);
    });

    child.stdin.on('error', () => {}); // The exit callback reports why raindown stopped reading.
    child.stdin.end(markdown);
  });
}

function stop() {
  server?.stop();
}

module.exports = { render, renderSync, serving, stop };
