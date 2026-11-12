# frozen_string_literal: true

module Raindown
  # What a node shows behind its text in an app that draws pixels, from its rasterize, for the app to paint itself,
  # like weather:'s valley: the name of a painter the app has, like valley, and the data it paints, like branches.
  # A node that paints its own pixels returns a Raster instead.
  Scene = Data.define(:name, :data) do
    def to_h = { painter: name, data: }
  end
end
