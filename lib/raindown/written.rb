# frozen_string_literal: true

module Raindown
  # What a node's rewrite writes below its directive: its Markdown, and a comment straight below the directive, like
  # table:'s "2 rows · 3f2a9c", which its rewrite gets back as comment: the next time it writes. A rewrite can return a
  # string instead, when it has no comment.
  class Written
    attr_reader :markdown, :comment

    def initialize(markdown, comment: nil)
      @markdown = markdown
      @comment = comment
    end

    # Its Markdown, as a rewrite's string would be, like when it's rendered as HTML.
    def to_s
      markdown.to_s
    end
  end
end
