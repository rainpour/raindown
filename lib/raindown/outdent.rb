# frozen_string_literal: true

require_relative 'code_blocks'

module Raindown
  # A block that reaches the page's top and left edges, framed by a rule of ^ above it and a < before each of its lines:
  #   ^^^^^^^^^^^^^^^^^^^^
  #   < weather:
  #   <   main -> fix
  # Its lines are written back and rendered without their <, so directives work in it as anywhere else, then it's put
  # back. In HTML it's a <div class="outdent">, which a page's styles take to its edges.
  module Outdent
    RULE = /\A\^{3,}[ \t]*\r?\n?\z/
    LINE = /\A</
    HTML = "<div class=\"outdent\">\n"

    module_function

    # Each block outside code, as { rule:, first:, last: }, its rule's line and its first and last lines.
    def blocks(lines)
      found = []
      index = 0
      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close] + 1
        elsif lines[index].match?(RULE) && lines[index + 1]&.match?(LINE)
          found << block_at(lines, index)
          index = found.last[:last] + 1
        else
          index += 1
        end
      end
      found
    end

    def block_at(lines, rule)
      last = rule + 1
      last += 1 while lines[last + 1]&.match?(LINE)
      { rule:, first: rule + 1, last: }
    end

    # The content with each block's lines written by the block, which is given the file with that block's lines
    # without their <, so they're at their lines in the file, and the range of them, which only it may change.
    def rewrite(content, &)
      lines = content.lines
      blocks(lines).reverse_each { |block| lines[block[:first]..block[:last]] = written_block(lines, block, &) }
      lines.join
    end

    # The block's lines as the block given writes them, each with its < again.
    def written_block(lines, block)
      given = with_block_unwrapped(lines, block)
      written = yield(given.join, block[:first]..block[:last]).lines
      last = block[:last] + written.length - given.length
      outer_lines(written[block[:first]..last], ends_file: !lines[block[:last]].end_with?("\n"))
    end

    # A blank line after the block's lines ends a bare block in it with it, as the line after it is outside it.
    def with_block_unwrapped(lines, block)
      [*lines[0...block[:first]], *inner_lines(lines[block[:first]..block[:last]]), "\n", *lines[(block[:last] + 1)..]]
    end

    # The content with every block's lines without their <, at the same lines, so what's in them is read as anywhere
    # else, like by Document.
    def without_markers(content)
      lines = content.lines
      blocks(lines).each { |block| lines[block[:first]..block[:last]] = inner_lines(lines[block[:first]..block[:last]]) }
      lines.join
    end

    # The last line of a bare block that opens at a line, which ends with the outdent block it's in, if it's in one.
    def bare_block_last(blocks, open, last)
      block = blocks.find { (it[:first]..it[:last]).cover?(open) }
      return last unless block

      [last, block[:last]].min
    end

    # The Markdown with each block as a <div class="outdent"> of its lines without their <, so they render as Markdown.
    def unwrapped(markdown)
      lines = markdown.lines
      blocks(lines).reverse_each do |block|
        inner = inner_lines(lines[block[:first]..block[:last]]).map { it.end_with?("\n") ? it : "#{it}\n" }
        lines[block[:rule]..block[:last]] = [HTML, "\n", *inner, "\n", "</div>\n"]
      end
      lines.join
    end

    def inner_lines(lines)
      lines.map { it.sub(/\A< ?/, '') }
    end

    # Each line with its <, and the last without a line break when the block ends the file without one.
    def outer_lines(lines, ends_file:)
      outer = lines.map { it.strip.empty? ? "<#{it}" : "< #{it}" }
      outer[-1] = outer[-1].chomp if ends_file && outer.any?
      outer
    end
  end
end
