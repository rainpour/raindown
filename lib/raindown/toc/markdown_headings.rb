# frozen_string_literal: true

require_relative '../front_matter'
require_relative '../variables'

module Raindown
  # The headings of Markdown as it's written, without rendering it, so a table of contents can be written back while
  # it's typed: # headings and underlined ones, outside front matter, code and HTML comments, with their text as it
  # reads, without its links, code or emphasis marks, and ids made the way Commonmarker makes them, numbered when
  # they repeat, like to-read and to-read-1. Variables in them, like {title}, are filled in from the variables given,
  # but headings in if: and for: blocks are as they're written, and headings that components render aren't in it, as
  # they're only in HTML.
  module MarkdownHeadings
    ATX = /\A {0,3}(\#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+\#+)?[ \t]*\z/
    SETEXT = /\A {0,3}(=+|-+)[ \t]*\z/
    FENCE = /\A {0,3}(`{3,}|~{3,})/
    # A line that's a block of its own, rather than a paragraph's, which can't be underlined into a heading.
    BLOCK = /\A {0,3}(?:[|>#<]|[-*+][ \t]|\d+[.)][ \t]|\z)/
    COMMENT = /<!--.*?-->/m

    module_function

    def scan(markdown, variables: nil)
      seen = Hash.new(0)
      headings(lines(markdown)).map do |level, written|
        written = filled(written, variables)
        text = plain(written)
        id = anchor(plain(written, images: true))
        count = seen[id]
        seen[id] += 1
        { level:, text:, id: count.zero? ? id : "#{id}-#{count}" }
      end
    end

    # A heading's id, the way Commonmarker makes it, like to-read for "To read".
    def anchor(heading)
      heading.downcase.gsub(/[^\p{Word}\- ]/, '').tr(' ', '-')
    end

    # Its lines after its front matter, with its HTML comments blanked out, keeping their lines.
    def lines(markdown)
      _, body = FrontMatter.parse(markdown)
      body.to_s.gsub(COMMENT) { it.gsub(/[^\n]/, '') }.lines(chomp: true)
    end

    # Each heading's level and text, outside fenced code, in order.
    def headings(lines)
      fence = nil
      lines.each_with_index.filter_map do |line, index|
        marker = line[FENCE, 1]
        if marker || fence
          fence = fence_after(fence, marker)
          next
        end

        heading(line, index.positive? ? lines[index - 1] : '')
      end
    end

    # The fence still open after a line with the marker: closed by one like it, at least as long.
    def fence_after(fence, marker)
      return marker unless fence
      return nil if marker&.start_with?(fence[0]) && marker.length >= fence.length

      fence
    end

    def heading(line, above)
      if (match = line.match(ATX))
        [match[1].length, match[2].to_s]
      elsif line.match?(SETEXT) && !above.match?(BLOCK) && !above.match?(SETEXT)
        [line.strip.start_with?('=') ? 1 : 2, above]
      end
    end

    # The heading with its variables filled in, like {title}.
    def filled(text, variables)
      return text unless variables

      text.gsub(/\{([A-Za-z_][\w.]*)\}/) { Variables.value(variables, ::Regexp.last_match(1)).to_s }
    end

    # The heading's text as it reads: links as their text, images left out, or as their alt text, as in its id, code
    # without its backticks, emphasis without its marks, but for underscores inside words, HTML without its tags, and
    # escaped characters as themselves.
    def plain(text, images: false)
      text.strip
          .gsub(/!\[([^\]]*)\]\([^)]*\)/) { images ? ::Regexp.last_match(1) : '' }
          .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')
          .gsub(/(`+)(.+?)\1/) { ::Regexp.last_match(2).strip }
          .gsub(/(\*\*|\*)(?=\S)(.+?)(?<=\S)\1/, '\2')
          .gsub(/(?<![[:alnum:]])(__|_)(?=\S)(.+?)(?<=\S)\1(?![[:alnum:]])/, '\2')
          .gsub(/<[^>]*>/, '')
          .gsub(/\\([[:punct:]])/, '\1')
          .strip
    end
  end
end
