# frozen_string_literal: true

require 'antlers/api'
require_relative '../raindown/node_blocks'

module Raindown
  # A write-in node, in Antlers' delimiters, read with its props as Raindown reads them, like
  # <{ :list folder: 'notes' }>. It opens a block with <{ Name: }>, and <{ :Name }> ends one, or else it's self-closing,
  # as is <{ Card title='Hi' }>. Template directives, like if: and for:, aren't nodes, so they're left to their lexemes.
  module NodeLexeme
    include Antlers::Lexeme

    module_function

    DIRECTIVE = /\A(:)?([A-Za-z]\w*(?:::[A-Z]\w*)*)(:)?(?:\s+(.*))?\z/m

    # A name with a colon is a node, like <{ :toc }> or <{ :app_name }>, while {:app_name} is a translation. One without
    # is a node when it's capitalized, so <{ title }> is still a variable. The lexer gives no name to a directive that
    # starts with another lexeme's keyword, like <{ if: draft }> or <{ :list }>, which it leaves to that lexeme.
    def match?(segment:, name: nil, **)
      _, close, node_name, open = segment.to_s.match(DIRECTIVE).to_a
      return false if name.nil? || node_name.nil? || (close && open)
      return true if close || open

      node_name.match?(/\A[A-Z]/)
    end

    # <{ :Name }> ends a block of the name, or else is self-closing, while <{ Name }> is always self-closing.
    def lexeme(segment:, **)
      _, close, name, open, args = segment.match(DIRECTIVE).to_a
      return { node_def: name, args: args.to_s } if open
      return { node_end: name, args: args.to_s } if close

      { node_solo: name, args: args.to_s }
    end
  end
end
