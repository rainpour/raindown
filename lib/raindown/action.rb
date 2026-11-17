# frozen_string_literal: true

require_relative 'node_blocks'

module Raindown
  # What an input does to a note, rather than typing, which Raindown makes rather than an app, so it reads
  # directives as Raindown does: props set on the directive on a line, counted from 0, like { zoom: 9 } for a map's
  # zoom: 8, each written where the directive has it, as it'd be typed. A directive in a grid's cell is by the column
  # its cell starts at, after its |. The directive decides what can change, so a prop it hasn't got, or a line that
  # isn't one, leaves the note as it was. An app makes it at once too, with SCRIPT, so it shows straight away, before
  # Raindown makes it again as it writes the note back.
  class Action
    # The same action in JavaScript, raindownAfterAction(markdown, action, { bare }), for an app to take at once.
    SCRIPT = File.join(__dir__, 'js', 'action.js')

    attr_reader :line, :column, :set

    def initialize(line:, set:, column: nil)
      @line = line
      @column = column
      @set = set.transform_keys(&:to_sym)
    end

    # The Markdown after the action.
    def apply(markdown, bare: false)
      lines = markdown.lines
      edited = lines[line] && directive_edited(lines[line], bare:)
      return markdown unless edited

      lines[line] = edited
      lines.join
    end

    private

    # The line with the props set on its directive, or nil.
    def directive_edited(text, bare:)
      props, at = props_of(text, bare:)
      return unless props

      values = values_in(props)
      return unless set.keys.all? { values.key?(it) }

      with_values(text, values.values_at(*set.keys).map { |start, stop| [at + start, at + stop] })
    end

    # The line with each of the set's values typed over where the prop's value was, from the last, so where the others
    # are doesn't move.
    def with_values(text, spans)
      spans.zip(set.values).sort_by { |(start, _), _| -start }.each_with_object(text.dup) do |((start, stop), value), edited|
        edited[start...stop] = typed(value)
      end
    end

    # The directive's props on the line, and where they start in it, or nil when it isn't a directive with props.
    def props_of(text, bare:)
      from, to = directive_span(text)
      match, = NodeBlocks.directive(text[from...to], bare: bare || !column.nil?)
      return unless match && match[3]

      [match[3], from + match.begin(3)]
    end

    # Where the directive is in the line: all of it but its line break, or its cell, up to the next |, without the
    # spaces around it.
    def directive_span(text)
      return [0, text.chomp.length] unless column

      cell = text[column..].to_s.split('|').first.to_s
      from = column + cell[/\A\s*/].length
      [from, from + cell.strip.length]
    end

    # Where each prop's value is in the props, as [start, stop], by its name, after a value that's the node's argument
    # when it comes first.
    def values_in(args)
      start = argument_end(args)
      args[start..].to_enum(:scan, NodeBlocks::PROP).to_h do
        match = Regexp.last_match
        [match[1].to_sym, [start + match.begin(2), start + match.end(2)]]
      end
    end

    # Where the node's argument ends, or 0 when the props come first.
    def argument_end(args)
      return 0 if args.match?(NodeBlocks::PROP_FIRST)

      args.match(NodeBlocks::ARG)&.end(0).to_i
    end

    # A value as it'd be typed: text in quotes, in double ones when it has a single one, and other values as they are.
    def typed(value)
      return 'nil' if value.nil?
      return value.to_s unless value.is_a?(String)
      return "'#{value}'" unless value.include?("'")
      raise ArgumentError, "Can't write #{value} as a prop, as it has both kinds of quote" if value.include?('"')

      "\"#{value}\""
    end
  end
end
