# frozen_string_literal: true

require_relative 'table_column'

module Raindown
  # Pads every column of each Markdown table to the width of its widest cell, but for a column whose delimiter is
  # equals signs, like |====|, which is as wide as they are, letting a longer cell run past it. A row starting with +,
  # like "+ more | |", carries on the row above it, which Raindown joins into its cells when it renders.
  class TableFormatter
    DELIMITER_CELL = /\A:?[-=]+:?\z/
    FENCE = /\A\s*(```|~~~)/
    CONTINUATION = /\A\s*\+/

    def self.rewrite(content:, **)
      new(content:).format
    end

    # The Markdown as Commonmarker reads it: each table's equals signs as dashes, and its + rows joined into the row
    # above them, each cell carrying on with a space.
    def self.gfm(markdown)
      new(content: markdown).gfm
    end

    def initialize(content:)
      @lines = content.lines
    end

    def format
      replace_tables { align(it) }
    end

    def gfm
      replace_tables { gfm_table(it) }
    end

    private

    # The content with each table, outside code, replaced by the block's lines for it.
    def replace_tables
      output = []
      index = 0
      in_fence = false

      while index < @lines.length
        line = @lines[index]
        in_fence = !in_fence if line.match?(FENCE)

        if !in_fence && table_start?(index)
          table_end = find_table_end(index)
          output.concat(yield(@lines[index...table_end]))
          index = table_end
        else
          output << line
          index += 1
        end
      end

      output.join
    end

    # Split on pipes that aren't escaped, dropping the optional outer pipes, or the + starting a continuation row.
    def cells(line)
      content = line.strip
      content = content.delete_prefix(row_start(line))
      content = content.delete_suffix('|') unless content.end_with?('\|')

      content.split(/(?<!\\)\|/, -1).map(&:strip)
    end

    def row_start(line)
      return '+' if line.match?(CONTINUATION)

      '|'
    end

    def table_start?(index)
      header = @lines[index]
      delimiter = @lines[index + 1]
      return false unless header&.include?('|') && delimiter && !header.match?(CONTINUATION)

      delimiter_cells = cells(delimiter)
      delimiter_cells.any? && delimiter_cells.all? { |cell| cell.match?(DELIMITER_CELL) } &&
        delimiter_cells.length == cells(header).length
    end

    def find_table_end(index)
      table_end = index + 2
      table_end += 1 while @lines[table_end]&.include?('|') && !@lines[table_end].strip.empty?
      table_end
    end

    def gfm_table(table)
      header, delimiter, *body = table.map { |line| cells(line) }
      rows = joined_rows(table.drop(2), header, body)
      rows.insert(1, delimiter.map { it.tr('=', '-') }).map { "#{table.first[/\A\s*/]}| #{it.join(' | ')} |\n" }
    end

    # The rows, each with the + rows below it joined into its cells.
    def joined_rows(lines, header, body)
      lines.zip(body).each_with_object([header]) do |(line, row), joined|
        next joined << row unless line.match?(CONTINUATION)

        joined[-1] = joined.last.zip(row).map { |above, more| [above, more].reject { it.to_s.empty? }.join(' ') }
      end
    end

    def align(table)
      header, delimiter, *body = table.map { |line| cells(line) }
      return table if body.any? { |row| row.length > header.length }

      rows = [header, *body.map { |row| row + ([''] * (header.length - row.length)) }]
      aligned_lines(table, rows, TableColumn.all(delimiter, rows))
    end

    def aligned_lines(table, rows, columns)
      indent = table.first[/\A\s*/]
      lines = rows.zip(table.values_at(0, 2...table.length)).map do |row, line|
        row_line(indent, line, columns.zip(row).map { |column, cell| column.pad(cell) })
      end
      lines.insert(1, row_line(indent, table[1], columns.map(&:delimiter_cell)))
    end

    # The row's line, starting with + when it carries on the row above, as the line it was did.
    def row_line(indent, line, cells)
      "#{indent}#{row_start(line)} #{cells.join(' | ')} |\n"
    end
  end
end
