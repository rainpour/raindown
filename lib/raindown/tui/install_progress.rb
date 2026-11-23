# frozen_string_literal: true

module Raindown
  module TUI
    # A bar for installing curses, with its step and the seconds so far. Installing has no total to count towards, so
    # the bar sweeps back and forth until it's done. Without a terminal to draw in, it says what it's doing once.
    class InstallProgress
      WIDTH = 24
      MARK = '==='

      attr_writer :step

      def initialize(output)
        @output = output
        @step = 'Downloading'
        @started = clock
      end

      # Draws the bar every tenth of a second until the block says the install is done.
      def show_until
        @output.puts("Installing curses for Raindown's terminal app...") unless @output.tty?
        frame = 0
        until yield
          draw(frame) if @output.tty?
          frame += 1
          sleep(0.1)
        end
        clear
      end

      def done
        @output.puts("Installed curses in #{seconds}s")
      end

      # The bar on one line, drawn over the last one: "Building curses for Raindown's terminal app [  ===   ] 12s".
      def line(frame)
        travel = WIDTH - MARK.size
        position = frame % (travel * 2)
        position = (travel * 2) - position if position > travel
        bar = (' ' * position) + MARK + (' ' * (travel - position))
        "#{@step} curses for Raindown's terminal app [#{bar}] #{seconds}s"
      end

      private

      def draw(frame)
        @output.print("\r\e[2K#{line(frame)}")
        @output.flush
      end

      def clear
        @output.print("\r\e[2K") if @output.tty?
      end

      def seconds
        (clock - @started).round
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
