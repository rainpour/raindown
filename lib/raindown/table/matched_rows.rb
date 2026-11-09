# frozen_string_literal: true

module Raindown
  # Which of a file's rows each of a table's rows shows, by index, given whether a table row shows a file row, so a row
  # added or removed doesn't move the rows after it onto others. Rows that are the same in both are matched, in order,
  # then those left between them are paired in order, like a row that's been edited.
  class MatchedRows
    def initialize(rows, file_rows, &same)
      @rows = rows
      @file_rows = file_rows
      @same = same
    end

    # Each table row's file row, or nil for a row that's new.
    def file_rows
      [].tap do |matched|
        [[-1, -1], *common_rows, [@rows, @file_rows]].each_cons(2) do |(row, file_row), (next_row, next_file_row)|
          matched[row] = file_row unless row.negative?
          (row + 1...next_row).zip(file_row + 1...next_file_row) { |gap_row, gap_file_row| matched[gap_row] = gap_file_row }
        end
      end
    end

    private

    # The longest run of rows, in order, the same in both, as pairs of their indexes. Rows the same at the start and
    # end are matched first, so only the few between them, being edited, are compared each with each.
    def common_rows
      head = matching_run((0...@rows).zip(0...@file_rows))
      rows, file_rows = [@rows, @file_rows].map { (head.length...it).to_a }
      tail = matching_run(rows.reverse.zip(file_rows.reverse)).reverse
      rows, file_rows = [rows, file_rows].map { it.take(it.length - tail.length) }
      [*head, *common_pairs(rows, file_rows, common_lengths(rows, file_rows)), *tail]
    end

    def matching_run(pairs)
      pairs.take_while { |row, file_row| file_row && @same.call(row, file_row) }
    end

    # How many rows, at most, the rows and file rows from each on have in common.
    def common_lengths(rows, file_rows)
      rows.reverse.each_with_object([Array.new(file_rows.length + 1, 0)]) do |row, lengths|
        lengths.unshift(common_lengths_from(row, file_rows, lengths.first))
      end
    end

    # The common lengths from the row, from those from the row below it.
    def common_lengths_from(row, file_rows, below)
      file_rows.each_index.reverse_each.with_object(Array.new(file_rows.length + 1, 0)) do |j, lengths|
        lengths[j] = @same.call(row, file_rows[j]) ? below[j + 1] + 1 : [below[j], lengths[j + 1]].max
      end
    end

    def common_pairs(rows, file_rows, lengths)
      i = j = 0
      pairs = []
      while i < rows.length && j < file_rows.length
        if @same.call(rows[i], file_rows[j])
          pairs << [rows[i], file_rows[j]]
          i += 1
          j += 1
        elsif lengths[i + 1][j] >= lengths[i][j + 1]
          i += 1
        else
          j += 1
        end
      end
      pairs
    end
  end
end
