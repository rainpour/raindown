# frozen_string_literal: true

module Raindown
  # What a product built on Raindown does with it, set before any note's written: Raindown itself, with its own nodes,
  # like toc: and table:, endpoints, tables lined up, and a project's Ruby, JavaScript and Markdown Components in its
  # .raindown folder, or Components, the Obsidian plugin for beginners, with only Markdown Components, in a vault's
  # Components folder, which Obsidian shows, and nothing else, so the rest of a note, like a table, stays as it's
  # written.
  class Edition
    attr_reader :folder

    def initialize(folder:, full:)
      @folder = folder
      @full = full
    end

    # Whether it has Raindown's own nodes, endpoints, tables lined up, and Ruby and JavaScript Components.
    def full?
      @full
    end

    FULL = new(folder: '.raindown', full: true)
    COMPONENTS = new(folder: 'Components', full: false)
  end

  class << self
    attr_writer :edition

    def edition
      @edition ||= Edition::FULL
    end
  end
end
