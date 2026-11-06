# frozen_string_literal: true

module Raindown
  # The base class of Raindown's own nodes, like TOC and List.
  # A project's nodes are LowNodes, or subclasses of these.
  class Node
    # Write-in, in <{ }>, a node renders its Markdown as HTML. One whose rewrite takes written:, what it wrote last
    # time, can write edits back to its source, like Table to its file, so it needs its own render, which never does.
    def render(**context)
      raise Nodes::NoRender, "#{self.class.name} writes edits back, so it needs a render" if Nodes.takes?(self, :rewrite, :written)

      Raindown.commonmark(Nodes.call(self, :rewrite, **context).to_s)
    end
  end
end
