// Runs a project's JavaScript Components for Raindown, which starts it with node -e, after services.js, since inside
// Raindown's package the script is where NodeJS can't read it. Each line on stdin is a request, answered by one line
// of JSON on stdout:
//   { op: 'load', folder }                     → { nodes: [{ name, render, rasterize, file }] }
//   { op: 'new', id, name, args, props }       → {}
//   { op: 'call', id, method, context, root }  → { value }
// A request that throws is answered with { error }. A node asking for one of Raindown's services meanwhile writes
// { service, root, args, asked }, which Raindown answers on stdin with { answer, value } or { answer, error }.
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { createInterface } from 'node:readline'
import { pathToFileURL } from 'node:url'

// stdout carries the replies, so what nodes log goes to stderr.
console.log = console.info = console.error

const classes = {}
const files = {}
const nodes = {}
const waiting = new Map()
let asks = 0

// A service, asked of Raindown on stdout, and answered on stdin.
function ask(root, service, args) {
  const asked = ++asks
  process.stdout.write(`${JSON.stringify({ service, root, args, asked })}\n`)
  return new Promise((resolve, reject) => waiting.set(asked, { resolve, reject }))
}

const requests = {
  // Every exported class with rewrite is a node, named by its export, or by its class for a default export.
  async load({ folder }) {
    for (const file of readdirSync(folder).filter((file) => /\.m?js$/.test(file))) {
      const exports = await import(pathToFileURL(join(folder, file)).href)

      for (const [name, value] of Object.entries(exports)) {
        if (typeof value?.prototype?.rewrite !== 'function') continue
        const nodeName = name === 'default' ? value.name : name
        classes[nodeName] = value
        files[nodeName] = file
      }
    }

    const nodes = Object.entries(classes).map(([name, node]) => ({
      name,
      render: typeof node.prototype.render === 'function',
      rasterize: typeof node.prototype.rasterize === 'function',
      file: files[name]
    }))
    return { nodes }
  },

  new({ id, name, args, props }) {
    nodes[id] = new classes[name](props, ...args)
    return {}
  },

  async call({ id, method, context, root }) {
    return { value: await nodes[id][method]({ ...context, raindown: raindownServices(root, ask) }) }
  },
}

async function answer(request) {
  try {
    process.stdout.write(`${JSON.stringify(await requests[request.op](request))}\n`)
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ error: String(error?.message ?? error) })}\n`)
  }
}

// A line's a service's answer, or a request, which isn't waited for, so its services' answers can be read meanwhile.
createInterface({ input: process.stdin }).on('line', (line) => {
  const message = JSON.parse(line)
  if (!('answer' in message)) return answer(message)

  const { resolve, reject } = waiting.get(message.answer)
  waiting.delete(message.answer)
  if ('error' in message) reject(new Error(message.error))
  else resolve(message.value)
})
