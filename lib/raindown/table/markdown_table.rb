# frozen_string_literal: true

module Raindown
  # Rows of cells as a Markdown table, its first row the header, and back again. A | in a cell is escaped as \|, and
  # a line break is written as a space, as a table's cells are one line. The TableFormatter lines up its columns.
  module MarkdownTable
    SEPARATOR = /\A\|?(\s*:?-+:?\s*\|)*\s*:?-+:?\s*\|?\z/
    # A | that isn't escaped.
    PIPE = /(?<!\\)\|/

    module_function

    def format(rows)
      return '' if rows.empty?

      header, *body = rows.map { |row| "| #{row.map { escape(it) }.join(' | ')} |" }
      [header, "|#{Array.new(rows.first.length, '---').join('|')}|", *body].join("\n")
    end

    # The rows of the table in the lines, leaving out its separator, or none when they aren't a table.
    def parse(lines)
      return [] unless lines[1]&.strip&.match?(SEPARATOR)

      [lines[0], *lines.drop(2)].take_while { it.strip.start_with?('|') }.map { cells(it.strip) }
    end

    def cells(line)
      line.delete_prefix('|').delete_suffix('|').split(PIPE, -1).map { it.strip.gsub('\|', '|') }
    end

    def escape(cell)
      cell.gsub('|', '\|').gsub(/\s*\R\s*/, ' ')
    end
  end
end
