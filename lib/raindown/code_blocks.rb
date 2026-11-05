# frozen_string_literal: true

module Raindown
  # Finds fenced code blocks in a file's lines.
  module CodeBlocks
    FENCE = /\A {0,3}(`{3,}|~{3,})[ \t]*(\S*)/
    SNIPPET_LANGUAGES = %w[sh bash shell zsh console curl].freeze
    # The comment Raindown writes between an endpoint's snippet and its response, with the response's status, how long
    # it took and the date it was fetched, like <!-- response 200 · 142 ms · 2026-10-14 -->.
    RESPONSE_COMMENT = /\A {0,3}<!-- response [^\n]*? -->[ \t]*$/
    # The line closing a fence, like ``` or ~~~~, compiled once per fence.
    CLOSINGS = Hash.new { |closings, fence| closings[fence] = /\A {0,3}#{fence[0]}{#{fence.length},}[ \t]*$/ }

    module_function

    # The block opening at index, closed by a fence of the same character that's at least as long.
    def at(lines, index)
      fence, language = lines[index]&.match(FENCE)&.captures
      return unless fence

      close = (index + 1...lines.length).find { |i| lines[i].match?(CLOSINGS[fence]) }
      { open: index, close:, language:, body: lines[index + 1...close].join } if close
    end

    # An endpoint's curl snippet and its response, if it has one yet, with the line of the response comment between them
    # as the response's :comment, if there is one. A second snippet straight after is another example rather than the
    # response. A bare endpoint's are in the lines straight below it, up to the next blank line.
    def endpoint(lines, index, bare: false)
      lines = lines[..last_before_blank(lines, index - 1)] if bare
      snippet = at(lines, skip_blank_lines(lines, index))
      return [] unless snippet

      index = skip_blank_lines(lines, snippet[:close] + 1)
      comment = index if lines[index]&.match?(RESPONSE_COMMENT)
      response = at(lines, comment ? skip_blank_lines(lines, comment + 1) : index)
      return [snippet] if response.nil? || snippet?(response)

      [snippet, response.merge(comment:)]
    end

    def snippet?(block)
      SNIPPET_LANGUAGES.include?(block[:language].downcase) || block[:body].lstrip.start_with?('curl')
    end

    # The last of the lines straight below open, up to the next blank line, with fenced code kept whole, or open when
    # there are none, like a bare block's.
    def last_before_blank(lines, open)
      last = open
      last = at(lines, last + 1)&.fetch(:close) || (last + 1) while lines[last + 1] && !lines[last + 1].strip.empty?
      last
    end

    def skip_blank_lines(lines, index)
      index += 1 while lines[index]&.strip&.empty?
      index
    end
  end
end
