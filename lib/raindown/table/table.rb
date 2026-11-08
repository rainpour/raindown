# frozen_string_literal: true

require 'digest'
require 'json'

require_relative '../node'
require_relative '../utils'
require_relative 'markdown_table'
require_relative 'table_file'
require_relative 'table_formulas'
require_relative 'written_table'

module Raindown
  # The node behind table:, a CSV or TSV file relative to the project as a Markdown table, after a comment of how many
  # rows it has and a hash of them, as they were when the table and the file last matched:
  #   table: 'data/team.csv'
  #   <!-- table 2 rows · 3f2a9c -->
  #   | name | role     |
  #   |------|----------|
  #   | Ada  | engineer |
  #   | Lin  | design   |
  # Edit the table and its rows are written back to the file, or edit the file and the table's written again. When
  # both changed, neither is, and the table's comment says so until they match again. With total: true, a bold row
  # below the table sums its columns of numbers, which is worked out each time and never written to the file. Formula
  # cells in the file, like =SUM(B), show their values, and keep their formulas while their values are left alone. Delete
  # the padding around one's value and it shows its formula, to edit, until it's changed.
  class Table < Node
    COMMENT = /\A<!-- table (?:conflict|\d+ rows?) · (\h+) -->\z/
    BOLD = /\A\*\*.*\*\*\z/

    def initialize(data, total: false)
      @data = data
      @total = total
    end

    # Written is what it wrote last time, so it can tell which of the table and the file changed since.
    def rewrite(written: [], metadata: NoMetadata)
      path = data_path(metadata)
      data_error(path, metadata) || synced(path, written.map(&:chomp))
    end

    # Write-in, in <{ }>, the table only shows its file, and never writes to it.
    def render(metadata: NoMetadata)
      path = data_path(metadata)
      Raindown.commonmark(data_error(path, metadata) || MarkdownTable.format(with_total(TableFormulas.evaluate(TableFile.read(path)))))
    end

    private

    def data_path(metadata)
      File.expand_path(@data.to_s, data_root(metadata))
    end

    def data_root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end

    # Why the file can't be a table, or nil when it can.
    def data_error(path, metadata)
      return "Can't show #{@data.inspect} as a table: only CSV and TSV files can be" unless TableFile.supported?(path)
      return "Can't show #{@data.inspect} as a table: it's outside the project" unless Utils.inside?(path, data_root(metadata))

      "Can't show #{@data.inspect} as a table: no such file" unless File.file?(path)
    end

    def synced(path, written)
      file = TableFile.read(path)
      shown = TableFormulas.evaluate(file)
      synced_hash = written.first&.[](COMMENT, 1)
      table = WrittenTable.new(written_rows(written), file)
      return markdown(file, table.revealed) if unchanged?(table.rows, synced_hash, shown)
      return markdown(TableFile.write(path, with_file_cells(table.rows, file, shown)), table.revealed) if hash_rows(shown) == synced_hash

      warn "raindown: #{@data} and its table both changed, so neither is written until they match"
      ["<!-- table conflict · #{synced_hash} -->", *written.drop(1)].join("\n")
    end

    # Whether there's nothing to write back: the table's rows are as it wrote them, or as the file's are, or it's new.
    def unchanged?(rows, synced_hash, shown)
      synced_hash.nil? || rows.empty? || [synced_hash, hash_rows(shown)].include?(hash_rows(rows))
    end

    # The table's rows as it was written, padding and all, leaving out its total.
    def written_rows(written)
      header, *body = MarkdownTable.padded_rows(written.drop(1))
      [header, *body.reject { total_row?(it.map(&:strip)) }].compact
    end

    def markdown(rows, revealed = [])
      return '' if rows.empty?

      shown = TableFormulas.evaluate(rows)
      count = rows.length - 1
      table = MarkdownTable.format(with_total(with_revealed(shown, rows, revealed)))
      "<!-- table #{count} row#{'s' unless count == 1} · #{hash_rows(shown)} -->\n#{table}"
    end

    # The values, but for each revealed cell, which shows its formula.
    def with_revealed(values, rows, revealed)
      revealed.each_with_object(values.map(&:dup)) { |(row, column), shown| shown[row][column] = rows[row][column] }
    end

    # The table's rows, keeping the file's cell where the table still shows it, like a formula as its value, or a cell
    # with line breaks on one line.
    def with_file_cells(table, file, shown)
      table.each_with_index.map do |row, row_index|
        row.each_with_index.map do |cell, column|
          kept = file.dig(row_index, column)
          next kept if kept && MarkdownTable.one_line(shown.dig(row_index, column).to_s) == cell

          cell
        end
      end
    end

    def with_total(rows)
      return rows unless @total && rows.length > 1

      body = rows.drop(1)
      sums = rows.first.each_index.map { |column| sum_cells(body.map { it[column].to_s }) }
      sums[0] ||= 'Total'
      [*rows, sums.map { bold_cell(it) }]
    end

    # The sum of cells that are all numbers, or blank, to the most decimal places any has, or nil when they aren't.
    def sum_cells(cells)
      numbers = cells.reject(&:empty?)
      return if numbers.empty? || !numbers.all? { it.match?(TableFormulas::NUMBER) }

      TableFormulas.sum(numbers)
    end

    def bold_cell(text)
      return '' unless text

      "**#{text}**"
    end

    # The total row it wrote, its cells bold or blank, which isn't one of the file's rows.
    def total_row?(row)
      row.any? { !it.empty? } && row.all? { it.empty? || it.match?(BOLD) }
    end

    # As the table shows them, so a cell with line breaks hashes the same in both.
    def hash_rows(rows)
      Digest::SHA256.hexdigest(JSON.generate(rows.map { |row| row.map { MarkdownTable.one_line(it.to_s) } }))[0, 6]
    end
  end
end
