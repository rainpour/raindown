# frozen_string_literal: true

module Raindown
  # The pixels a node paints behind its text in an app that draws pixels, from its rasterize, painted in Ruby, so it
  # needs nothing else: a colour for each pixel, across then down, as 0xRRGGBB. An app draws them under the text, a
  # pixel each of its own, and asks again when their size or the text changes. A node the app paints returns a Scene.
  class Raster
    attr_reader :width, :height, :pixels

    def initialize(width, height)
      @width = width
      @height = height
      @pixels = Array.new(width * height, 0)
    end

    def []=(x, y, color)
      x = x.round
      y = y.round
      @pixels[(y * @width) + x] = color if x >= 0 && y >= 0 && x < @width && y < @height
    end

    # The pixels as bytes, red, green, blue and alpha for each, for an app to draw.
    def to_bytes
      @pixels.map { (it << 8) | 0xff }.pack('N*')
    end

    # For an app, its pixels' bytes in Base64, to copy in as they are.
    def to_h = { painter: 'pixels', width:, height:, pixels: [to_bytes].pack('m0') }
  end
end
