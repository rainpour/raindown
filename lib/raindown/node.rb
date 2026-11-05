# frozen_string_literal: true

module Raindown
  # The base class of Raindown's own nodes, like TOC and Files.
  # A project's nodes are LowNodes, or subclasses of these.
  class Node
    # Written in, in <{ }>, a node renders its Markdown as HTML. A node whose replace writes more than Markdown, like
    # Table writing to its file, renders without it.
    def render(**context)
      Raindown.commonmark(Nodes.call(self, :replace, **context).to_s)
    end
  end
end
