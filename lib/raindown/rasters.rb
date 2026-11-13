# frozen_string_literal: true

require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'grid_directives'
require_relative 'node_blocks'
require_relative 'nodes'
require_relative 'outdent'
require_relative 'pages/pages'
require_relative 'area'
require_relative 'scene'
require_relative 'utils'

module Raindown
  # The nodes that rasterize, painting pixels behind their text in an app that draws pixels, like weather:'s sky. An
  # app finds their blocks by name, then asks for each one's pixels by its directive's line.
  module Rasters
    module_function

    # The names of Raindown's own nodes that rasterize, like weather, and, for a file, its project's Ruby and JavaScript
    # Components that do.
    def names(path = nil)
      built_in = Nodes::BUILT_INS.select { |_, name| Raindown.const_get(name).method_defined?(:rasterize) }.keys
      return built_in unless path

      Nodes.load(path)
      folder = Nodes.find_folder(File.dirname(File.expand_path(path)))
      return built_in unless folder

      built_in + ruby_rasterizing(folder) + JSNodes.rasterizing(folder)
    end

    # The names of the Ruby nodes in a project's folder that rasterize, by where they're defined, so nothing else is
    # loaded to find them.
    def ruby_rasterizing(folder)
      Object.constants.filter_map do |name|
        file, = Object.const_source_location(name)
        next unless file&.start_with?("#{folder}/")

        klass = Object.const_get(name)
        name.to_s if Nodes.node?(klass) && klass.method_defined?(:rasterize)
      end.sort
    end

    # What the node whose directive's on the line, counted from 0, in the file shows behind its text, for an app, and
    # how it formats the characters of its lines, as { painting:, formatting: }, in an Area of the width and height,
    # in pixels, with where the text ends on each of its rows, and a character's width and height, as cell. A node in a
    # grid's cell is by the column its cell starts at, after its |.
    def repaint(path:, line:, column: nil, **space)
      Nodes.load(path)
      node = node_on(path, line, column)
      raise ArgumentError, "Nothing on line #{line + 1} of #{path} rasterizes" unless node

      metadata = Pages.for(path)
      area = Area.new(**space)
      { painting: painting_of(node, area, metadata), formatting: formatting(node, metadata) }
    end

    # What the node shows: a Scene, for one of an app's own painters to paint, like weather:'s valley, or else the area
    # it painted, painted again in the seconds it gave, if it did.
    def painting_of(node, area, metadata)
      painted = Nodes.call(node, :rasterize, area:, metadata:)
      return painted.to_h if painted.is_a?(Scene)

      again = painted if painted.is_a?(Numeric)
      area.to_h(again)
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
