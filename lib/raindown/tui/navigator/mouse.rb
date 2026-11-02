# frozen_string_literal: true

module Raindown
  module TUI
    # What a Navigator does with the mouse: a click where it's clicked, the mouse moving over something, which it keeps
    # as what's hovered, and dragging with the button held, which the view takes, like a blueprint's canvas, if it can.
    module Mouse
      # What the mouse is over, which a click there would send, like a Click on a method's cells, or nil.
      attr_reader :hovered

      private

      # A click moves the cursor where it's clicked, and does the click's action there, like a key, unless that would
      # leave the terminal UI, like for the editor, so a stray click only moves the cursor.
      # While the project menu or Teleport is open, only its items are clicked.
      def click(click)
        return if menu && click.pane != :menu
        return if teleporting? && click.pane != :teleport

        point(click)
        effect = route(click.action)
        effect unless effect.is_a?(Run)
      end

      def point(click)
        return @menu = click.index if click.pane == :menu
        return @match = click.index if click.pane == :teleport

        content(click.pane).cursor = click.index
        @focus = click.pane
      end

      def hover(hover)
        @hovered = hover.target
        nil
      end

      def drag(drag)
        view.drag(drag) if view.respond_to?(:drag)
      end
    end
  end
end
