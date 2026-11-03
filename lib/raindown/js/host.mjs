// Runs a project's JavaScript Components for Raindown, which starts it with node -e, since inside Raindown's package
// the script is where NodeJS can't read it. Each line on stdin is a request, answered by one line of JSON on stdout:
//   { op: 'load', folder }                → { nodes: [{ name, render }] }
//   { op: 'new', id, name, args, props }  → {}
//   { op: 'call', id, method, context }   → { value }
// A request that throws is answered with { error }.
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { createInterface } from 'node:readline'
import { pathToFileURL } from 'node:url'

// stdout carries the replies, so what nodes log goes to stderr.
console.log = console.info = console.error

const classes = {}
const nodes = {}

const requests = {
  // Every exported class with replace is a node, named by its export, or by its class for a default export.
  async load({ folder }) {
    for (const file of readdirSync(folder).filter((file) => /\.m?js$/.test(file))) {
      const exports = await import(pathToFileURL(join(folder, file)).href)

      for (const [name, value] of Object.entries(exports)) {
        if (typeof value?.prototype?.replace === 'function') classes[name === 'default' ? value.name : name] = value
      }
    }

    const nodes = Object.entries(classes).map(([name, node]) => ({ name, render: typeof node.prototype.render === 'function' }))
    return { nodes }
  },

  new({ id, name, args, props }) {
    nodes[id] = new classes[name](props, ...args)
    return {}
  },

  async call({ id, method, context }) {
    return { value: await nodes[id][method](context) }
  },
}

for await (const line of createInterface({ input: process.stdin })) {
  const request = JSON.parse(line)

  try {
    process.stdout.write(`${JSON.stringify(await requests[request.op](request))}\n`)
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ error: String(error?.message ?? error) })}\n`)
  }
}
