# frozen_string_literal: true

require_relative '../code_box'

module Raindown
  module TUI
    # A blueprint traced to its code: its lines and text cornflower blue, the selected box highlighted, on a canvas that
    # scrolls, with a marker at each edge there's more beyond, then the code the selected box names in a box below it,
    # as tall whether or not there's code, so the canvas above stays still.
    module Tracing
      include CodeBox

      # The rows the canvas keeps when the code box is expanded.
      MIN_CANVAS_ROWS = 2
      # The line above the canvas, and the rows for its up and down markers.
      AROUND_CANVAS = 3
      # The most lines its description wraps onto, above the canvas.
      DESCRIPTION_LINES = 3

      private

      # When it was saved and which one it is, then its description, then the canvas, between the rows for its up and
      # down markers, then the code its selected box names, in a CodeBox, which takes rows from the canvas when it's
      # expanded.
      def traced_lines
        box = code_box
        description = description_lines
        @canvas_height = [height - box.length - description.length - AROUND_CANVAS, 1].max
        canvas = canvas_lines
        [about(view.selected), *description, marker_line(:up, '▲'), *canvas, marker_line(:down, '▼'), *box].first(height)
      end

      # The paragraph above it in Claude Code's reply, below a blank line, in the text's own colour, wrapped.
      def description_lines
        description = view.selected.description
        return [] unless description

        lines = wrap(description, width - 2).first(DESCRIPTION_LINES).map { [segment(" #{it.rstrip}", :text)] }
        [[segment('', :blank)], *lines]
      end

      # The canvas's rows of the drawing, from its offset, which follows the selected box.
      def canvas_lines
        column, row = view.canvas(canvas_width, canvas_height)
        @beyond = view.beyond(canvas_width, canvas_height)
        Array.new(canvas_height) { canvas_line(row + it, column, middle: it == canvas_height / 2) }
      end

      # The pane's width, less a column at each side for the left and right markers.
      def canvas_width = [width - 2, 1].max

      # The rows between the line above, the markers' rows and the code box.
      attr_reader :canvas_height

      # A row of the drawing seen through the canvas, from its column, with the left and right markers on the middle row.
      def canvas_line(row, column, middle:)
        segments = drawn_segments(view.drawing[row].to_a, row, column)
        drawn = segments.sum { display_width(it.text) }
        [marker(:left, '◀', middle), *segments, segment('', :blank, width: [canvas_width - drawn, 0].max), marker(:right, '▶', middle)]
      end

      # The line's columns across the canvas, from its column, in runs of the same style and box.
      def drawn_segments(line, row, column)
        runs = (column...[column + canvas_width, line.length].min).chunk_while { drawn_part(row, _1) == drawn_part(row, _2) }
        runs.map { |run| run_segment(line, run, row) }
      end

      def marker(side, arrow, shown)
        return segment(arrow, :divider, width: 1) if shown && @beyond[side]

        segment(' ', :blank, width: 1)
      end

      # The row above or below the canvas, with its marker in the middle when there's more of the drawing that way.
      def marker_line(side, arrow)
        return [segment('', :blank)] unless @beyond[side]

        [segment(arrow.center(width), :divider)]
      end

      def drawn_part(row, column) = [part_style(row, column), box_click(row, column)]

      # The line's characters at the run of columns, in their style, which select their box when they're clicked, with half
      # a wide character, cut at the canvas's edge, left blank.
      def run_segment(line, run, row)
        segment(line[run.first..run.last].join, part_style(row, run.first), width: run.size, event: box_click(row, run.first))
      end

      def box_click(row, column)
        clicked = view.boxes.find { it.cover?(row, column) }
        Click.new(pane:, index: view.cursor, action: clicked) if clicked
      end

      # The selected box highlighted, and the rest cornflower blue.
      def part_style(row, column)
        return :selected if view.box && view.boxes[view.box].cover?(row, column)

        :divider
      end

      # The code box shows the code the selected box names, or that it names none.
      def boxed_method = view.code
      def box_style = :divider
      def box_footer = []
      def box_room = height - AROUND_CANVAS - BOX_LINES - MIN_CANVAS_ROWS

      def box_title(method)
        return 'No code' unless method

        "#{where(method)} · #{method.owner}##{method.name}"
      end

      # Which of the code the box names is shown, at the right of the box's top, when it names more than one.
      def box_note(method)
        named = view.codes(view.boxes[view.box]) if method
        return '' unless named && named.length > 1

        " #{named.index(method) + 1} of #{named.length} ─"
      end

      # The method's code highlighted, or that the box names no code.
      def box_parts(method)
        return [[['Nothing in this box names a class or method in the code.', :body]]] unless method

        highlighted(method)
      end
    end
  end
end
