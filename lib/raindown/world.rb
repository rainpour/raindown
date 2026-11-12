# frozen_string_literal: true

require_relative 'node'

module Raindown
  # The node behind world:, a map of the world, with the night where it is now, and the lights of its cities in the
  # dark, which an app that draws pixels paints like an image, as big as fits where it's written, keeping its shape:
  # alone on its line, over it and the blank lines below it, or in a grid's cell. It writes nothing into the file:
  #   world:
  #
  #   +-----------+-----------+
  #   | :world    | ![cat]    |
  #   +-----------+-----------+
  class World < Node
    def rewrite = ''
  end
end
