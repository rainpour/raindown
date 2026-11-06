# frozen_string_literal: true

require 'unicode/display_width'

require_relative 'markdown_table'
require_relative 'table_formulas'

module Raindown
  # A table: block's table as it was written, its cells padded as they were, against its file's rows. A formula cell
  # shows its formula, so it can be edited, when its value's padding was deleted, no longer the width of its column's
  # header, and keeps showing it, until it's changed from the file's, ignoring whitespace.
  class WrittenTable
    def initialize(padded_rows, file)
      @padded_rows = padded_rows
      @file = file
      @values = TableFormulas.evaluate(file)
    end

    # Its rows, as wide as each other, each formula still shown as it's saved being its value, as they're compared with the file's.
    def rows
      cells.each_with_index.map do |row, row_index|
        row.each_with_index.map do |cell, column|
          next @values.dig(row_index, column) if same_formula?(cell, @file.dig(row_index, column))

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

    # As wide as its widest row, as its file's rows are read, so a row still being typed reads the same in both.
    def width_in_cells
      @padded_rows.map(&:length).max
    end

    def reveal?(row, column)
      formula = @file.dig(row, column)
      return false unless TableFormulas.formula?(formula)

      cell = cells[row][column]
      same_formula?(cell, formula) || (cell == @values.dig(row, column) && squeezed?(row, column))
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
