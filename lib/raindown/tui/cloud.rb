# frozen_string_literal: true

require 'zlib'

module Raindown
  module TUI
    # Raindown's logo, raindown.dev's rain cloud, in the middle of the screen while the terminal UI loads: bumps and a
    # rounded base of blocks, each its own blue, lighter at the top, with a few corrupted, and rain falling from under it
    # to the bottom of the screen, fading and thinning out as it goes:
    #                   ███████████████▞███▄██████████
    #                    ██████████████████████████
    #                   ╎╎,┊ '  ,   ┊ ┊ '   ┊' ╎,
    #                ╎  │ ││ ,  │   │ , '   ' ┊,
    # It's drawn like the site's RainCloud, with the same seed, so it's the same cloud, in the nearest of the 256 colours
    # most terminals have.
    class Cloud
      WIDTH = 50
      ROWS = 19
      SEED = 5
      # Bumps as [column, row, radius], and the base under them, with its corners rounded. Rows are stretched, as
      # characters are taller than they're wide.
      BUMPS = [[25, 8, 11], [13, 12, 7.5], [37, 11, 8.5]].freeze
      BASE_ROWS = 12..18
      BASE_COLUMNS = 7..43
      CORNER = 5
      ROW_STRETCH = 1.7
      SHADES = %w[█ ▓].freeze
      CORRUPT = %w[▀ ▄ ▚ ▞ ▌ ▐].freeze
      CORRUPTED = 0.015
      RAIN = %w[│ ╎ ┊ ' ,].freeze
      # The rain's blue, as hue, saturation and lightness, which fades in steps as it falls, and thins out.
      RAIN_BLUE = [212, 100, 70].freeze
      RAIN_STEPS = 8
      FADE = 0.11
      # The levels of red, green and blue in the 256 colours' cube, from 16 to 231, leaving out the greys after it, so
      # the rain stays blue as it fades.
      CUBE = [0, 95, 135, 175, 215, 255].freeze
      XTERM = (16..231).to_h { [it, CUBE.values_at((it - 16) / 36, ((it - 16) / 6) % 6, (it - 16) % 6)] }.freeze

      class << self
        # Each cell inside the cloud, by its row and column, as its block and its blue's style.
        def cells = drawing.first

        # The columns it rains from.
        def rainy = drawing.last

        # The rain's style at each step, from just under the cloud to the bottom of the screen.
        def rain_styles
          @rain_styles ||= Array.new(RAIN_STEPS) { |step| style(rgb(*RAIN_BLUE).map { (it * (1 - (step * FADE))).round }) }
        end

        # Every blue it's drawn in, for the screen's colours.
        def styles = (cells.values.map(&:last) + rain_styles).uniq

        private

        # Rolled in the site's order, a cell at a time, then the rainy columns.
        def drawing
          @drawing ||= begin
            random = Random.new(SEED)
            cells = ROWS.times.to_a.product(WIDTH.times.to_a).select { inside?(*it) }.to_h { [it, cell(it.first, random)] }
            [cells, ((BASE_COLUMNS.begin + 1)..(BASE_COLUMNS.end - 1)).select { random.rand < 0.6 }]
          end
        end

        # A corrupted block now and then, and otherwise a shade, denser towards the bottom, with some noise.
        def cell(row, random)
          return [CORRUPT.sample(random:), blue(row, random)] if random.rand < CORRUPTED

          depth = (row / ROWS.to_f) + random.rand(-0.25..0.25)
          [SHADES[(1 - (depth * 2)).round.clamp(0, 1)], blue(row, random)]
        end

        # A random blue, lighter at the top of the cloud and darker at the bottom.
        def blue(row, random)
          light = (82 - (row * 2.4) + random.rand(-12..12)).round.clamp(25, 90)
          style(rgb(random.rand(198..235), random.rand(65..100), light))
        end

        # The style of the nearest of the 256 colours.
        def style(rgb) = :"cloud_#{XTERM.min_by { |_, color| color.zip(rgb).sum { (it[0] - it[1])**2 } }.first}"

        def rgb(hue, saturation, lightness)
          saturation /= 100.0
          lightness /= 100.0
          chroma = saturation * [lightness, 1 - lightness].min
          [0, 8, 4].map do |offset|
            k = (offset + (hue / 30.0)) % 12
            ((lightness - (chroma * [[k - 3, 9 - k, 1].min, -1].max)) * 255).round
          end
        end

        def inside?(row, column)
          BUMPS.any? { |x, y, radius| ((column - x)**2) + (((row - y) * ROW_STRETCH)**2) <= radius**2 } || base?(row, column)
        end

        def base?(row, column)
          return false unless BASE_ROWS.cover?(row) && BASE_COLUMNS.cover?(column)

          corner_row, corner_column = corner(row, column)
          ((column - corner_column)**2) + (((row - corner_row) * ROW_STRETCH)**2) <= CORNER**2
        end

        # The nearest point to the cell that's a corner's radius in from the base's edges, where its corners curve in
        # from, reaching at most halfway up the base.
        def corner(row, column)
          inset = [CORNER / ROW_STRETCH, (BASE_ROWS.end - BASE_ROWS.begin) / 2.0].min
          [row.clamp(BASE_ROWS.begin + inset, BASE_ROWS.end - inset), column.clamp(BASE_COLUMNS.begin + CORNER, BASE_COLUMNS.end - CORNER)]
        end
      end

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
        @left = (width - WIDTH) / 2
        @top = [(height - ROWS) / 3, 0].max
      end

      # Draws the cloud and its rain at the tick into a Scene's cells.
      def draw(cells, tick)
        self.class.cells.each { |(row, column), (block, style)| put(cells, row, column, block, style) }
        rain(cells, tick)
      end

      private

      # Drops in the rainy columns, moving down a row a tick, fading and thinning out in steps below the cloud.
      def rain(cells, tick)
        falling = height - @top - ROWS
        falling.times do |below|
          step = below * RAIN_STEPS / falling
          self.class.rainy.each { |column| drop(cells, column, below - tick, ROWS + below, step) }
        end
      end

      # The drop in the column at the row, if there's one there at the tick, from a checksum of where it is in the rain.
      def drop(cells, column, falling, row, step)
        drop = Zlib.crc32("#{column} #{falling}")
        return unless (drop % 100) < 90 - (step * 9)

        put(cells, row, column, RAIN[drop % RAIN.length], self.class.rain_styles[step])
      end

      # The cell at the cloud's row and column, where it's on the screen.
      def put(cells, row, column, char, style)
        row += @top
        column += @left
        cells[row][column] = [char, style] if row.between?(0, height - 1) && column.between?(0, width - 1)
      end
    end
  end
end
