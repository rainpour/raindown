# frozen_string_literal: true

require_relative 'tracing'
require_relative '../renderers/renderer'
require_relative '../search_box'

module Raindown
  module TUI
    # The blueprints from Claude Code's replies, right of the files, below the keywords they're filtered by, in the border,
    # which opens the filter, like Teleport, over it, listing those that match: when it was saved and its kind, and which one of how
    # many, then the blueprint, cut to fit the pane:
    #    ─────┌─────────────────── Filter ──────────────────┐───
    #         │ / weather▏                                  │
    #       ╭─│ Weather Report Light rain   2026-10-30 03:14 │
    #       │ └─────────────────────────────────────────────┘
    # Each is traced to its code: it's cornflower blue, the selected box is highlighted, and the code it names is below:
    #     ╭──────────────╮   ╭──────────────╮
    #     │ Watcher.listen│  │ Workers       │
    #     ╰──────────────╯   ╰──────────────╯
    #    ╭─ lib/raindown/watcher/changes.rb:17 · Watcher#listen ─────────────╮
    #    │ def self.listen(directory, &)                                      │
    #    ╰────────────────────────────────────────────────────────────────────╯
    class BlueprintsRenderer < Renderer
      include Tracing

      BUTTONS = [['Tab', 'Pane', :tab], ['f', 'Filter', :filter], ['↑↓←→', 'Box', nil], ['Space', 'Code', :toggle],
                 ['Enter', 'More', :expand], ['e', 'Edit', :edit], ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS

      def page = 'Blueprints'

      # The keywords the blueprints are filtered by, in the middle of the line above the panes, which opens the filter,
      # whose box's top is drawn over it while it's open.
      def spacer
        return title_line unless view.typing?

        with_filter.first
      end

      # The blueprint, with the rest of the filter over it while it's open.
      def lines
        return shown_lines unless view.typing?

        with_filter.drop(1)
      end

      private

      def view = navigator.view

      def title_line
        title = " #{filtered_by} ▾ "
        title_width = display_width(title)
        left = [(width - title_width) / 2, 0].max
        padded([segment('', :blank, width: left), segment(title, :divider, width: title_width, event: filter_click),
                segment('', :blank, width: [width - left - title_width, 0].max)])
      end

      # The title line and the blueprint, with the filter drawn over them from the title line, once a frame.
      def with_filter = @with_filter ||= SearchBox.new(view, width:, title: 'Filter', pane:, top: 0).apply([title_line, *shown_lines])

      def shown_lines
        return traced_lines if view.selected
        return blank(" No blueprints match #{filtered_by}.") unless view.query.to_s.empty?

        blank(" No blueprints yet. #{saving}")
      end

      def filtered_by
        return 'All' if view.query.to_s.strip.empty?

        "“#{view.query.strip}”"
      end

      # The click on the title, which keeps the blueprint shown.
      def filter_click = Click.new(pane:, index: view.cursor, action: :filter)

      # When it was saved and its kind, then which one it is of how many, at the right.
      def about(blueprint)
        saved = " #{blueprint.where}"
        place = "#{view.cursor + 1} of #{view.blueprints.length} "
        [segment(saved, :body, width: [width - display_width(place), 0].max), segment(place, :body, width: display_width(place))]
      end

      def saving = "Claude Code's are saved to #{Blueprints::FILE} by `raindown blueprints`."

      def blank(message)
        [[segment(message, :info)], *Array.new([height - 1, 0].max) { [segment('', :blank)] }]
      end
    end
  end
end
