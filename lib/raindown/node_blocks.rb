# frozen_string_literal: true

require 'lowkey'

require_relative 'code_blocks'
require_relative 'directives'
require_relative 'front_matter'
require_relative 'nodes'
require_relative 'variables'

module Raindown
  # Finds node blocks in a file's lines: a node's directive and the Markdown it wrote below it.
  # In comments the block ends with the node's end tag, and bare at the next blank line, and both write back:
  #   <!-- Changelog: limit=3 -->        Changelog: limit=3
  #                                      - **1.2.0** Bare directives
  #   - **1.2.0** Bare directives
  #
  #   <!-- :Changelog -->
  # A bare :Changelog is write-in: it only renders, with its render, never its rewrite. In Antlers' delimiters, like
  # <{ Changelog }>, it's write-in too, and the template pass renders it, as a WriteInNode, so it's only found here
  # for a document's outline. toc: and list: are Raindown's own nodes. A name only starts a block when it's a loaded
  # node, so other text like "Note:" is left alone.
  module NodeBlocks
    class MissingEndTag < StandardError; end
    class BrokenText < StandardError; end

    NAME = "(?:#{Nodes::BUILT_INS.keys.join('|')}|[A-Z]\\w*(?:::[A-Z]\\w*)*)".freeze
    OPEN = /\A( {0,3})<\{\s*(#{NAME}):(?:\s+(.*?))?\s*\}>[ \t]*$/
    COMMENT_OPEN = /\A( {0,3})<!--\s*(#{NAME}):(?:\s+(.*?))?\s*-->[ \t]*$/
    BARE_OPEN = /\A( {0,3})(#{NAME}):(?:[ \t]+(.*?))?[ \t]*$/
    # <{ Card }>, or <{ :Card }>, which a lowercase name like toc needs, as <{ toc }> is a variable.
    SELF_CLOSING = /\A( {0,3})<\{\s*(?::|(?=[A-Z]))(#{NAME})(?:\s+(.*?))?\s*\}>[ \t]*$/
    BARE_SELF_CLOSING = /\A( {0,3}):(#{NAME})(?:[ \t]+(.*?))?[ \t]*$/
    # Unquoted text after name:, like YAML's, runs up to the next prop, so title: Hello world limit: 3 has two.
    UNQUOTED = /.+?(?=[ \t]+\w+(?:=|:[ \t])|[ \t]*\z)/
    # A prop is name=value or name: value, where the value is quoted text, a number, true, false
    # or a variable like author.name. After name= it's one word.
    PROP = /(\w+)(?:=|:[ \t]+)("[^"]*"|'[^']*'|(?<==)\S+|#{UNQUOTED})/
    # A value before the props is the node's argument.
    ARG = /\A("[^"]*"|'[^']*'|[^\s"']#{UNQUOTED}|[^\s"'])(?:\s+|\z)/

    module_function

    # Each block outside code and front matter as { open:, close:, last:, writes:, node: }, where close is nil for a
    # bare block, and writes is whether its output's written into the file. A self-closing node is a block of one line.
    def find(lines, front_matter: {}, bare: false)
      with_nodes(spans(lines, bare:), front_matter)
    end

    def with_nodes(spans, front_matter)
      variables = Variables.new(front_matter)

      spans.map do |span|
        node = Nodes.instance(span[:class], *args(span[:args], variables, antlers: span[:antlers]))
        span.except(:name, :class, :args, :antlers).merge(node:)
      end
    end

    # Each block like find's, with the node's name, class and props text in place of the node,
    # so a block can be found without making its node, like for a document's outline.
    def spans(lines, bare: false)
      spans = []
      index = FrontMatter.line_count(lines)

      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close]
        elsif (span = span_at(lines, index, bare:))
          spans << span
          index = span[:last]
        end

        index += 1
      end

      spans
    end

    # Swaps each bare block or block in comments for its node's Markdown, or its HTML when it has its own, or only renders,
    # as a fragment or a placeholder. The directive and end tag become Directives markers, which also keep the node's
    # output from joining the Markdown around it, like two lists becoming one. Ones in <{ }> are left to Antlers.
    def to_rendered(context)
      lines = context.document.dup.force_encoding('UTF-8').lines
      spans = spans(lines, bare: context.bare).reject { it[:antlers] }
      with_nodes(spans, FrontMatter.parse(context.document).first).reverse_each do |block|
        lines[block[:open]..block[:last]] = rendered_lines(lines, block, context)
      end
      lines.join
    end

    def rendered_lines(lines, block, context)
      output = node_markdown(block, context).chomp
      close = marker(lines[block[:close]]) if block[:close]

      [marker(lines[block[:open]]), *("#{output}\n".lines unless output.empty?), *close]
    end

    def node_markdown(block, context)
      return Nodes.rendered(block[:node], context) if !block[:writes] || Nodes.html?(block[:node])

      Nodes.call(block[:node], :rewrite, **context.to_h).to_s
    end

    def marker(line)
      "#{Directives.marker(line)}\n"
    end

    def span_at(lines, index, bare:)
      found, pattern = directive(lines[index], bare:)
      return unless found && (klass = Nodes.node_class(found[2]))

      span = { name: found[2], class: klass, args: found[3].to_s, antlers: %i[open self_closing].include?(pattern) }
      case pattern
      when :open, :comment_open
        end_tag(lines, index, found[2], comment: pattern == :comment_open)
          .then { |close| { open: index, close:, last: close, writes: pattern == :comment_open, **span } }
      when :bare_open then { **bare_block(lines, index), writes: true, **span }
      else { open: index, close: nil, last: index, writes: false, **span }
      end
    end

    # The directive on the line and which kind it is, or nil.
    def directive(line, bare:)
      patterns = { open: OPEN, comment_open: COMMENT_OPEN, self_closing: SELF_CLOSING }
      patterns.merge!(bare_open: BARE_OPEN, bare_self_closing: BARE_SELF_CLOSING) if bare

      patterns.each do |pattern, regexp|
        match = line.match(regexp)
        return [match, pattern] if match
      end

      nil
    end

    # A bare block holds the lines straight below it, up to the next blank line, with fenced code kept whole.
    def bare_block(lines, open) = { open:, close: nil, last: CodeBlocks.last_before_blank(lines, open) }

    # The end tag written the same way as the directive: in a comment, or in Antlers' delimiters.
    def end_tag(lines, open, name, comment:)
      first, last = comment ? Directives::COMMENT : Directives::DELIMITERS
      tag = /\A {0,3}#{Regexp.escape(first)}\s*:#{Regexp.escape(name)}\s*#{Regexp.escape(last)}[ \t]*$/
      close = (open + 1...lines.length).find { |index| lines[index].match?(tag) }
      raise MissingEndTag, "#{first} #{name}: #{last} on line #{open + 1} needs #{first} :#{name} #{last}" unless close

      close
    end

    # The props, after a value that's the node's argument when it comes first, like 'data.csv' in chart: 'data.csv'.
    def args(text, variables, antlers: true)
      arg = text.match(ARG) unless text.match?(/\A#{PROP}/)
      return [props(text, variables, antlers:)] unless arg

      [props(arg.post_match, variables, antlers:), [value(arg[1], variables, antlers:)]]
    end

    # Text that isn't a prop, like world in title: 'Hello' world or tag=a b, is an error rather than left out.
    def props(text, variables, antlers: true)
      unread = text.gsub(PROP, '').split
      raise BrokenText, "Can't read #{unread.join(' ')} in #{text.strip}. Text with spaces needs quotes" if unread.any?

      text.scan(PROP).to_h { |name, value| [name.to_sym, value(value, variables, antlers:)] }
    end

    # A value, like 'text', 3, true, nil or :draft, or else a variable. In Antlers' delimiters a word is a variable, like
    # author.name, while bare or in a comment, which read like Markdown, it's text, like notes in list: folder: notes,
    # and only one in braces is a variable, like {author.name}.
    def value(value, variables, antlers: true)
      Lowkey::ValueParser.parse(value) do
        next value[1..-2] if value.match?(/\A(["']).*\1\z/)
        next Variables.value(variables, value[1..-2]) if !antlers && value.match?(/\A\{.+\}\z/)
        next value unless antlers
        raise BrokenText, "Can't read #{value} as a variable. Text with spaces needs quotes" if value.match?(/\s/)

        Variables.value(variables, value)
      end
    end
  end
end
