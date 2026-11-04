# frozen_string_literal: true

require_relative '../cloud'
require_relative '../feelings/celebration/scene'

module Raindown
  module TUI
    # The Screen's first frames, which it's prepended to: Raindown's rain cloud over the whole screen while the Navigator's
    # made in another thread, like while Rouge loads.
    module Loading
      private

      def start
        super
        loading = Thread.new(&@loading)
        loading.report_on_exception = false
        rain_until(loading)
        @navigator = loading.value
      end

      # The rain cloud, a frame each animation tick, until the thread's done.
      def rain_until(thread)
        scene = Scene.new(width: Curses.cols, height: Curses.lines, animations: [Cloud])
        tick = 0
        loop do
          draw(scene.lines(tick))
          break if thread.join(Screen::TICKS[:animation] / 1000.0)

          tick += 1
        end
      end
    end
  end
end
