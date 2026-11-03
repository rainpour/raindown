# frozen_string_literal: true

require_relative '../file_tree'
require_relative 'commands'
require_relative '../endpoints'
require_relative 'focus'
require_relative 'mouse'
require_relative '../events'
require_relative '../views/outline_view'
require_relative '../views/list_view'
require_relative 'project_menu'
require_relative 'teleport'
require_relative 'views'
require_relative '../project'

module Raindown
  module TUI
    # What the terminal UI shows and does, in plain Ruby, with no terminal: a FileTree of the project's Markdown files,
    # beside the open file's Outline, or the Dashboard of its charts. The Screen draws it and sends it events, keys like
    # :down, or a Click, and next_step returns what the Screen does next: nil to draw again, :quit to stop, or a Run or Wait.
    class Navigator
      include Commands
      include Views
      include ProjectMenu
      include Teleport
      include Focus
      include Mouse

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :nav, right: :main }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze
      # Keys that open Teleport, the project menu, the Dashboard, Code feelings or Blueprints, from anywhere.
      OPENERS = { search: -> { open_teleport }, projects: -> { toggle_menu }, dashboard: -> { toggle_dashboard },
                  feelings: -> { open_view(feelings) }, blueprints: -> { open_view(blueprints) } }.freeze

      attr_reader :focus, :status

      # Saves tells of the files saved in the folder, which are written back on the next tick, like when it's watched,
      # running endpoints with no response as they are when it runs_endpoints, like with -x.
      def initialize(root:, path: nil, workers: Project.workers(root:), saves: nil, runs_endpoints: false)
        @workers = workers
        @saves = saves
        @runs_endpoints = runs_endpoints
        @files = FileTree.new(root:, workers:)
        @endpoints = Endpoints.new(workers:)
        @dashboard = DashboardView.new(root:, workers:)
        @feelings = FeelingsView.new(projects: Projects.outer_roots(workers.roots))
        @blueprints = BlueprintsView.new(root:, projects: workers.roots)
        @nav = ListView.new { nav_rows }
        first = @files.files.first
        # The dashboard is the first page, unless a file is asked for, and "d" goes from it to the first file.
        @view = OutlineView.new(first, workers:) if first
        path ? open_at(path, nil) : open_view(dashboard)
      end

      # An event nothing has, like a mouse button's release, does nothing.
      def next_step(event)
        case event
        when nil then nil
        when Click then click(event)
        when Type then type(event)
        when Hover then hover(event)
        when Drag then drag(event)
        else route(event)
        end
      end

      # After the editor closes, a Markdown file is written back, like a save while it's watched, and read again.
      # Other files, like code that was felt, aren't written back, and the view reads them again.
      def ran
        write_back(@edited) if @files.files.include?(@edited)
        view.load
        @endpoints.load
      end

      def root = @files.root
      def relative(path) = @files.relative(path)

      # The folder the files are shown from: the chosen project's, or the root's.
      def base = @files.base

      # While Teleport, or the view, like a feeling's note, takes what's typed, rather than keys' events.
      def typing? = teleporting? || view.typing?

      # How often the screen's drawn, which is up to the view, like faster for Code feelings' rain.
      def pace = view.pace(hovered)

      # What's in a pane: the nav's ListView on the left, or the view on the right, which keeps its own cursor.
      def content(pane) = pane == :nav ? @nav : view

      private

      # A typed character goes to Teleport, or to the view while it's typing.
      def type(event)
        return type_query(query + event.text) if teleporting?

        view.next_step(event)&.take(self) if view.typing?
      end

      def route(name)
        return :quit if name == :quit
        return teleport_event(name) if teleporting?
        return menu_event(name) if menu
        return instance_exec(&OPENERS[name]) if opener?(name)
        return view.next_step(name)&.take(self) if @focus == :main && view.next_step?(name)

        browser_event(name)
      end

      # Whether the key opens something from anywhere, unless the view's focused and keeps the key, like f in Blueprints.
      def opener?(name)
        return false if @focus == :main && view.respond_to?(:own_key?) && view.own_key?(name)

        OPENERS.key?(name)
      end

      def browser_event(name)
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] || other_pane) if PANES.key?(name)
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      # The Dashboard, Code feelings and Blueprints, then the files and the endpoints, with a blank line between each section that
      # has rows.
      def nav_rows
        rows = pages.map { |text, view| Row.new(text:, depth: 0, kind: :page, target: view, open: OpenView.new(view:)) }
        [rows, @files.rows, @endpoints.rows].reject(&:empty?).flat_map { [Row::SEPARATOR, *it] }.drop(1)
      end

      # The pages above the files, by how they're shown, in the files and Teleport, with emoji every terminal draws two
      # columns wide. Blueprints is listed once the project has some, from Claude Code or its code's comments.
      def pages
        pages = { '📊 Dashboard' => dashboard, '🎭 Feelings' => feelings }
        return pages unless blueprints.any?

        pages.merge('🌀 Blueprints' => blueprints)
      end

      def selected
        content(@focus).selected
      end

      # Enter opens what's selected, or folds it, and Space only folds.
      def activate(name)
        row = selected
        return row.open.take(self) if name == :enter && row&.open

        row&.fold&.call
        nil
      end
    end
  end
end
