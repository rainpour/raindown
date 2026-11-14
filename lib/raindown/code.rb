# frozen_string_literal: true

require_relative 'code_blocks'

module Raindown
  # Finds code in Markdown the way Commonmarker reads it: code spans and fenced, indented or quoted code blocks.
  module Code
    # A code span on one line, like `{x}`, between runs of the same number of backticks, from the run it opens with.
    SPAN = /\G(`+)(?!`).+?(?<!`)\1(?!`)/n
    NOT_BACKTICK = /[^`]/n

    module_function

    # Byte ranges of code in the Markdown, from Commonmarker's line and column positions, or rendering Markdown, which
    # doesn't load Commonmarker, its fenced blocks and code spans.
    def ranges(markdown)
      return scanned_ranges(markdown) unless Raindown.commonmark?

      offsets = line_offsets(markdown.lines)
      ranges = []

      Raindown.parse_markdown(markdown).walk do |node|
        ranges << range(node.source_position, offsets) if %i[code code_block].include?(node.type)
      end

      ranges
    end

    # The byte offset each line starts at, and the end's.
    def line_offsets(lines)
      lines.reduce([0]) { |offsets, line| offsets << (offsets.last + line.bytesize) }
    end

    def scanned_ranges(markdown)
      lines = markdown.lines
      offsets = line_offsets(lines)
      ranges = []
      index = 0
      while index < lines.length
        if (block = CodeBlocks.at(lines, index))
          ranges << (offsets[index]...offsets[block[:close] + 1])
          index = block[:close]
        else
          ranges.concat(span_ranges(lines[index], offsets[index]))
        end
        index += 1
      end
      ranges
    end

    # The line's spans, each matched from its next run of backticks, which byteindex finds without a regex, so the
    # text between spans is never scanned, and nor is a line without a backtick, as most are. A run that opens no span
    # is passed over whole.
    def span_ranges(line, start)
      bytes = line.b
      ranges = []
      from = 0
      while (open = bytes.byteindex('`', from))
        from = SPAN.match(bytes, open)&.end(0)
        ranges << ((start + open)...(start + from)) if from
        from ||= bytes.byteindex(NOT_BACKTICK, open) || break
      end
      ranges
    end

    def range(position, line_offsets)
      start = line_offsets[position[:start_line] - 1] + position[:start_column] - 1
      # A block that ends with its last line ends at column 0 of the line after.
      finish = line_offsets[position[:end_line] - 1] + position[:end_column]
      start...finish
    end

    # Swaps braces in code for the placeholders that render as braces, so Antlers leaves them alone.
    def hide_braces(markdown)
      ranges(markdown).reverse.each_with_object(markdown.b) do |range, bytes|
        bytes[range] = bytes[range].force_encoding('UTF-8').gsub(/[{}]/, CODE_BRACES).b
      end.force_encoding('UTF-8')
    end
  end
end
