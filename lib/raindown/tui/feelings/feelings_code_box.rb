# frozen_string_literal: true

require_relative '../code_box'

module Raindown
  module TUI
    # Code feelings' CodeBox below the grid: the selected method's code, where it is and how many commits changed its
    # file, then why it felt that way while that's typed, below a line.
    module FeelingsCodeBox
      include CodeBox

      private

      def boxed_method = view.selected
      def box_title(method) = "#{where(method)} · #{method.label}"
      def box_note(method) = " changed #{method.changes}× ─"
      def box_style = :feelings
      def box_parts(method) = highlighted(method)

      # As many lines as fit expanded, with the bins and a few of the grid's rows left above it.
      def box_room = height - Bins::BIN_LINES - BOX_LINES - MIN_GRID_ROWS

      def box_footer
        return [] unless view.typing?

        note_lines
      end

      # Why it felt that way, as it's typed, below a line, in as many lines as it takes.
      def note_lines = [box_edge('├', '┤'), *hanging("Why #{view.noting.upcase}? > ", "#{view.note}▏").map { boxed([[it, :feelings]]) }]

      # The text after the lead, wrapped to fit the box, with the lines after the first lined up under the text.
      def hanging(lead, text)
        indent = ' ' * display_width(lead)
        lines = wrap(text, width - 6 - indent.length)
        [lead, *Array.new(lines.length - 1, indent)].zip(lines).map(&:join)
      end
    end
  end
end
