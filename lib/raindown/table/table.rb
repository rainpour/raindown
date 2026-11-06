# frozen_string_literal: true

require 'csv'
require 'digest'
require 'json'

require_relative '../node'
require_relative 'markdown_table'

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
  # both changed, neither is, and the table's comment says so until they match again.
  class Table < Node
    COMMENT = /\A<!-- table (?:conflict|\d+ rows?) · (\h+) -->\z/
    SEPARATORS = { '.csv' => ',', '.tsv' => "\t" }.freeze

    def initialize(data)
      @data = data
    end

    # Written is what it wrote last time, so it can tell which of the table and the file changed since.
    def rewrite(written: [], metadata: NoMetadata)
      path = data_path(metadata)
      data_error(path) || synced(path, written.map(&:chomp))
    end

    # Write-in, in <{ }>, the table only shows its file, and never writes to it.
    def render(metadata: NoMetadata)
      path = data_path(metadata)
      Raindown.commonmark(data_error(path) || MarkdownTable.format(read_rows(path)))
    end

    private

    def data_path(metadata)
      File.expand_path(@data.to_s, metadata.respond_to?(:root) ? metadata.root : Dir.pwd)
    end

    # Why the file can't be a table, or nil when it can.
    def data_error(path)
      return "Can't show #{@data.inspect} as a table: only CSV and TSV files can be" unless SEPARATORS.key?(File.extname(path).downcase)

      "Can't show #{@data.inspect} as a table: no such file" unless File.file?(path)
    end

    def synced(path, written)
      file = read_rows(path)
      synced_hash = written.first&.[](COMMENT, 1)
      table = MarkdownTable.parse(written.drop(1))
      return markdown(file) if synced_hash.nil? || table.empty? || [synced_hash, hash_rows(file)].include?(hash_rows(table))
      return markdown(write_rows(path, table)) if hash_rows(file) == synced_hash

      warn "raindown: #{@data} and its table both changed, so neither is written until they match"
      ["<!-- table conflict · #{synced_hash} -->", *written.drop(1)].join("\n")
    end

    def markdown(rows)
      return '' if rows.empty?

      count = rows.length - 1
      "<!-- table #{count} row#{'s' unless count == 1} · #{hash_rows(rows)} -->\n#{MarkdownTable.format(rows)}"
    end

    def read_rows(path)
      rows = CSV.read(path, col_sep: SEPARATORS[File.extname(path).downcase], skip_blanks: true, encoding: Encoding::UTF_8)
      width = rows.map(&:length).max.to_i
      rows.map { |row| Array.new(width) { row[it].to_s.strip } }
    end

    def write_rows(path, rows)
      File.write(path, rows.map { CSV.generate_line(it, col_sep: SEPARATORS[File.extname(path).downcase]) }.join)
      rows
    end

    def hash_rows(rows)
      Digest::SHA256.hexdigest(JSON.generate(rows))[0, 6]
    end
  end
end
