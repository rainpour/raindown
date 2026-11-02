# frozen_string_literal: true

module Raindown
  module TUI
    # A blueprint's drawing seen through the canvas, a window of a fixed size, from its offset: the columns and rows of
    # the drawing off its left and top. The canvas follows the selected box, bringing it into view, until it's scrolled,
    # with Shift and the arrows or by dragging the mouse, and follows again when another box is selected.
    module Canvas
      # Shift and an arrow scroll the canvas by columns across, or by rows up and down, like the arrows' own steps.
      SCROLLS = { scroll_left: [-4, 0], scroll_right: [4, 0], scroll_up: [0, -1], scroll_down: [0, 1] }.freeze

      # The offset for a canvas of the width and height, with the selected box in view while it's followed, and the
      # drawing no further off than it can be while still filling the canvas.
      def canvas(width, height)
        column, row = @offset || [0, 0]
        column, row = into_view(column, row, width, height) if @following && box
        @offset = [column.clamp(0, [drawing_width - width, 0].max), row.clamp(0, [drawing_height - height, 0].max)]
      end

      # Whether there's more of the drawing past the canvas, to the left, right, top and bottom.
      def beyond(width, height)
        column, row = @offset
        { left: column.positive?, right: drawing_width > column + width, up: row.positive?, down: drawing_height > row + height }
      end

      # Dragging the drawing moves it with the mouse, so the canvas scrolls the other way.
      def drag(drag)
        scroll(-drag.columns, -drag.rows)
      end

      private

      def scroll(columns, rows)
        column, row = @offset || [0, 0]
        @offset = [[column + columns, 0].max, [row + rows, 0].max]
        @following = false
        nil
      end

      # Shown from its first column and row, following the selected box, like when another blueprint's selected.
      def follow(from_start: false)
        @offset = [0, 0] if from_start
        @following = true
      end

      # The offset moved as little as it can for the box to be in view, or its top left when it's bigger than the canvas.
      def into_view(column, row, width, height)
        selected_box = boxes[box]
        column = selected_box.right - width + 1 if selected_box.right >= column + width
        row = selected_box.bottom - height + 1 if selected_box.bottom >= row + height
        [[column, selected_box.left].min, [row, selected_box.top].min]
      end

      def drawing_width = drawing.map(&:length).max.to_i
      def drawing_height = drawing.length
    end
  end
end
