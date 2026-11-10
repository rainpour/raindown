# frozen_string_literal: true

require_relative 'chart/chart'
require_relative 'fragments'
require_relative 'grid'
require_relative 'image'
require_relative 'js/js_nodes'
require_relative 'list'
require_relative 'markdown_nodes'
require_relative 'node'
require_relative 'problem'
require_relative 'stat'
require_relative 'table/table'
require_relative 'toc/toc'

module Raindown
  # Nodes are LowNodes that a node block writes into the Markdown and renders into the HTML.
  # A project keeps them in a .raindown folder, which is loaded with Dirload, beside its JavaScript and Markdown
  # Components, if any.
  # Bare or in comments, a node writes back: its Markdown, from #rewrite, is written into the file, and its HTML is from
  # #render if it has one. In <{ }> it's write-in: it only renders, with #render, which takes the Markdown between its
  # tags as slot:, in HTML. Either can take the keywords document: (the Markdown being rendered), metadata:, bare: and
  # written: (the lines it wrote last time), and gets the ones it asks for.
  module Nodes
    # A write-in node that has no render.
    class NoRender < StandardError; end

    FOLDER = '.raindown'
    # Lowercase directives for Raindown's own nodes. A project's own TOC, List, Chart, Table, Image or Grid node
    # replaces Raindown's.
    BUILT_INS = { 'toc' => 'TOC', 'list' => 'List', 'chart' => 'Chart', 'table' => 'Table', 'image' => 'Image',
                  'grid' => 'Grid' }.freeze
    # A placeholder for a node's HTML, which stays as it is through Commonmarker and Antlers, with its slot's HTML, as a
    # fragment, when it has one.
    PLACEHOLDER = /<!-- raindown:node (\d+)(?: slot (\d+))? -->/

    module_function

    # Loads the .raindown folder beside the file or in the nearest directory above it, once per process.
    def load(path)
      folder = find_folder(File.dirname(File.expand_path(path)))
      return if folder.nil? || loaded.include?(folder)

      require 'lownode'
      require 'dirload'
      loaded << folder
      dirload(folder)
      JSNodes.load(folder)
      MarkdownNodes.load(folder)
    end

    def find_folder(directory)
      loop do
        folder = File.join(directory, FOLDER)
        return folder if File.directory?(folder)

        parent = File.dirname(directory)
        return if parent == directory

        directory = parent
      end
    end

    def loaded
      @loaded ||= []
    end

    # The node class a block names, when it's loaded.
    def node_class(name)
      return loaded_class(name) unless BUILT_INS.key?(name)

      loaded_class(BUILT_INS[name]) || Raindown.const_get(BUILT_INS[name])
    end

    # A Ruby node of the name, or else a JavaScript one, or else a Markdown one.
    def loaded_class(name)
      klass = Object.const_get(name) if name.match?(/\A[A-Z]/) && Object.const_defined?(name)
      return klass if node?(klass)

      JSNodes.node_class(name) || MarkdownNodes.node_class(name)
    end

    # A LowNode, or one of Raindown's own nodes, that writes Markdown. In an app, LowNodes are also routes and pages,
    # which don't have rewrite, so text like "Note:" only starts a block when the Note node writes something.
    def node?(klass)
      return false unless klass.is_a?(Class) && klass.method_defined?(:rewrite)

      klass < Node || (defined?(::LowNode) && klass < ::LowNode) || false
    end

    # Calls a node's rewrite or render with the context keywords it takes.
    def call(node, name, **context)
      parameters = node.method(name).parameters
      return node.public_send(name, **context) if parameters.any? { |type, _| type == :keyrest }

      keys = parameters.filter_map { |type, key| key if %i[key keyreq].include?(type) }
      node.public_send(name, **context.slice(*keys))
    end

    # One instance for each node and its props, kept for the whole process.
    # So a node can keep what its Markdown and HTML share, like a date, and both stay the same between renders.
    def instance(klass, props, args = [])
      key = [klass, args, props]
      instances[key] ||= begin
        id = list.length
        list << klass.new(*args, **props)
        id
      end

      list[instances[key]]
    end

    # Renders the node where it is, as a fragment, so its headings are part of the page, or through a placeholder, once
    # the page is HTML, when its render takes html:, the page's HTML, like TOC's.
    def rendered(node, context, slot: '', **keywords)
      raise NoRender, "#{node.class.name} has no render, so it can't be write-in: write it bare or in comments" unless renders?(node)
      return placeholder(node, slot:) if !template?(node.class) && takes?(node, :render, :html)

      Fragments.add(html(node, context, slot:, **keywords))
    end

    def takes?(node, method_name, keyword)
      node.method(method_name).parameters.any? { |_, name| name == keyword }
    end

    # Whether the node's class has a template, like a Raindeer .rbx component, which renders in place of render.
    def template?(klass)
      klass.respond_to?(:template) && !klass.template.nil?
    end

    def placeholder(node, slot: '')
      return "<!-- raindown:node #{list.index(node)} -->" if slot.empty?

      "<!-- raindown:node #{list.index(node)} slot #{Fragments.store(slot)} -->"
    end

    # Swaps each placeholder for its node's HTML, given the page's HTML and its slot, the HTML between its tags in <{ }>,
    # which can hold components' fragments.
    def render_placeholders(page_html, context)
      page_html.gsub(PLACEHOLDER) do
        match = ::Regexp.last_match
        slot = match[2] ? Fragments.list[match[2].to_i] : ''
        Fragments.fill(html(list[match[1].to_i], context, slot:, html: page_html))
      end
    end

    # Rendering Markdown, a node's written as it would be written back.
    def html(node, context, **keywords)
      return node.render_template(props: {}).to_s if template?(node.class)
      return call(node, :rewrite, **context.to_h, **keywords).to_s if !Raindown.commonmark? && node.respond_to?(:rewrite)

      call(node, :render, **context.to_h, **keywords).to_s
    end

    # Whether the node renders its own HTML rather than the HTML of its Markdown, which Raindown's nodes render by default.
    def html?(node)
      return true if template?(node.class)

      node.respond_to?(:render) && node.method(:render).owner != Node
    end

    # Whether the node renders at all, so it can be write-in, in <{ }>.
    def renders?(node)
      node.respond_to?(:render) || html?(node)
    end

    def instances
      @instances ||= {}
    end

    def list
      @list ||= []
    end
  end
end
