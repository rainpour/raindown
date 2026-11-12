// QuickJS's side of a project's JavaScript Components, which QuickJSHost runs after services.js, answering the same
// requests as any host, as JSON, through __raindown.request. QuickJSHost imports each file of a folder, registering its
// exports, then asks to load them. A service is asked of Ruby through __raindownService, which it defines.
globalThis.__raindown = (() => {
  const classes = {}
  const fileOf = {}
  const exportsOf = {}
  const nodes = {}
  const ask = async (root, name, args) => JSON.parse(__raindownService(root, name, JSON.stringify(args)))

  const requests = {
    // Every exported class with rewrite in the files is a node, named by its export, or by its class for a default one.
    load({ files }) {
      const loaded = []
      for (const file of files) {
        for (const [name, value] of Object.entries(exportsOf[file] ?? {})) {
          if (typeof value?.prototype?.rewrite !== 'function') continue
          const nodeName = name === 'default' ? value.name : name
          classes[nodeName] = value
          fileOf[nodeName] = file.split('/').at(-1)
          loaded.push(nodeName)
        }
      }
      const described = loaded.map((name) => ({
        name,
        render: typeof classes[name].prototype.render === 'function',
        rasterize: typeof classes[name].prototype.rasterize === 'function',
        file: fileOf[name]
      }))
      return { nodes: described }
    },

    new({ id, name, args, props }) {
      nodes[id] = new classes[name](props, ...args)
      return {}
    },

    async call({ id, method, context, root }) {
      return { value: await nodes[id][method]({ ...context, raindown: raindownServices(root, ask) }) }
    }
  }

  return {
    register(file, exports) {
      exportsOf[file] = exports
    },

    async request(json) {
      const message = JSON.parse(json)
      try {
        return JSON.stringify(await requests[message.op](message))
      } catch (error) {
        return JSON.stringify({ error: String(error?.message ?? error) })
      }
    }
  }
})()
