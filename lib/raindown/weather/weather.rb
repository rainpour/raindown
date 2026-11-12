# frozen_string_literal: true

require 'cgi/escape'
require_relative '../config'
require_relative '../node'
require_relative '../scene'
require_relative 'branch_tree'

module Raindown
  # The node behind weather:, a project's forecast, which apps draw a sky behind, like over a valley in the app. In a
  # code project, it's the branches that aren't merged into main, and the branches off them, by when they were made:
  #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #   < weather:
  #   < login · 4 commits
  #   <     -> login-tests · 2 commits
  # A notes project's forecast is still to come, so it writes nothing yet. In an app that draws pixels, it shows a
  # valley behind its text, by day or by night, with a constellation for each branch, a star a commit, which the app
  # paints itself, from the branches it gives it.
  class Weather < Node
    # How long its branches are kept, as an app asks for its sky about once a second.
    FRESH_FOR = 5

    def rewrite(metadata: NoMetadata)
      branches(metadata).map(&:to_s).join("\n")
    end

    # Its valley, with its branches' names and commits for their constellations, at any size, which the app paints.
    def rasterize(metadata: NoMetadata, **)
      Scene.new(name: 'valley', data: { branches: branches(metadata).map { { name: it.name, commits: it.commits } } })
    end

    # The characters of its lines an app dims, so its branches' names stand out: each line's arrow and count, as
    # [line, from, to], its lines counted from the first it writes.
    def quiet(metadata: NoMetadata)
      spans = branches(metadata).each_with_index.flat_map do |branch, line|
        from = branch.indent + branch.arrow.length
        [[line, branch.indent, from], [line, from + branch.name.length, branch.to_s.length]]
      end
      spans.reject { |_, from, to| from == to }
    end

    # Its lines as they're written, keeping their spaces, so each branch stays where it was drawn.
    def render(metadata: NoMetadata)
      %(<pre class="weather">#{CGI.escapeHTML(rewrite(metadata:))}</pre>)
    end

    private

    # Its branches, found again once they're FRESH_FOR seconds old, or none in a notes project.
    def branches(metadata)
      root = root(metadata)
      return [] unless Config.kind(root) == 'code'

      found_at, branches = @branches
      return branches if found_at && Time.now - found_at < FRESH_FOR

      BranchTree.new(root).branches.tap { @branches = [Time.now, it] }
    end

    # The project's folder, from the page being written, or else the current one.
    def root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end
  end
end
