# frozen_string_literal: true

require 'digest'
require 'json'

require_relative '../node'
require_relative '../utils'
require_relative '../written'
require_relative 'markdown_table'
require_relative 'table_column'
require_relative 'table_file'
require_relative 'table_formulas'
require_relative 'written_table'

module Raindown
  # The node behind table:, a CSV or TSV file relative to the project as a Markdown table, after a comment of how many
  # rows it has and a hash of them, as they were when the table and the file last matched:
  #   table: 'data/team.csv'
  #   <!-- 2 rows · 3f2a9c -->
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
    # The hash in its comment, like 3f2a9c in "2 rows · 3f2a9c".
    HASH = /· (\h+)\z/
    BOLD = /\A\*\*.*\*\*\z/
    # The table a new file starts with, when there's no table to make it from.
    STARTER = [['Column 1', 'Column 2'], ['', '']].freeze

    def initialize(data = nil, total: false)
      @data = data
      @total = total
    end

    # Written is what it wrote last time, so it can tell which of the table and the file changed since. A file that's
    # not there yet is made, from the table below it, or else one to fill in.
    def rewrite(written: [], metadata: NoMetadata, comment: nil)
      path = data_path(metadata)
      lines = written.map(&:chomp)
      create_file(path, lines) if missing_file?(path, metadata)
      data_error(path, metadata)&.then { Problem.alert(it) } || synced(path, lines, comment)
    end

    # Write-in, in <{ }>, the table only shows its file, and never writes to it.
    def render(metadata: NoMetadata)
      path = data_path(metadata)
      error = data_error(path, metadata)
      return Raindown.commonmark(Problem.alert(error)) if error

      Raindown.commonmark(MarkdownTable.format(with_total(TableFormulas.evaluate(TableFile.read(path)))))
    end

    private

    def data_path(metadata)
      File.expand_path(@data.to_s, data_root(metadata))
    end

    def data_root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end

    def missing_file?(path, metadata)
      TableFile.supported?(path) && Utils.inside?(path, data_root(metadata)) && !File.exist?(path)
    end

    # From the table as it's written.
    def create_file(path, lines)
      rows = MarkdownTable.parse(lines)
      rows = STARTER if rows.empty?
      TableFile.create(path, rows)
    end

    # Why the file can't be a table, or nil when it can.
    def data_error(path, metadata)
      return 'Needs a file path to a CSV/TSV that exists or will be created' if @data.to_s.strip.empty?
      return "#{@data.inspect} must be a file path to a CSV/TSV that exists or will be created" unless TableFile.supported?(path)
      return "Can't show #{@data.inspect} as a table: it's outside the project" unless Utils.inside?(path, data_root(metadata))

      "Can't show #{@data.inspect} as a table: no such file" unless File.file?(path)
    end

    def synced(path, written, comment)
      file = TableFile.read(path)
      shown = TableFormulas.evaluate(file)
      synced_hash = comment&.[](HASH, 1)
      table = WrittenTable.new(written_rows(written), file, MarkdownTable.delimiter(written))
      return markdown(file, table) if unchanged?(table.rows, synced_hash, shown)
      return markdown(TableFile.write(path, table.saved_rows), table) if hash_rows(shown) == synced_hash

      warn "raindown: #{@data} and its table both changed, so neither is written until they match"
      Written.new(written.join("\n"), comment: "conflict · #{synced_hash}")
    end

    # Whether there's nothing to write back: the table's rows are as it wrote them, or as the file's are, or it's new.
    def unchanged?(rows, synced_hash, shown)
      synced_hash.nil? || rows.empty? || [synced_hash, hash_rows(shown)].include?(hash_rows(rows))
    end

    # The table's rows as it was written, padding and all, leaving out its total.
    def written_rows(written)
      header, *body = MarkdownTable.padded_rows(written)
      [header, *body.reject { total_row?(it.map(&:strip)) }].compact
    end

    # Written with the delimiter it was written with, its cells fit to its fixed columns.
    def markdown(rows, written)
      return '' if rows.empty?

      shown = TableFormulas.evaluate(rows)
      count = rows.length - 1
      cells = with_total(with_revealed(shown, rows, written.revealed))
      columns = TableColumn.all(written.delimiter, rows)
      table = MarkdownTable.format(TableColumn.fit(cells, columns, written.revealed), written.delimiter)
      Written.new(table, comment: "#{count} row#{'s' unless count == 1} · #{hash_rows(shown)}")
    end

    # The values, but for each revealed cell, which shows its formula, or its full text.
    def with_revealed(values, rows, revealed)
      revealed.each_with_object(values.map(&:dup)) { |(row, column), shown| shown[row][column] = rows[row][column] }
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
