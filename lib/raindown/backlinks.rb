# frozen_string_literal: true

require_relative 'node'
require_relative 'utils'
require_relative 'wiki_links'

module Raindown
  # The node behind backlinks:, a list of links to the files whose [[wikilinks]] link to this one, like Obsidian's
  # backlinks, written into the file so they show wherever it's read.
  class Backlinks < Node
    def replace(metadata: NoMetadata)
      current = metadata.current
      return '' unless current

      linking(current, metadata.list).map { |page| "- [#{page.title || page.path}](<#{page.path}>)" }.join("\n")
    end

    private

    def linking(current, pages)
      pages.select { |page| page.file_path != current.file_path && links_to?(page, current, pages) }
    end

    def links_to?(page, current, pages)
      WikiLinks.links(Utils.read_markdown(page.file_path)).any? do |link|
        WikiLinks.page_for(link[1], pages)&.file_path == current.file_path
      end
    end
  end
end
