# frozen_string_literal: true

require 'raindown/node'
require 'raindown/written'

# Nodes for the node specs. Real projects keep theirs in a .raindown folder, as LowNodes.
class SpecReleases < Raindown::Node
  RELEASES = [%w[1.2.0 Bare], %w[1.1.0 Fetched], %w[1.0.0 First]].freeze

  def initialize(limit: 5)
    @releases = RELEASES.first(limit)
    @count = 0
  end

  def rewrite
    @releases.map { |version, summary| "- **#{version}** #{summary}" }.join("\n")
  end

  # Counts its renders, to show the same instance renders each time.
  def render
    @count += 1
    "<ol data-count=\"#{@count}\">#{@releases.map { |version, _| "<li>#{version}</li>" }.join}</ol>"
  end
end

# A node with no HTML of its own, so its Markdown renders.
class SpecHeading < Raindown::Node
  def initialize(title: 'Untitled')
    @title = title
  end

  def rewrite
    "## #{@title}"
  end
end

# A node that writes two paragraphs, which only fit in a delimited block.
class SpecParagraphs < Raindown::Node
  def rewrite
    "One.\n\nTwo."
  end
end

# A node that wraps the Markdown between its tags in <{ }>, and fails if it's ever asked to write back there.
class SpecWrapper < Raindown::Node
  def rewrite = raise('rewrite is only for writing back')

  def render(slot:)
    "<aside>#{slot}</aside>"
  end
end

# A node that takes edits to what it wrote, like Table, but has no render of its own, so it can't be write-in.
class SpecSynced < Raindown::Node
  def rewrite(written: [])
    raise "rewrite wrote back #{written}"
  end
end

# A node counting how many times it's written in its comment, straight below its directive.
class SpecRuns < Raindown::Node
  def rewrite(comment: nil)
    Raindown::Written.new('Ran.', comment: "run #{comment.to_s[/\d+/].to_i + 1}")
  end
end
