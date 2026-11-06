# frozen_string_literal: true

module Raindown
  # Formula cells in a table's rows, like =SUM(B), by its column's letter, or =sum(Price), by its header, worked out
  # as spreadsheets do: the numbers in the column's other rows below the header, leaving out other formulas. Any other
  # formula, or one naming no column, like one still being typed, is left as it's written.
  module TableFormulas
    NUMBER = /\A-?\d+(?:\.\d+)?\z/
    SUM = /\A=SUM\(\s*([^)]+?)\s*\)\z/i

    module_function

    def evaluate(rows)
      header, *body = rows
      return rows unless header

      [header, *body.map { |row| row.map { sum_formula(it, header, body) || it } }]
    end

    def formula?(cell)
      cell.to_s.match?(SUM)
    end

    # The sum of the numbers, to the most decimal places any of them has.
    def sum(numbers)
      places = numbers.map { it[/\.(\d+)/, 1].to_s.length }.max.to_i
      total = numbers.sum { Rational(it) }
      return total.round.to_s if places.zero?

      format("%.#{places}f", total)
    end

    def sum_formula(cell, header, body)
      column_ref = cell[SUM, 1]
      return unless column_ref

      column = header.index { it.casecmp?(column_ref) } || column_index(column_ref)
      return unless column && column < header.length

      sum(body.map { it[column].to_s }.select { it.match?(NUMBER) })
    end

    # A column's letters as its index, like B as 1 and AA as 26, or nil when they aren't letters.
    def column_index(letters)
      return unless letters.match?(/\A[A-Z]{1,3}\z/i)

      letters.upcase.chars.reduce(0) { |index, letter| (index * 26) + letter.ord - 64 } - 1
    end
  end
end
