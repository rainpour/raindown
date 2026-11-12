// Raindown's services for a JavaScript node, as raindown in its methods' context, the same wherever it runs: in
// QuickJS in the terminal, an app's page, the Obsidian plugin or a phone. Each asks the host with ask(root, name, args), which
// answers with a promise, from Raindown::Services on the desktop, so they're all async, and a service a platform hasn't
// got rejects. A plain script, not a module, so each host can put it before its own code.
function raindownServices(root, ask) {
  const call = (name, ...args) => ask(root, name, args)

  return {
    root,
    // { status, headers, body, json() }, its body as text.
    fetch: async (url, { method, headers, body } = {}) => {
      const response = await call('fetch', url, { method, headers, body })
      return { ...response, json: () => JSON.parse(response.body) }
    },
    // The project's files, by their paths from its root, which they can't leave.
    files: {
      read: (path) => call('read', path),
      list: (pattern = '**/*') => call('list', pattern),
      write: (path, text) => call('write', path, text)
    },
    // Values JSON can hold, kept for the project, for so many seconds, or until they're kept again.
    cache: {
      get: (key) => call('cache_get', key),
      set: (key, value, { seconds } = {}) => call('cache_set', key, value, seconds ?? null)
    },
    // What git writes, run in the project, like git('branch', '--list'), where there's git.
    git: (...args) => call('git', ...args)
  }
}
