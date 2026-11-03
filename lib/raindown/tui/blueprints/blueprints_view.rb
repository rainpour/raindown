# frozen_string_literal: true

require_relative '../code_box'
require_relative '../events'
require_relative '../../blueprints'
require_relative 'traced_code'
require_relative 'canvas'
require_relative 'code_comments'
require_relative 'filter'

module Raindown
  module TUI
    # The blueprints from Claude Code's replies, in the project's .raindown/blueprints.md, newest first, then those in its
    # code's comments, one at a time, of
    # those its Filter's keywords match, each traced to its code: the arrows move between the boxes drawn in one, or a
    # click on one, the code each box names shows below, Space or another click moving on to
    # the next it names, Enter showing more of it, and E opens it, or the blueprint when the box names none.
    # The file's read again when it changes, like when a reply's saved more, showing the newest then.
    class BlueprintsView
      include Canvas
      include TracedCode
      include ShownCode
      include Filter

      # Left and right move between the boxes drawn in a blueprint, in reading order, and up and down to the nearest box
      # above or below, while up and down move between the filter's matches.
      BOX_MOVES = { left: -1, right: 1 }.freeze
      MOVES = { up: -1, down: 1 }.freeze
      BOX_ROWS = { up: :above?, down: :below? }.freeze
      # Space moves on to the next code the selected box names, Enter or clicking its more lines shows them, and E opens it.
      ACTIONS = { toggle: :next_code, enter: :toggle_expanded, expand: :toggle_expanded, edit: :edit }.freeze

      attr_reader :cursor

      def initialize(root:, projects: [root])
        @root = root
        @projects = projects
        @path = File.join(root, Blueprints::FILE)
        @all = []
        @cursor = 0
        select_box(0)
      end

      def renderer = BlueprintsRenderer
      def target = self
      def path = nil
      def pace(_hovered) = :active

      def status(_navigator)
        commented = @all.count { it.time.nil? }
        [:info, "#{count(@all.length - commented, 'blueprint')} from Claude Code, in #{Blueprints::FILE}, and #{commented} in comments"]
      end

      # Whether there are any blueprints yet, saved or in the code's comments, which are looked for once until it's loaded.
      def any? = File.exist?(@path) || commented.any?

      # Whether the file's changed since it was read, so it's read again on the next tick.
      def changed? = mtime != @read_at

      def load
        @read_at = mtime
        newest = @all.first&.time
        @commented = nil
        @all = Blueprints.read(@root) + commented
        self.cursor = 0 unless @all.first&.time == newest
        self.cursor = @cursor
      end

      def selected = blueprints[@cursor]

      # Another blueprint's shown from its first box, while the same one keeps its box and canvas, like when it's clicked.
      def cursor=(index)
        shown = selected
        @cursor = index.clamp(0, [blueprints.length - 1, 0].max)
        return if selected == shown

        select_box(0)
        follow(from_start: true)
      end

      # The selected box, of those drawn in the selected blueprint, or nil when it has none.
      def box = (@box.to_i.clamp(0, boxes.length - 1) if boxes.any?)

      # Every key but Tab to the files, or left from the first box, while the filter's closed.
      def next_step?(key) = !%i[tab tick].include?(key) && !(key == :left && box.to_i.zero? && !typing?)

      # The selected blueprint's characters by the columns they're shown in, with its boxes' sides straightened, and the
      # boxes drawn in it, found again when another's selected.
      def drawing
        @drawing = [selected, Blueprints.tidied(Blueprints.columns(selected&.lines || []), boxes)] unless @drawing&.first == selected
        @drawing.last
      end

      def boxes
        @boxes = [selected, Blueprints.boxes(selected&.lines || [])] unless @boxes&.first == selected
        @boxes.last
      end

      def next_step(key)
        return filter_step(key) if typing?
        return open_filter if %i[feelings filter].include?(key)
        return clicked(key) unless key.is_a?(Symbol)
        return move_box(BOX_MOVES[key]) if BOX_MOVES.key?(key)
        return move_row(BOX_ROWS[key]) if BOX_ROWS.key?(key)
        return scroll(*SCROLLS[key]) if SCROLLS.key?(key)

        send(ACTIONS[key]) if ACTIONS.key?(key)
      end

      private

      # The selected box's code, or the blueprint when the box names none.
      def edit
        return unless selected

        method = code
        return Edit.new(path: method.path, line: method.line) if method

        Edit.new(path: File.join(@root, selected.path), line: selected.line)
      end

      # A click on a box drawn in the blueprint, which moves on to the next code it names when it's already selected.
      def clicked(action)
        return next_code if boxes.index(action) == box

        select_box(boxes.index(action))
      end

      def move_box(by)
        select_box((box + by).clamp(0, boxes.length - 1)) if box
      end

      # The nearest box above or below the selected one, if there's one that way.
      def move_row(way)
        from = boxes[box] if box
        nearest = boxes.select { from && it.public_send(way, from) }.min_by { it.distance(from) }
        select_box(boxes.index(nearest)) if nearest
      end

      def count(number, noun) = "#{number} #{number == 1 ? noun : "#{noun}s"}"

      def mtime = File.exist?(@path) ? File.mtime(@path) : nil

      def commented = @commented ||= CodeComments.blueprints(@root, projects: @projects)
    end
  end
end
