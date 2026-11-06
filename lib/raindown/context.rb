# frozen_string_literal: true

require_relative 'front_matter'
require_relative 'variables'

module Raindown
  # The document being rendered, its metadata, like a site's pages, and whether its directives can be bare: the keywords
  # a node's rewrite and render can take. Antlers passes it down to Raindown's own Antlers nodes.
  Context = Data.define(:document, :metadata, :bare) do
    def initialize(document: '', metadata: NoMetadata, bare: false)
      super
    end

    # The document's front matter, as variables, like {title}.
    def variables
      Variables.new(FrontMatter.parse(document).first)
    end
  end
end
