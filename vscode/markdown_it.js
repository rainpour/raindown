'use strict';

const vscode = require('vscode');
const raindown = require('./raindown');

// Without the document the preview's parsing, which only bare directives depend on and Markdown files don't allow, any
// .md name renders the same. With it, the document's project's nodes and config are used too.
const FILE = 'preview.md';

// Each document's last Markdown and the HTML Raindown rendered from it.
const rendered = new Map();

let warned = false;

// Hands Markdown that has <{ }> directives to raindown, and replaces markdown-it's tokens with its HTML.
// Without directives, or if raindown fails, markdown-it renders the document as usual.
// The preview parses synchronously, so with Raindown's server running, it shows the document's last HTML while the
// server renders the new Markdown, then refreshes. Otherwise, as the first time, it waits for Raindown.
function plugin(md) {
  md.core.ruler.push('raindown', (state) => {
    if (!vscode.workspace.getConfiguration('raindown').get('markdownPreview') || !state.src.includes('<{')) return;

    const document = state.env?.currentDocument;
    const key = document?.toString() ?? FILE;
    const file = document?.fsPath || FILE;
    const last = rendered.get(key);
    let html = last?.html;

    try {
      if (last?.markdown === state.src) html = last.html;
      else if (last && raindown.serving()) renderLater(key, state.src, file);
      else rendered.set(key, { markdown: state.src, html: html = raindown.renderSync(state.src, file) });
    } catch (error) {
      warnOnce(error);
      return;
    }
    if (html == null) return;

    const token = new state.Token('html_block', '', 0);
    token.content = html;
    token.block = true;
    token.map = [0, state.src.split('\n').length];
    state.tokens = [token];
  });

  return md;
}

// Renders the Markdown through the server, then refreshes the preview, which finds it rendered.
async function renderLater(key, markdown, file) {
  try {
    rendered.set(key, { markdown, html: await raindown.render(markdown, file) });
    vscode.commands.executeCommand('markdown.preview.refresh');
  } catch (error) {
    warnOnce(error);
  }
}

// The preview re-parses as you type, so only the first failure is shown.
function warnOnce(error) {
  if (warned) return;

  warned = true;
  vscode.window.showWarningMessage(`Raindown: ${error.message} Showing the plain Markdown preview.`);
}

module.exports = { plugin };
