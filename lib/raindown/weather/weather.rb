# frozen_string_literal: true

require 'cgi/escape'
require_relative '../config'
require_relative '../node'
require_relative 'branch_tree'

module Raindown
  # The node behind weather:, a project's forecast, which apps draw a sky behind, like over a valley in the app. In a
  # code project, it's the branches that aren't merged into main, and the branches off them, by when they were made:
  #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #   < weather:
  #   < Nov 10 login  ->  Nov 11 login-tests
  #   <                   Nov 12 search  ->  Nov 12 search-filters
  # A notes project's forecast is still to come, so it writes nothing yet.
  class Weather < Node
    def rewrite(metadata: NoMetadata)
      root = root(metadata)
      return '' unless Config.kind(root) == 'code'

      BranchTree.new(root).lines.join("\n")
    end

    # Its lines as they're written, keeping their spaces, so each branch stays where it was drawn.
    def render(metadata: NoMetadata)
      %(<pre class="weather">#{CGI.escapeHTML(rewrite(metadata:))}</pre>)
    end

    private

    # The project's folder, from the page being written, or else the current one.
    def root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end
  end
end
