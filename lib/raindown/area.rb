# frozen_string_literal: true

module Raindown
  # The space a Ruby node paints behind its text in an app that draws pixels, given to its rasterize as area:, like a
  # JavaScript Component's, painted in Ruby: its width and height, in pixels, the time, where the text ends on each of
  # its rows, in pixels across, a character's width and height, as cell, its pixels, each set as 0xRRGGBB, one at a time
  # or all at once, and the buttons it's painted, which, clicked, change the props in set on its node's directive. Its
  # rasterize gives how many milliseconds until it's painted again, like a JavaScript one's, or nothing, for when its
  # size or text changes, which an app makes it wait longer for when painting it takes long, as each time is a trip
  # to Ruby and its pixels back. A pixel it doesn't set shows what's behind it.
  class Area
    attr_reader :width, :height, :time, :text_ends, :cell, :buttons

    def initialize(width:, height:, text_ends: [], cell: [8, 16], time: Time.now)
      @width = width
      @height = height
      @text_ends = text_ends
      @cell = cell
      @time = time
      @pixels = Array.new(width * height)
      @buttons = []
    end

    # A pixel, at whole pixels, so a node can give any point, as a pixel between two isn't one, and none outside it.
    def set_pixel(x, y, color)
      x = x.round
      y = y.round
      @pixels[(y * @width) + x] = color if x >= 0 && y >= 0 && x < @width && y < @height
    end

    # All its pixels at once, as 0xRRGGBB, across then down, width by height.
    def put_pixels(colors)
      @pixels = Array.new(@width * @height) { colors[it] }
    end

    # A rectangle it's painted a button, which, clicked, changes the props in set on its node's directive, like
    # { zoom: 8 }, as typing them there would, and only props the directive already has.
    def button(x:, y:, width:, height:, set:)
      @buttons << { x:, y:, width:, height:, set: }
    end

    # Its pixels as bytes, red, green, blue and alpha for each, those it didn't set clear.
    def to_bytes
      @pixels.map { it.nil? ? 0 : (it << 8) | 0xff }.pack('N*')
    end

    # For an app, its pixels' bytes in Base64, to copy in as they are, its buttons, and how many milliseconds until
    # it's painted again, if it said.
    def to_h(again = nil)
      { painter: 'pixels', width:, height:, pixels: [to_bytes].pack('m0'), buttons:, again: }
    end
  end
end
