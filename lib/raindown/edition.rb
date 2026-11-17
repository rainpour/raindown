# frozen_string_literal: true

require_relative 'features'

module Raindown
  # What a product built on Raindown does with it, set before any note's written, as the features it has: Raindown
  # itself, with all of them, and a project's components in its .raindown folder, or Components, the Obsidian plugin
  # for beginners, with only Markdown Components, in a vault's Components folder, which Obsidian shows, so the rest of a
  # note, like a table, stays as it's written. Only the features an edition has load.
  class Edition
    attr_reader :folder

    def initialize(folder:, features:)
      @folder = folder
      @features = Features[*features]
    end

    # What its features have of a kind, like components, loaded the first time they're asked for, and kept, as some are
    # asked for on each line.
    def plugs(key)
      @plugs ||= {}
      return @plugs[key] if @plugs.key?(key)
      return @plugs[key] = [] unless @features.key?(key)

      @plugs[key] = @features[key].to_a
    end

    # The notes list: lists and wiki links link to, beside the file, when it has them, or none.
    def metadata(path)
      pages = plugs(:pages).first
      return NoMetadata unless pages

      pages.for(path)
    end

    # Its write-in nodes' and endpoints' lexemes and nodes, for Antlers.
    def elements
      @features[:lexeme, :node]
    end

    FULL = new(folder: '.raindown', features: %i[write_in code_components markdown_components built_ins pages endpoints schemas tables])
    COMPONENTS = new(folder: 'Components', features: %i[write_in markdown_components])
  end

  class << self
    attr_writer :edition

    def edition
      @edition ||= Edition::FULL
    end
  end
end
