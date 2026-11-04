# frozen_string_literal: true

require_relative 'front_matter'
require_relative 'node'
require_relative 'variables'

module Raindown
  # Markdown Components, the .md and .rd files in a project's .raindown folder named like a component, like BookCard.md,
  # which write their Markdown with their props as variables, so they need no code:
  #   ---                          BookCard: title: Dune rating: 5
  #   rating: 0
  #   ---
  #   **{title}** {rating}/5
  # Its front matter is its props' defaults, and a value before its props, like Dune in BookCard: Dune, is {value}.
  # Its template is read each time it's written, so changing it changes the next render.
  module MarkdownNodes
    EXTENSIONS = %w[.md .rd].freeze
    NAME = /\A[A-Z]\w*\z/

    module_function

    def load(folder)
      Dir.glob(EXTENSIONS.map { "*#{it}" }, base: folder).each do |file|
        name = File.basename(file, '.*')
        node_classes[name] ||= MarkdownNode.for(name:, path: File.join(folder, file)) if name.match?(NAME)
      end
    end

    # Whether a file is a Markdown Component, by its extension and name, so .raindown/data/blueprints.md isn't one.
    def file?(path)
      EXTENSIONS.include?(File.extname(path)) && File.basename(path, '.*').match?(NAME)
    end

    def node_class(name)
      node_classes[name]
    end

    def node_classes
      @node_classes ||= {}
    end
  end

  # A Markdown Component, made with its props, which writes its template's Markdown.
  class MarkdownNode < Node
    def self.for(name:, path:)
      Class.new(self) do
        define_singleton_method(:name) { name }
        define_singleton_method(:path) { path }
      end
    end

    def initialize(value = nil, **props)
      super()
      @props = props
      @props = { value:, **props } unless value.nil?
    end

    # Braces that the template pass hid, in its code or its props' values, are written back as braces.
    # The template pass loads here, as it loads nodes itself.
    def replace(metadata: NoMetadata, bare: false)
      require_relative 'pre_renderer'
      defaults, template = FrontMatter.parse(File.read(self.class.path))
      markdown = PreRenderer.render(template, variables: Variables.new(defaults.merge(@props)), metadata:, bare:)
      Variables.unwrap(markdown.sub(/\A(?:[ \t]*\n)+/, '').rstrip)
    end
  end
end
