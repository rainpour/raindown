# frozen_string_literal: true

module Raindown
  # A grid: row's cells' text wrapped to their widths, unless they fit it.
  module GridWrapping
    module_function

    # The row with each cell's text wrapped at its spaces to its width: each paragraph, its lines up to a blank one,
    # written again from its words, the row taller when they need more lines, never shorter. A word longer than its cell,
    # like an image's path, runs on past it. The cells in kept, by their columns, keep their lines, like a directive's
    # and its output's, each wrapped on its own, taking blank lines at the cell's end for the lines that adds.
    def wrapped(row, widths, kept: [])
      columns = widths.each_with_index.map do |width, column|
        texts = row.map { it[column].to_s }
        kept.include?(column) ? kept_lines(texts, width - 2) : wrapped_lines(texts, width - 2)
      end
      Array.new([row.size, *columns.map(&:size)].max) { |line| columns.map { it[line] } }
    end

    def kept_lines(texts, width)
      lines = texts.flat_map { it.empty? ? [it] : lines_of(it, width) }
      lines.pop while lines.size > texts.size && lines.last.empty?
      lines
    end

    def wrapped_lines(texts, width)
      texts.chunk_while { |line, following| !line.empty? && !following.empty? }.flat_map do |lines|
        next lines if lines.first.empty?

        lines_of(lines.join(' '), width)
      end
    end

    # The text's lines, broken at the spaces after its words, each word keeping the spaces after it unless it ends a
    # line, so spaces typed between words, like one before another as a word's typed between two, are kept.
    def lines_of(text, width)
      text.scan(/\S+\s*/).each_with_object([+'']) do |word, lines|
        if lines.last.empty? || Unicode::DisplayWidth.of(lines.last + word.rstrip, emoji: :all) <= width
          lines.last << word
        else
          lines << +word
        end
      end.map(&:rstrip)
    end
  end
end
