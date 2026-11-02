# frozen_string_literal: true

require 'cgi/escape'

module Raindown
  # How a content directive is written says what it does, and how it shows in the HTML:
  #   toc:                          bare, it writes its output into the file, and shows in bold
  #   <!-- toc: --> <!-- :toc -->   as comments, it writes its output into the file, and is left out of the HTML
  #   <{ toc: }> <{ :toc }>         in Antlers' delimiters, it only renders, and is left out of the HTML
  # Template directives, like for: and if:, are always in Antlers' delimiters, and always hidden.
  # Until the HTML's done each is a comment marker, which ends the Markdown block before it and starts nothing itself,
  # so a node's list stays its own list. A hidden one is left out of the HTML altogether.
  module Directives
    MARKER = /<!-- raindown:directive (.*?) -->/
    HIDDEN = /<!-- raindown:hidden .*? -->\n?/
    # A directive in an HTML comment, which writes back, or in Antlers' delimiters, which only renders.
    COMMENT = ['<!--', '-->'].freeze
    DELIMITERS = ['<{', '}>'].freeze

    module_function

    # A directive's line without its delimiters, like "files: folder: 'notes'" for <!-- files: folder: 'notes' -->.
    def text(line)
      line = line.strip
      [COMMENT, DELIMITERS].each do |open, close|
        return line.delete_prefix(open).delete_suffix(close).strip if line.start_with?(open) && line.end_with?(close)
      end
      line
    end

    # Whether the directive's line is bare, without delimiters, so it shows in bold.
    def bare?(line) = text(line) == line.strip

    # A directive's line as a marker: in bold when it's shown, like a bare directive, or else hidden.
    def marker(line, shown: bare?(line))
      text = text(line).gsub('--', '- -')
      return "<!-- raindown:hidden #{text} -->" unless shown

      "<!-- raindown:directive #{text} -->"
    end

    def render(html)
      html.gsub(HIDDEN, '').gsub(MARKER) { "<p><strong>#{CGI.escapeHTML(::Regexp.last_match(1).to_s)}</strong></p>" }
    end
  end
end
