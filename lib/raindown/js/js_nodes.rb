# frozen_string_literal: true

require 'json'

require_relative '../node'
require_relative '../scene'
require_relative '../services'

module Raindown
  # JavaScript Components, the .js and .mjs files in a project's .raindown folder, which export classes with rewrite and
  # optionally render, like Ruby nodes. They run in QuickJS, inside Raindown, so they need nothing installed, or in a
  # host of an app's own, like its page. Wherever they run, they get Raindown's services as raindown in their context.
  # A host answers requests, which JSON can hold, with request(**message):
  #   { op: 'load', folder }                     → { nodes: [{ name, render, rasterize, file }], errors: [{ file, error }] }
  #   { op: 'new', id, name, args, props }       → {}
  #   { op: 'call', id, method, context, root }  → { value }
  # and raises an Error for a request that fails.
  module JSNodes
    EXTENSIONS = %w[.js .mjs].freeze
    # Raindown's services for JavaScript nodes, which every host runs before its own script, like an app's page.
    SERVICES = File.join(__dir__, 'services.js')

    class Error < StandardError; end

    class << self
      # A host of an app's own, answering the same requests, like the Obsidian plugin's worker or the desktop app's page.
      attr_writer :host
    end

    module_function

    # Loads the JavaScript Components in a .raindown folder, starting their host the first time a folder has any, and
    # gives why any file couldn't be loaded, like ".raindown/sky.mjs: SyntaxError: …", or why none could, when the host
    # couldn't load them, so the folder's other nodes still load.
    def load(folder)
      return [] if Dir.glob(EXTENSIONS.map { "*#{it}" }, base: folder).empty?

      reply = host.request(op: 'load', folder:)
      reply.fetch('nodes').each { add(folder, it) }
      reply.fetch('errors', []).map { "#{Nodes::FOLDER}/#{it['file']}: #{it['error']}" }
    rescue Error => e
      ["#{Nodes::FOLDER}: #{e.message}"]
    end

    # A node as the host described it, unless one of its name is already loaded.
    def add(folder, node)
      file = node['file'] && File.join(folder, node['file'])
      node_classes[node['name']] ||= JSNode.for(name: node['name'], render: node['render'], rasterize: node['rasterize'], file:)
    end

    def node_class(name)
      node_classes[name]
    end

    # The names of the folder's JavaScript Components that rasterize.
    def rasterizing(folder)
      node_classes.select { |_, node| node.method_defined?(:rasterize) && File.dirname(node.file) == folder }.keys
    end

    # QuickJS, unless an app gives its own. QuickJS is native, so it's only loaded here, not where an app gives its
    # own host, like WebAssembly in the Obsidian plugin, and isn't installed on Windows, where it doesn't build.
    def host
      @host ||= begin
        require_relative 'quickjs_host'
        QuickJSHost.new
      end
    rescue LoadError
      raise Error, "JavaScript Components need the quickjs gem, which doesn't build on Windows"
    end

    def node_classes
      @node_classes ||= {}
    end
  end

  # A JavaScript Component, made in its host with its props, where its rewrite and render are sent.
  class JSNode < Node
    # A class for each JavaScript Component, from its file, which renders its own HTML when the component has render,
    # and rasterizes when it has rasterize.
    def self.for(name:, render:, rasterize: false, file: nil)
      Class.new(self) do
        define_singleton_method(:name) { name }
        define_singleton_method(:file) { file }
        define_method(:render) { |**context| js_output(:render, context) } if render
        define_method(:rasterize) { |metadata: NoMetadata, **| scene(metadata) } if rasterize && file
      end
    end

    def initialize(*args, **props)
      super()
      @args = args
      @props = props
      JSNodes.host.request(op: 'new', id: object_id, name: self.class.name, args:, props:)
    end

    def rewrite(**context)
      js_output(:rewrite, context)
    end

    private

    # What it shows behind its text, which an app paints by running its rasterize itself, every frame: the node scene,
    # with its file's source, read again each time, so a change shows, its value and props, to make it with, and its
    # project's root, for the services the app gives it as raindown.
    def scene(metadata)
      data = { node: self.class.name, source: File.read(self.class.file), args: @args, props: @props, root: Services.for(metadata).root }
      Scene.new(name: 'node', data:)
    end

    # Its output, with the project's root for its services, which its host gives it as raindown.
    def js_output(method, context)
      root = Services.for(context[:metadata]).root
      JSNodes.host.request(op: 'call', id: object_id, method:, root:, context: json_context(**context)).fetch('value').to_s
    end

    # JSON can't hold Pages, so the metadata is its root and each file's front matter and path, nor the services, which
    # its host makes again.
    def json_context(metadata: NoMetadata, **context)
      root = metadata.root if metadata.respond_to?(:root)
      { **context.except(:raindown), metadata: { root:, files: metadata.list.map(&:metadata) } }
    end
  end
end
