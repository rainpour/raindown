# frozen_string_literal: true

require_relative '../events'
require_relative '../rows'
require_relative '../text'

module Raindown
  module TUI
    # Said in place of a page, like the charts or the code to feel, when the folder has no projects, with how to make one.
    NO_PROJECTS = ['No projects found in this directory.', %(Run "raindown init" in a project's folder.)].freeze

    # Draws what's in a pane, :nav or :main, as lines of the pane's width and height, which the Layout puts in it.
    # Like the Layout, it's made again for each draw, so it draws what the Navigator and its view hold then.
    Renderer = Struct.new(:navigator, :pane, :width, :height) do
      include Rows
      include Text

      # Its side of the line above the panes, which is blank unless it has something to say there, like a progress.
      def spacer = [segment('', :blank)]

      # The lines in a purple box, like an alert, at the top left, with blank below it, like when there's nothing to show.
      # It's no wider than the pane, cutting the lines to fit.
      def alert(messages)
        inner = [messages.map { display_width(it) }.max, width - 5].min.clamp(0..)
        box = [alert_edge('╔', '╗', inner), *messages.map { alert_line(it, inner) }, alert_edge('╚', '╝', inner)]
        (box + Array.new(height) { [segment('', :blank)] }).first(height)
      end

      def alert_edge(left, right, inner)
        padded([segment('', :blank, width: 1), segment("#{left}#{'═' * (inner + 2)}#{right}", :alert, width: inner + 4)])
      end

      def alert_line(message, inner)
        padded([segment('', :blank, width: 1), segment('║ ', :alert, width: 2), segment(message, :alert, width: inner),
                segment(' ║', :alert, width: 2)])
      end
    end
  end
end
