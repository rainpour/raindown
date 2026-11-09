# frozen_string_literal: true

require 'unicode/display_width'

require_relative 'markdown_table'
require_relative 'matched_rows'
require_relative 'table_formulas'

module Raindown
  # A table: block's table as it was written, its cells padded as they were, against its file's rows. Each of its rows
  # is matched to the file's row it shows, so a row added or removed above a formula doesn't move it onto another. A
  # formula cell shows its formula, so it can be edited, when its value's padding was deleted, no longer the width of
  # its column's header, and keeps showing it, until it's changed from the file's, ignoring whitespace.
  class WrittenTable
    def initialize(padded_rows, file)
      @padded_rows = padded_rows
      @file = file
      @values = TableFormulas.evaluate(file)
    end

    # Its rows, as wide as each other, each formula still shown as it's saved being its value, as they're compared with the file's.
    def rows
      each_cell { |cell, row, column| same_formula?(cell, file_cell(row, column)) ? value(row, column) : cell }
    end

    # Its rows to write to the file, keeping the file's cell where the table still shows it, like a formula as its
    # value, or a cell with line breaks on one line.
    def saved_rows
      rows.each_with_index.map do |cells, row|
        cells.each_with_index.map do |cell, column|
          next file_cell(row, column) if file_cell(row, column) && MarkdownTable.one_line(value(row, column).to_s) == cell

          cell
        end
      end
    end

    # The row and column of each cell to show as its formula.
    def revealed
      cells.each_with_index.flat_map do |row, row_index|
        row.each_index.select { reveal?(row_index, it) }.map { [row_index, it] }
      end
    end

    private

    def cells
      @cells ||= @padded_rows.map { |row| Array.new(width_in_cells) { MarkdownTable.cell(row[it].to_s) } }
    end

    def each_cell
      cells.each_with_index.map { |row, row_index| row.each_with_index.map { |cell, column| yield cell, row_index, column } }
    end

    # As wide as its widest row, as its file's rows are read, so a row still being typed reads the same in both.
    def width_in_cells
      @padded_rows.map(&:length).max
    end

    def file_cell(row, column)
      file_rows[row]&.then { @file.dig(it, column) }
    end

    def value(row, column)
      file_rows[row]&.then { @values.dig(it, column) }
    end

    # The index of each of its rows' file row, or nil for a row that's new.
    def file_rows
      @file_rows ||= MatchedRows.new(cells.length, @file.length) { |row, file_row| same_row?(row, file_row) }.file_rows
    end

    # Whether the table's row shows the file's row: each cell its value, or its formula.
    def same_row?(row, file_row)
      cells[row].each_with_index.all? do |cell, column|
        cell == @values.dig(file_row, column).to_s || same_formula?(cell, @file.dig(file_row, column))
      end
    end

    def reveal?(row, column)
      formula = file_cell(row, column)
      return false unless TableFormulas.formula?(formula)

      cell = cells[row][column]
      same_formula?(cell, formula) || (cell == value(row, column) && squeezed?(row, column))
    end

    def same_formula?(cell, formula)
      TableFormulas.formula?(formula) && cell.gsub(/\s+/, '') == formula.gsub(/\s+/, '')
    end

    def squeezed?(row, column)
      width(@padded_rows[row][column]) != width(@padded_rows.first[column])
    end

    def width(padded)
      Unicode::DisplayWidth.of(padded.to_s, emoji: :all)
    end
  end
end
