# frozen_string_literal: true

require 'unicode/display_width'
require_relative 'node'
require_relative 'grid_wrapping'

module Raindown
  # The node behind grid:, a frame of cells in text, like a page of photos, which editors that draw images in text fill
  # with the image in each cell:
  #   grid: width: 40
  #   +-------------------+------------------+
  #   | ![cat](cat.png)   | ![dog](dog.png)  |
  #   |                   |                  |
  #   +-------------------+------------------+
  # It's written from itself, as it's edited: each | added to a row's line adds a cell to that row, each line added
  # between its rules makes the row taller, and each row's cells share its width, in characters, equally, a cell's text
  # wrapping onto the row's next lines. With cell: :fit, a cell whose text needs more grows into the room the others
  # don't need instead, and widens the grid when there's none.
  class Grid < Node
    RULE = /\A\s*\+[-+]*\+?\s*\z/
    # A reference definition, like [cat]: pictures/cat.png, which an image like ![cat] in a cell takes its path from.
    DEFINITION = /\A {0,3}\[[^\]]+\]:\s*\S/
    NEW_GRID = [Array.new(3) { ['', ''] }].freeze

    def initialize(width: 60, cell: nil)
      @width = width.to_i
      @fit = cell.to_s.delete_prefix(':') == 'fit'
      super()
    end

    def rewrite(written: [])
      rows = rows_of(written)
      widths = widths_of(rows)
      lines = [rule(widths.first)]
      rows.each_with_index do |row, index|
        row = GridWrapping.wrapped(row, widths[index]) unless @fit
        row.each { |cells| lines << row_line(cells, widths[index]) }
        lines << rule(widths[index], widths[index + 1])
      end
      lines.join("\n")
    end

    # Each row as a grid of its cells, sharing its width as the text does, its cells' Markdown rendered, with the note's
    # reference definitions, so a cell's image can be by reference, like ![cat], its path on a line of its own below the
    # grid, like [cat]: cat.png.
    def render(written: [], document: '')
      definitions = document.lines.grep(DEFINITION).join
      rows = rows_of(written)
      rows.zip(widths_of(rows)).map { |row, widths| row_html(row, widths, definitions) }.join
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

    # Each row's cells' widths, inside their borders, as wide as the grid, or as the widest row's cells need.
    def widths_of(rows)
      needs = rows.map { needs_of(it) }
      inner = [@width, *needs.map { it.sum + it.size + 1 }].max
      needs.map { |row| cell_widths(row, inner - row.size - 1) }
    end

    # The width each of a row's cells needs, inside its borders, for its text and a space either side of it, as it
    # shows, so a wide character, like an emoji, takes the two it does, or none, unless cells fit their text.
    def needs_of(row)
      Array.new(row.map(&:size).max) do |column|
        next 0 unless @fit

        row.map { Unicode::DisplayWidth.of(" #{it[column]} ", emoji: :all) }.max
      end
    end

    # The widths of a row's cells, inside their borders, sharing its room equally, but for those whose text needs more,
    # which take what it needs.
    def cell_widths(needs, room, grown = [])
      shared = needs.each_index.to_a - grown
      shares = shares_of(shared, room - needs.values_at(*grown).sum)
      more = shared.select { needs[it] > shares[it] }
      return cell_widths(needs, room, grown + more) if more.any?

      needs.each_index.map { shares[it] || needs[it] }
    end

    # Room shared equally among cells, by their indexes, the first a character wider when it doesn't share evenly.
    def shares_of(indexes, room)
      base, extra = [room, indexes.size].max.divmod([indexes.size, 1].max)
      indexes.each_with_index.to_h { |index, at| [index, base + (at < extra ? 1 : 0)] }
    end

    def row_html(row, widths, definitions)
      cells = widths.each_index.map { |column| row.map { it[column].to_s }.join("\n").strip }
      html_cells = cells.map { "<div>#{Raindown.commonmark("#{it}\n\n#{definitions}")}</div>" }.join
      columns = widths.map { "minmax(0, #{it}fr)" }.join(' ')
      %(<div class="raindown-grid" style="display: grid; grid-template-columns: #{columns}">#{html_cells}</div>)
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
