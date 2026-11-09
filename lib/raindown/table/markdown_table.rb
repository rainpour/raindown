# frozen_string_literal: true

module Raindown
  # Rows of cells as a Markdown table, its first row the header, and back again. A | in a cell is escaped as \|, and
  # a line break is written as a space, as a table's cells are one line. A row starting with +, carrying on the row
  # above, is read as part of it. The TableFormatter lines up its columns.
  module MarkdownTable
    SEPARATOR = /\A\|?(\s*:?[-=]+:?\s*\|)*\s*:?[-=]+:?\s*\|?\z/
    # A | that isn't escaped.
    PIPE = /(?<!\\)\|/

    module_function

    # With the delimiter's cells, like ':===', when it has one for each column, keeping their alignment and widths. A
    # cell can be lines, wrapped onto + rows below its row.
    def format(rows, delimiter = nil)
      return '' if rows.empty?

      delimiter = Array.new(rows.first.length, '---') unless delimiter&.length == rows.first.length
      header, *body = rows.flat_map { row_lines(it) }
      [header, "|#{delimiter.join('|')}|", *body].join("\n")
    end

    def row_lines(row)
      lines = row.map { Array(it) }
      starts = ['|', *Array.new(lines.map(&:length).max - 1, '+')]
      starts.each_with_index.map { |start, line| "#{start} #{lines.map { escape(it[line].to_s) }.join(' | ')} |" }
    end

    # The cells of the table's delimiter row, like ['---', ':==='], or nil when the lines aren't a table.
    def delimiter(lines)
      return unless lines[1]&.strip&.match?(SEPARATOR)

      lines[1].strip.delete_prefix('|').delete_suffix('|').split('|').map(&:strip)
    end

    # The rows of the table in the lines, leaving out its separator, or none when they aren't a table.
    def parse(lines)
      padded_rows(lines).map { |row| row.map { cell(it) } }
    end

    # The rows of the table in the lines, their cells as written, padding and all, leaving out its separator, with each
    # + row's cells joined into the row above's, on lines of their own.
    def padded_rows(lines)
      return [] unless delimiter(lines)

      table_lines = [lines[0], *lines.drop(2)].map(&:strip).take_while { it.start_with?('|', '+') }
      table_lines.each_with_object([]) do |line, rows|
        cells = padded_cells(line)
        next rows << cells unless line.start_with?('+') && rows.any?

        rows[-1] = rows.last.zip(cells).map { |above, more| joined_cell(above, more.to_s) }
      end
    end

    # The line's cells, padding and all, without its outer pipes, or the + starting it.
    def padded_cells(line)
      line.delete_prefix(line[0]).delete_suffix('|').split(PIPE, -1)
    end

    # The cell carried on by the one below it, or as it was, padding and all, when that's blank.
    def joined_cell(above, more)
      return above if more.strip.empty?

      [above.strip, more.strip].reject(&:empty?).join("\n")
    end

    def cell(padded)
      one_line(padded.strip).gsub('\|', '|')
    end

    def escape(cell)
      one_line(cell).gsub('|', '\|')
    end

    # The cell as a table shows it, on one line.
    def one_line(cell)
      cell.gsub(/\s*\R\s*/, ' ')
    end
  end
end
