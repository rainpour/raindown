# frozen_string_literal: true

require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'node_blocks'
require_relative 'nodes'
require_relative 'outdent'
require_relative 'pages/pages'
require_relative 'raster'
require_relative 'scene'
require_relative 'utils'

module Raindown
  # The nodes that rasterize, painting pixels behind their text in an app that draws pixels, like weather:'s sky. An
  # app finds their blocks by name, then asks for each one's pixels by its directive's line.
  module Rasters
    module_function

    # The names of Raindown's own nodes that rasterize, like weather.
    def names
      Nodes::BUILT_INS.select { |_, name| Raindown.const_get(name).method_defined?(:rasterize) }.keys
    end

    # What the node whose directive's on the line, counted from 0, in the file shows behind its text, a Scene or a
    # Raster, for an app, and the characters of its lines to dim, to embolden and to draw as large as a line is tall,
    # as { painting:, quiet:, bold:, large: }, with options like width: and height: for its rasterize.
    def rasterize(path:, line:, **options)
      Nodes.load(path)
      node = node_on(path, line)
      raise ArgumentError, "Nothing on line #{line + 1} of #{path} rasterizes" unless node

      metadata = Pages.for(path)
      { painting: node.rasterize(metadata:, **options).to_h, **%i[quiet bold large].to_h { [it, spans(node, it, metadata)] } }
    end

    # The spans a node gives for its lines, like the ones to dim, or none.
    def spans(node, name, metadata)
      return [] unless node.respond_to?(name)

      node.public_send(name, metadata:)
    end

    # The node on the line, read with outdent blocks' lines without their <, as anywhere else.
    def node_on(path, line)
      content = Utils.read_markdown(path)
      bare = BareDirectives.enabled?(path:, content:)
      blocks = NodeBlocks.find(Outdent.without_markers(content).lines, front_matter: FrontMatter.parse(content).first, bare:)
      blocks.find { it[:open] == line && it[:node].respond_to?(:rasterize) }&.dig(:node)
    end
  end
end
