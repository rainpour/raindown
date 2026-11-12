# frozen_string_literal: true

module Raindown
  # A grid: row's cells that start with one of Raindown's own content directives, other than a grid, like painting:,
  # which run as anywhere else, writing their output into the cell's lines below them, taking the cell's blank lines at
  # its end, so the row stays as tall as it was if they're enough.
  module GridDirectives
    module_function

    # The row with each of its cells' directives run, as tall as it was unless one's output needs more lines than its
    # cell has.
    def run(row)
      cells = Array.new(row.map(&:size).max) { |column| row.map { it[column].to_s } }
      cells = cells.map { written(it) }
      Array.new(cells.map(&:size).max) { |line| cells.map { it[line].to_s } }
    end

    # The columns of the row's cells that start with a directive, whose lines are kept as they're wrapped.
    def columns(row)
      row.first.to_a.each_index.select { |column| row.first[column].to_s.match?(directive) }
    end

    def written(lines)
      return lines unless lines.first&.match?(directive)

      require_relative 'node_injector'
      written = NodeInjector.rewrite(content: "#{lines.join("\n")}\n", bare: true).lines.map(&:chomp)
      written.pop while written.size > lines.size && written.last == ''
      written + Array.new([lines.size - written.size, 0].max, '')
    end

    def directive
      names = Nodes::BUILT_INS.keys - ['grid']
      /\A(?:#{names.map { Regexp.escape(it) }.join('|')}):(?=\s|\z)/
    end
  end
end
