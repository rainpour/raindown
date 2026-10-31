# frozen_string_literal: true

require_relative 'stat'

module Raindown
  # The node behind wormholes:, a stat of how many links in the project's Markdown files lead nowhere, labelled like
  # "3 wormholes":
  #   <{ wormholes: }>
  # A project can count them its own way with its own WormholeCount node, like "class WormholeCount < Raindown::WormholeCount".
  class WormholeCount < Stat
    # Card lines ask for the value before the label, which says it. Wormholes are read from Documents, which need
    # the rest of Raindown, so they're only required once they're counted.
    def value(metadata: NoMetadata)
      require_relative 'wormholes'
      @count = Wormholes.new(root(metadata)).all.length
    end

    # Like "1 wormhole" or "3 wormholes".
    def self.label(count)
      return '1 wormhole' if count == 1

      "#{count} wormholes"
    end

    def label = self.class.label(@count)
  end
end
