# frozen_string_literal: true

require 'json'
require 'open3'

require_relative '../node'
require_relative '../scene'

module Raindown
  # JavaScript Components, the .js and .mjs files in a project's .raindown folder, which export classes with rewrite and
  # optionally render, like Ruby nodes. They run in a NodeJS process of Raindown's own, started when a folder has them,
  # so only projects with JavaScript Components need NodeJS.
  module JSNodes
    EXTENSIONS = %w[.js .mjs].freeze
    SCRIPT = File.join(__dir__, 'host.mjs')

    class Error < StandardError; end

    # The NodeJS process running the nodes, which answers each request with a line of JSON. NodeJS can't read the script
    # inside Raindown's package, so it's passed to node -e.
    class Host
      def initialize
        @input, @output, = Open3.popen2('node', '--input-type=module', '-e', File.read(SCRIPT))
      rescue Errno::ENOENT
        raise Error, 'JavaScript Components need NodeJS 22 or later on your PATH'
      end

      def request(**message)
        @input.puts(JSON.generate(message))
        reply = JSON.parse(@output.gets || raise(Error, 'NodeJS stopped running the JavaScript Components'))
        raise Error, reply['error'] if reply['error']

        reply
      end
    end

    class << self
      # A host in place of NodeJS, answering the same requests, like the Obsidian plugin's worker, which runs them itself.
      attr_writer :host
    end

    module_function

    # Loads the JavaScript Components in a .raindown folder, starting NodeJS the first time a folder has any.
    def load(folder)
      return if Dir.glob(EXTENSIONS.map { "*#{it}" }, base: folder).empty?

      host.request(op: 'load', folder:).fetch('nodes').each do |node|
        file = node['file'] && File.join(folder, node['file'])
        node_classes[node['name']] ||= JSNode.for(name: node['name'], render: node['render'], rasterize: node['rasterize'], file:)
      end
    end

    def node_class(name)
      node_classes[name]
    end

    # The names of the folder's JavaScript Components that rasterize.
    def rasterizing(folder)
      node_classes.select { |_, node| node.method_defined?(:rasterize) && File.dirname(node.file) == folder }.keys
    end

    def host
      @host ||= Host.new
    end

    def node_classes
      @node_classes ||= {}
    end
  end

  # A JavaScript Component, made in the NodeJS process with its props, where its rewrite and render are sent.
  class JSNode < Node
    # A class for each JavaScript Component, from its file, which renders its own HTML when the component has render,
    # and rasterizes when it has rasterize.
    def self.for(name:, render:, rasterize: false, file: nil)
      Class.new(self) do
        define_singleton_method(:name) { name }
        define_singleton_method(:file) { file }
        define_method(:render) { |**context| js_output(:render, context) } if render
        define_method(:rasterize) { |**| scene } if rasterize && file
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
    # with its file's source, read again each time, so a change shows, and its value and props, to make it with.
    def scene
      Scene.new(name: 'node', data: { node: self.class.name, source: File.read(self.class.file), args: @args, props: @props })
    end

    def js_output(method, context)
      JSNodes.host.request(op: 'call', id: object_id, method:, context: json_context(**context)).fetch('value').to_s
    end

    # JSON can't hold Pages, so the metadata is its root and each file's front matter and path.
    def json_context(metadata: NoMetadata, **context)
      root = metadata.root if metadata.respond_to?(:root)
      { **context, metadata: { root:, files: metadata.list.map(&:metadata) } }
    end
  end
end
