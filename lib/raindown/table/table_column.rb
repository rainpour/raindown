# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  # A table's column: its alignment, from its delimiter cell's colons, and its width, that of its widest cell, or as wide
  # as its delimiter when that's equals signs, like |====|, which is fixed.
  TableColumn = Data.define(:delimiter, :width) do
    # The columns of the delimiter's cells, while it has one for each of the rows' columns.
    def self.all(delimiter, rows)
      return [] unless delimiter&.length == rows.first&.length

      delimiter.each_with_index.map { |cell, i| from(cell, rows.map { it[i].to_s }) }
    end

    # The rows with each cell clipped to fit its fixed column, but for those revealed, which are wrapped to fit it as
    # lines instead, but for the header's, as + rows can only be below the delimiter.
    def self.fit(rows, columns, revealed)
      rows.each_with_index.map do |row, row_index|
        row.each_with_index.map do |cell, column|
          next cell unless columns[column]&.fixed?
          next columns[column].clip(cell) unless revealed.include?([row_index, column])
          next cell if row_index.zero?

          columns[column].wrap(cell)
        end
      end
    end

    def self.from(delimiter, cells)
      return new(delimiter:, width: delimiter.length) if delimiter.include?('=')

      new(delimiter:, width: [*cells.map { display_width(it) }, 3].max)
    end

    # Wide characters like CJK and emoji take two columns. Emoji are always measured as two,
    # instead of guessing from the terminal, so a file formats the same on every machine.
    def self.display_width(cell)
      Unicode::DisplayWidth.of(cell, emoji: :all)
    end

    def fixed?
      delimiter.include?('=')
    end

    def alignment
      if delimiter.start_with?(':') && delimiter.end_with?(':') then :center
      elsif delimiter.end_with?(':') then :right
      elsif delimiter.start_with?(':') then :left
      end
    end

    def delimiter_cell
      case alignment
      when :center then ":#{dashes * (width - 2)}:"
      when :right then "#{dashes * (width - 1)}:"
      when :left then ":#{dashes * (width - 1)}"
      else dashes * width
      end
    end

    def pad(cell)
      padding = [width - TableColumn.display_width(cell), 0].max

      case alignment
      when :center then "#{' ' * (padding / 2)}#{cell}#{' ' * (padding - (padding / 2))}"
      when :right then "#{' ' * padding}#{cell}"
      else "#{cell}#{' ' * padding}"
      end
    end

    # The cell cut to fit a fixed column, ending in an ellipsis, or as it is when it fits.
    def clip(cell)
      return cell unless fixed? && TableColumn.display_width(cell) > width

      kept = cell.grapheme_clusters.each_with_object(+'') do |grapheme, text|
        break text if TableColumn.display_width(text + grapheme) > width - 1

        text << grapheme
      end
      "#{kept.rstrip}…"
    end

    # The cell's words as lines that fit the column, each as many as fit, and a word longer than it on a line of its own.
    def wrap(cell)
      cell.split(' ').each_with_object([]) do |word, lines|
        next lines.last << " #{word}" if lines.any? && TableColumn.display_width("#{lines.last} #{word}") <= width

        lines << +word
      end
    end

    private

    def dashes
      return '=' if fixed?

      '-'
    end
  end
end
