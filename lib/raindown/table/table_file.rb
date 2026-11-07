# frozen_string_literal: true

require 'csv'

module Raindown
  # The CSV or TSV file behind a table:, as rows of cells as wide as each other, written back in its own format.
  module TableFile
    SEPARATORS = { '.csv' => ',', '.tsv' => "\t" }.freeze
    BYTE_ORDER_MARK = "\uFEFF"

    module_function

    def supported?(path)
      SEPARATORS.key?(File.extname(path).downcase)
    end

    def read(path)
      rows = CSV.read(path, col_sep: separator(path), skip_blanks: true, encoding: 'bom|utf-8')
      width = rows.map(&:length).max.to_i
      rows.map { |row| Array.new(width) { row[it].to_s.strip } }
    end

    # Keeps the file's line endings and any byte order mark, like Excel's.
    def write(path, rows)
      text = File.binread(path).force_encoding(Encoding::UTF_8)
      options = { col_sep: separator(path), row_sep: text[/\r?\n/] || "\n" }
      lines = rows.map { CSV.generate_line(without_empty_cells(it), **options) }
      File.binwrite(path, [(BYTE_ORDER_MARK if text.start_with?(BYTE_ORDER_MARK)), *lines].join)
      rows
    end

    def separator(path)
      SEPARATORS[File.extname(path).downcase]
    end

    # Empty cells as nil, which CSV leaves empty rather than quoting, but for a row of one, as it would be a blank line.
    def without_empty_cells(row)
      return row if row.one?

      row.map { it unless it.empty? }
    end
  end
end
