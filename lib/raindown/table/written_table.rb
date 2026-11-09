# frozen_string_literal: true

require 'unicode/display_width'

require_relative 'file_cell'
require_relative 'markdown_table'
require_relative 'matched_rows'
require_relative 'table_column'

module Raindown
  # A table: block's table as it was written, its cells padded as they were, against its file's cells, as its columns
  # show them. Each of its rows is matched to the file's row it shows, so a row added or removed above a formula
  # doesn't move it onto another. A formula's value is no longer lined up when its padding's deleted, the width of its
  # column's header.
  class WrittenTable
    # The delimiter's cells, like ':===', as it was written, or nil when it's not a table yet.
    attr_reader :delimiter

    def initialize(padded_rows, file, delimiter = nil)
      @padded_rows = padded_rows
      @file = file
      @values = TableFormulas.evaluate(file)
      @delimiter = delimiter
      @columns = TableColumn.all(delimiter, file)
    end

    # Its rows, as wide as each other, each formula still shown as it's saved being its value, as they're compared with the file's.
    def rows
      each_cell { |cell, row, column| file_cell(row, column)&.value_from(cell) || cell }
    end

    # Its rows to write to the file, keeping the file's cell where the table still shows it, like a formula as its
    # value, or a cell with line breaks on one line.
    def saved_rows
      rows.each_with_index.map do |cells, row|
        cells.each_with_index.map do |cell, column|
          kept = file_cell(row, column)
          next kept.saved if kept && MarkdownTable.one_line(kept.value) == cell

          cell
        end
      end
    end

    # The row and column of each cell typed into since it was written, which isn't clipped as it's saved, so what's
    # typed after it meanwhile isn't typed after an ellipsis, but the next time it's written.
    def typed
      cells.each_with_index.flat_map do |row, row_index|
        row.each_index.reject { file_cell(row_index, it)&.unchanged_by?(row[it]) }.map { [row_index, it] }
      end
    end

    # The row and column of each cell to show as its formula, or in full.
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
      file_rows[row]&.then { cell_in_file(it, column) }
    end

    def cell_in_file(file_row, column)
      saved = @file.dig(file_row, column)
      FileCell.new(saved:, value: @values.dig(file_row, column), column: @columns[column]) if saved
    end

    # The index of each of its rows' file row, or nil for a row that's new.
    def file_rows
      @file_rows ||= MatchedRows.new(cells.length, @file.length) { |row, file_row| same_row?(row, file_row) }.file_rows
    end

    # Whether the table's row shows the file's row, each cell unchanged, or blank where the file has none.
    def same_row?(row, file_row)
      cells[row].each_with_index.all? do |cell, column|
        cell_in_file(file_row, column)&.unchanged_by?(cell) || (cell.empty? && !@file.dig(file_row, column))
      end
    end

    def reveal?(row, column)
      padded = @padded_rows[row][column].to_s
      file_cell(row, column)&.revealed_by?(cells[row][column], squeezed: squeezed?(row, column), wrapped: padded.include?("\n"))
    end

    def squeezed?(row, column)
      width(@padded_rows[row][column]) != width(@padded_rows.first[column])
    end

    def width(padded)
      Unicode::DisplayWidth.of(padded.to_s, emoji: :all)
    end
  end
end
