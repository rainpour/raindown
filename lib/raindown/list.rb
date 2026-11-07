# frozen_string_literal: true

require_relative 'node'

module Raindown
  # The node behind list:, the files the metadata has for its props, like list: folder: 'notes'. Bare or in comments it
  # writes a link to each, and in <{ list: page folder: 'notes' }> ... <{ :list }> it renders its template for each,
  # with the file as page, the name before its props, which is its argument. A project can change how files are listed
  # with its own List node in .raindown, like "class List < Raindown::List".
  class List < Node
    # Order is the metadata to sort by, like order: :created_at, rather than a tag to list by.
    def initialize(_name = nil, order: nil, **tags)
      @order = order
      @tags = tags
    end

    # Each file has its front matter, its path and its content. Sorted by an order, numbers come first, then other values
    # as text, then files without it, and ones with the same value stay in the order they're listed.
    def files(metadata: NoMetadata)
      files = metadata.list(**@tags)
      return files unless @order

      sorted, unsorted = files.partition { it[@order] }
      sorted.sort_by.with_index { |file, index| [*order_key(file[@order]), index] } + unsorted
    end

    def rewrite(metadata: NoMetadata)
      files(metadata:).map { |file| "- [#{file.title || File.basename(file.path, '.*')}](#{file.path})" }.join("\n")
    end

    private

    def order_key(value)
      return [0, value, ''] if value.is_a?(Numeric)

      [1, 0, value.to_s]
    end
  end
end
