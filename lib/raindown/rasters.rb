# frozen_string_literal: true

require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'grid_directives'
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

    # The names of Raindown's own nodes that rasterize, like weather, and, for a file, its project's JavaScript
    # Components that do.
    def names(path = nil)
      built_in = Nodes::BUILT_INS.select { |_, name| Raindown.const_get(name).method_defined?(:rasterize) }.keys
      return built_in unless path

      Nodes.load(path)
      folder = Nodes.find_folder(File.dirname(File.expand_path(path)))
      return built_in unless folder

      built_in + JSNodes.rasterizing(folder)
    end

    # What the node whose directive's on the line, counted from 0, in the file shows behind its text, a Scene or a
    # Raster, for an app, and how it formats the characters of its lines, as { painting:, formatting: }, with options
    # like width: and height: for its rasterize. A node in a grid's cell is by the column its cell starts at, after its |.
    def repaint(path:, line:, column: nil, **options)
      Nodes.load(path)
      node = node_on(path, line, column)
      raise ArgumentError, "Nothing on line #{line + 1} of #{path} rasterizes" unless node

      metadata = Pages.for(path)
      { painting: node.rasterize(metadata:, **options).to_h, formatting: formatting(node, metadata) }
    end

    # The characters of a node's lines to dim, to embolden and to draw as large as a line is tall, as { quiet:, bold:,
    # large: }, each [line, from, to], its lines counted from the first it writes, from its formatting, or none.
    def formatting(node, metadata)
      return {} unless node.respond_to?(:formatting)

      node.formatting(metadata:)
    end

    # The node on the line, read with outdent blocks' lines without their <, as anywhere else, or in the grid cell at
    # the column.
    def node_on(path, line, column)
      content = Utils.read_markdown(path)
      lines = Outdent.without_markers(content).lines
      return cell_node(lines, line, column) if column

      bare = BareDirectives.enabled?(path:, content:)
      blocks = NodeBlocks.find(lines, front_matter: FrontMatter.parse(content).first, bare:)
      blocks.find { it[:open] == line && it[:node].respond_to?(:rasterize) }&.dig(:node)
    end

    # The node whose directive starts the grid cell at the column of the line, up to the cell's next |.
    def cell_node(lines, line, column)
      text = lines[line].to_s[column..].to_s.split('|').first.to_s.strip
      return unless GridDirectives.directive?(text)

      blocks = NodeBlocks.find(["#{text}\n"], bare: true)
      blocks.find { it[:node].respond_to?(:rasterize) }&.dig(:node)
    end
  end
end
