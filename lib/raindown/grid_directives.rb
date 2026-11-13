# frozen_string_literal: true

module Raindown
  # A grid: row's cells that start with a node's directive, other than a grid, one of Raindown's own, like chart:, or
  # the project's, like a JavaScript Component, which run as anywhere else, writing their output into the cell's lines
  # below them, taking the cell's blank lines at its end, so the row stays as tall as it was if they're enough.
  module GridDirectives
    DIRECTIVE = /\A([A-Za-z][\w-]*):(?=\s|\z)/

    module_function

    # The row with each of its cells' directives run, as tall as it was unless one's output needs more lines than its
    # cell has, for the file's metadata, so a project's node has its services.
    def run(row, metadata: NoMetadata)
      cells = Array.new(row.map(&:size).max) { |column| row.map { it[column].to_s } }
      cells = cells.map { written(it, metadata) }
      Array.new(cells.map(&:size).max) { |line| cells.map { it[line].to_s } }
    end

    # The columns of the row's cells that start with a directive, whose lines are kept as they're wrapped.
    def columns(row)
      row.first.to_a.each_index.select { |column| directive?(row.first[column].to_s) }
    end

    def written(lines, metadata)
      return lines unless directive?(lines.first.to_s)

      require_relative 'node_injector'
      written = NodeInjector.rewrite(content: "#{lines.join("\n")}\n", bare: true, metadata:).lines.map(&:chomp)
      written.pop while written.size > lines.size && written.last == ''
      written + Array.new([lines.size - written.size, 0].max, '')
    end

    # Whether a cell's first line is a node's directive, but a grid's, and not one that only looks like one, like a
    # note's "Note: hi".
    def directive?(line)
      name = line[DIRECTIVE, 1]
      return false if name.nil? || name == 'grid'

      !Nodes.node_class(name).nil?
    end
  end
end
