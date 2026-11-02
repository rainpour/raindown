# frozen_string_literal: true

require 'curses'

require_relative '../events'
require_relative '../text'
require_relative 'quiet'

module Raindown
  module TUI
    # Turns curses' keys and clicks into a Navigator's events.
    module Input
      KEYS = {
        Curses::KEY_UP => :up, 'k' => :up, Curses::KEY_DOWN => :down, 'j' => :down,
        Curses::KEY_LEFT => :left, 'h' => :left, Curses::KEY_RIGHT => :right, 'l' => :right,
        Curses::KEY_SLEFT => :scroll_left, Curses::KEY_SRIGHT => :scroll_right, Curses::KEY_SR => :scroll_up,
        Curses::KEY_SF => :scroll_down,
        "\t" => :tab, Curses::KEY_BTAB => :tab, "\r" => :enter, "\n" => :enter, Curses::KEY_ENTER => :enter,
        ' ' => :toggle, 'x' => :execute, 'e' => :edit, 'w' => :write_back, 'r' => :reload, 'd' => :dashboard,
        'p' => :projects, 'f' => :feelings, 'b' => :blueprints, "\x14" => :celebrate, '/' => :search,
        '1' => :bin1, '2' => :bin2, '3' => :bin3, '4' => :bin4, '5' => :bin5, "\e" => :escape, 'q' => :quit
      }.freeze
      # While typing, like in Teleport, printable characters are typed, and only these keys do anything else.
      TYPING_KEYS = {
        Curses::KEY_UP => :up, Curses::KEY_DOWN => :down, "\r" => :enter, "\n" => :enter, Curses::KEY_ENTER => :enter,
        "\e" => :escape, Curses::KEY_BACKSPACE => :backspace, "\x7F" => :backspace, "\b" => :backspace
      }.freeze

      module_function

      # The next event, or :tick when no key is pressed within the timeout, in milliseconds, or nil for keys without one,
      # like a resize, which clears the screen to draw it again.
      def read(timeout, zones:, typing:)
        Curses.stdscr.timeout = timeout
        key = Curses.stdscr.getch
        return :tick if key.nil?
        return mouse(zones) if key == Curses::KEY_MOUSE

        Curses.stdscr.clear if key == Curses::KEY_RESIZE
        key_event(key, typing:)
      end

      # The curses gem warns the first time it makes a MouseEvent, that it's "undefining the allocator" of the class.
      def mouse(zones)
        event = Quiet.quietly { Curses.getmouse }
        mouse_event(event, zones) if event
      end

      # A key from getch, which is a string for a printable character and otherwise a number.
      # Letters are the same with Shift, as the buttons show them as capitals, unless they're being typed.
      def key_event(key, typing: false)
        return typing_event(key) if typing

        key = key.chr if key.is_a?(Integer) && key < 256
        KEYS[key.is_a?(String) ? key.downcase : key]
      end

      def typing_event(key)
        key = key.chr if key.is_a?(Integer) && key < 256
        TYPING_KEYS.fetch(key) { Type.new(text: key) if key.is_a?(String) && key.match?(/\A[[:print:]]\z/) }
      end

      # The mouse buttons that click, which are the left button's. Scrolling does nothing, and since older ncurses,
      # like macOS's, has no button for scrolling down, it can't be mistaken for a click.
      CLICKS = Curses::BUTTON1_PRESSED | Curses::BUTTON1_CLICKED

      # Letting go of the button, which older ncurses, like macOS's, also reports for each move while it's held, as it
      # doesn't know the moves terminals send then.
      RELEASE = Curses::BUTTON1_RELEASED

      # Moving the mouse, which terminals report once they're asked to, with any motion tracking.
      MOTION = Curses::REPORT_MOUSE_POSITION
      ANY_MOTION = "\e[?1003h"
      NO_MOTION = "\e[?1003l"

      # The terminal sends the app its mouse events, clicks and moves, so scrolling doesn't scroll the terminal either.
      # ncurses only asks some terminals to report every move, so it's asked directly too, until untrack_mouse.
      def track_mouse
        Curses.mousemask(CLICKS | RELEASE | MOTION)
        Curses.mouseinterval(0)
        $stdout.write(ANY_MOTION)
        $stdout.flush
      end

      def untrack_mouse
        $stdout.write(NO_MOTION)
        $stdout.flush
      end

      # A click sends the event of what's under it, and moving the mouse a Hover of it, or a Drag by how far it's moved
      # since the last event while the button's held. Terminals and ncurses versions report that in their own ways: a
      # move the button's held for, a move after a press, until the release, or with older ncurses and some terminals,
      # a release somewhere else than the last event, for each move. A release where the mouse already is, which ends a
      # click or a drag, does nothing.
      def mouse_event(event, zones)
        from = @last
        @last = [event.x, event.y]
        held = hold(event.bstate)
        return drag(from, event) if from && dragged?(event, held:, moved: from != @last)
        return if event.bstate.anybits?(RELEASE)

        target = click(zones, column: event.x, row: event.y)
        return target if event.bstate.anybits?(CLICKS)

        Hover.new(target:) if event.bstate.anybits?(MOTION)
      end

      # Whether the button was held before this event, which holds it from a press until a release.
      def hold(bstate)
        held = @held
        @held = bstate.anybits?(CLICKS) || (held && !bstate.anybits?(RELEASE))
        held
      end

      def drag(from, event) = Drag.new(columns: event.x - from[0], rows: event.y - from[1])

      def dragged?(event, held:, moved:)
        bstate = event.bstate
        return held || bstate.anybits?(Curses::BUTTON1_PRESSED) if bstate.anybits?(MOTION)

        moved && bstate.anybits?(RELEASE)
      end

      # Where each of a Layout's segments with an event is on the screen, as [row, columns, event].
      def zones(lines)
        lines.each_with_index.flat_map do |segments, row|
          column = 0
          segments.filter_map do |segment|
            width = Text.display_width(segment.text)
            zone = [row, column...(column + width), segment.event] if segment.event
            column += width
            zone
          end
        end
      end

      def click(zones, column:, row:)
        zones.find { |zone_row, columns, _event| zone_row == row && columns.cover?(column) }&.last
      end
    end
  end
end
