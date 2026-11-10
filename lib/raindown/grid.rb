# frozen_string_literal: true

require 'unicode/display_width'
require_relative 'node'

module Raindown
  # The node behind grid:, a frame of cells in text, like a page of photos, which editors that draw images in text fill
  # with the image in each cell:
  #   grid: width: 40
  #   +-------------------+------------------+
  #   | ![cat](cat.png)   | ![dog](dog.png)  |
  #   |                   |                  |
  #   +-------------------+------------------+
  # It's written from itself, as it's edited: each | added to a row's line adds a cell to that row, each line added
  # between its rules makes the row taller, and each row's cells are shared equally across its width, in characters.
  class Grid < Node
    RULE = /\A\s*\+[-+]*\+?\s*\z/
    # A reference definition, like [cat]: pictures/cat.png, which an image like ![cat] in a cell takes its path from.
    DEFINITION = /\A {0,3}\[[^\]]+\]:\s*\S/
    NEW_GRID = [Array.new(3) { ['', ''] }].freeze

    def initialize(width: 60)
      @width = width.to_i
      super()
    end

    def rewrite(written: [])
      rows = rows_of(written)
      widths = rows.map { |row| cell_widths(row.map(&:size).max) }
      lines = [rule(widths.first)]
      rows.each_with_index do |row, index|
        row.each { |cells| lines << row_line(cells, widths[index]) }
        lines << rule(widths[index], widths[index + 1])
      end
      lines.join("\n")
    end

    # Each row as a grid of its cells, its cells' Markdown rendered, with the note's reference definitions, so a cell's
    # image can be by reference, like ![cat], its path on a line of its own below the grid, like [cat]: cat.png.
    def render(written: [], document: '')
      definitions = document.lines.grep(DEFINITION).join
      rows_of(written).map do |row|
        columns = row.map(&:size).max
        cells = Array.new(columns) { |column| row.map { it[column].to_s }.join("\n").strip }
        html_cells = cells.map { "<div>#{Raindown.commonmark("#{it}\n\n#{definitions}")}</div>" }.join
        %(<div class="raindown-grid" style="display: grid; grid-template-columns: repeat(#{columns}, 1fr)">#{html_cells}</div>)
      end.join
    end

    private

    # The rows between its rules, each line of each as its cells' text, or a new grid when it has none.
    def rows_of(written)
      lines = written.map(&:chomp).reject { it.strip.empty? }
      rows = lines.chunk_while { |line, following| !RULE.match?(line) && !RULE.match?(following) }
                  .reject { RULE.match?(it.first) }
                  .map { |row| row.map { cells_of(it) } }
      rows.empty? ? NEW_GRID : rows
    end

    def cells_of(line)
      inner = line.strip.delete_prefix('|').delete_suffix('|')
      inner.split('|', -1).map(&:strip)
    end

    # The widths of a row's cells, inside their borders, sharing the grid's width, the first ones a character wider when
    # it doesn't share evenly.
    def cell_widths(count)
      base, extra = [@width - count - 1, count].max.divmod(count)
      Array.new(count) { |index| base + (index < extra ? 1 : 0) }
    end

    # Each cell padded to its width as it shows, so a wide character, like an emoji, takes the two it does.
    def row_line(cells, widths)
      padded = widths.each_with_index.map do |width, index|
        text = " #{cells[index]}"
        text + (' ' * [width - Unicode::DisplayWidth.of(text, emoji: :all), 0].max)
      end
      "|#{padded.join('|')}|"
    end

    # A rule, with a + at each edge of the cells of the rows above and below it.
    def rule(above, below = nil)
      edges = [above, below].compact.flat_map { edges_of(it) }.uniq
      line = '-' * (edges.max + 1)
      edges.each { line[it] = '+' }
      line
    end

    def edges_of(widths)
      widths.reduce([0]) { |edges, width| edges << (edges.last + width + 1) }
    end
  end
end
