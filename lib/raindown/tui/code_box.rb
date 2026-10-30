# frozen_string_literal: true

require_relative 'highlighter'

module Raindown
  module TUI
    # A box of a method's code, highlighted, its first lines or, expanded, all that fit, like Code feelings' below its
    # grid, with why it felt that way while that's typed, below a line, or Blueprints' below a blueprint:
    #    ╭─ lib/text.rb:62 · Text#segments_between ──────────── changed 6× ─╮
    #    │ def segments_between(line, from, to)                              │
    #    │ [12 more lines]                                                   │
    #    ├───────────────────────────────────────────────────────────────────┤
    #    │ Why DREAD? > column maths, a character at a time▏                 │
    #    ╰───────────────────────────────────────────────────────────────────╯
    # The renderer gives the method shown, as boxed_method, or nil, and box_title, box_note for the top's right, box_style,
    # box_room, the most lines of code that fit expanded, box_parts, the lines it shows, and box_footer, any lines below them.
    # Its view keeps what it shows, as ShownCode.
    module CodeBox
      # The most of a method's code that shows, until it's expanded, and the rows the grid keeps when it is.
      CODE_LINES = 6
      MIN_GRID_ROWS = 2
      # The box's top and bottom, and the line of how many more lines there are.
      BOX_LINES = 3

      private

      # The method's code in a box, then the lines below it.
      def code_box
        method = boxed_method
        footer = box_footer
        code = code_lines(box_parts(method), box_room - footer.length)
        top = box_edge("╭─ #{box_title(method)} ", "#{box_note(method)}╮")
        [top, *code, *blank_lines(code.length + footer.length), *footer, box_edge('╰', '╯')]
      end

      # Blank lines after a short method's code and its footer, so the box is always as tall as it gets until it's expanded,
      # and what's above it stays still.
      def blank_lines(used) = Array.new([CODE_LINES + 1 - used, 0].max) { boxed([]) }

      # The first lines of the parts, or all that fit in the room when it's expanded, wrapped to fit the box, then how
      # many more there are, clicked to show them, or a line to show fewer again.
      def code_lines(parts, room)
        shown = CODE_LINES
        shown = [room, CODE_LINES].max if view.expanded
        lines = parts.map { wrapped(it) }
        fitting = lines.take_while { (shown -= it.length) >= 0 }
        code = fitting.flatten(1).map { boxed(it) }
        return code if lines.sum(&:length) <= CODE_LINES

        [*code, more_line(lines.length - fitting.length)]
      end

      # The highlighted line's [text, style] parts in as many lines as it takes to fit the box, like a note's, those
      # after the first carrying on after an ellipsis.
      def wrapped(parts)
        room = width - 6
        lead = [carried_lead(parts, room), box_style]
        rest = room - display_width(lead[0])
        return [parts] if rest < 1

        first, *others = line_breaks(parts.map { printable(it[0]) }.join, room, rest).each_cons(2).map { parts_between(parts, *it) }
        [first, *others.map { [lead, *it] }]
      end

      # Where the text breaks into lines, the first fitting the room and the others the rest.
      def line_breaks(text, room, rest)
        breaks = [0]
        fits = room
        while text.length - breaks.last > fits
          breaks << line_break(text, breaks.last, fits)
          fits = rest
        end
        breaks << text.length
      end

      # Where a line from the column breaks: after the last space that fits, or where it's full when none does.
      def line_break(text, from, fits)
        space = text[from, fits].rindex(' ').to_i
        return from + fits unless space.positive?

        from + space + 1
      end

      # An ellipsis at the line's own indent, up to half the room, which the lines it's wrapped onto start with.
      def carried_lead(parts, room) = "#{' ' * [parts.map(&:first).join[/\A */].length, room / 2].min}… "

      # The parts' text between two columns, in their styles.
      def parts_between(parts, from, to)
        segments = parts.map { |text, style| Text::Segment.new(text: printable(text), style:, event: nil) }
        segments_between(segments, from, to).map { [it.text, it.style] }
      end

      def more_line(hidden)
        text = "[#{hidden} more lines]"
        text = '[1 more line]' if hidden == 1
        text = "[Fewer lines]#{" · #{hidden} more don't fit" if hidden.positive?}" if view.expanded
        boxed([[text, :button]], event: Click.new(pane:, index: view.cursor, action: :expand))
      end

      # The method's code highlighted, kept by the view while it's shown.
      def highlighted(method) = view.highlighted(method) { Highlighter.lines(dedented(method.lines), filename: method.path) }

      # The lines without the indent they share, like a method's in its class.
      def dedented(lines)
        indent = lines.reject { it.strip.empty? }.map { it[/\A */].length }.min.to_i
        lines.map { it[indent..].to_s }
      end

      def where(method) = "#{navigator.relative(method.path)}:#{method.line}"

      # A line of the box, a column in from each side of the pane, of [text, style] parts, like highlighted code's.
      def boxed(parts, event: nil)
        padded([segment(' │ ', box_style, width: 3), *code_segments(parts, width - 6, event:), segment(' │', box_style, width: 2)])
      end

      # The box's top or bottom, with the left text cut short, rather than the corner, when there isn't room.
      def box_edge(left, right)
        room = width - 2 - display_width(right)
        left = "#{fit(left, room - 1)} " if display_width(left) > room
        fill = [room - display_width(left), 0].max
        padded([segment(" #{left}#{'─' * fill}#{right}", box_style, width: width - 1)])
      end
    end

    # What a view keeps of the code its CodeBox shows: whether it's expanded, and its highlighting, from frame to frame
    # while it's the one shown.
    module ShownCode
      attr_reader :expanded

      def highlighted(method)
        @highlighted = { method => yield } unless @highlighted&.key?(method)
        @highlighted[method]
      end

      private

      def toggle_expanded
        @expanded = !@expanded
        nil
      end
    end
  end
end
