# frozen_string_literal: true

require_relative '../../text'
require_relative '../waffle/waffle'
require_relative 'scene'

module Raindown
  module TUI
    # A Celebration over the whole screen, in place of the Layout: rain and fireworks, then a waffle popping out, among
    # confetti, balloons and sparkles.
    CelebrationRenderer = Struct.new(:celebration, :width, :height) do
      include Text
      include Waffle

      def lines
        return Scene.new(width:, height:).lines(celebration.frame) if celebration.raining?

        waffle(Scene.new(width:, height:, animations: [Confetti, Balloons, Sparkles]).lines(celebration.popping), celebration.popping)
      end
    end
  end
end
