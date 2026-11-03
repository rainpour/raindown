# frozen_string_literal: true

require_relative '../raindown'
require_relative 'rewriter'

module Raindown
  # What an editor asks of Raindown about Markdown it's editing, which needn't be saved: its HTML, or the Markdown as it
  # would be written back to the file, with its failed endpoint checks. "raindown FILE --stdin" and "raindown server"
  # both answer with it.
  module Editing
    module_function

    def render_markdown(markdown, path:, bare: false)
      Nodes.load(path)
      Raindown.render(markdown:, metadata: Pages.for(path), bare: bare || BareDirectives.file?(path), **Config.render_options(path))
    end

    def rewrite_markdown(markdown, path:, bare: false, execute: false)
      Nodes.load(path)
      rewritten = Rewriter.rewrite(content: markdown, path:, bare:, execute:, metadata: Pages.for(path))
      { output: rewritten, warnings: EndpointRunner.failures(content: rewritten, path:, bare:).map { "Endpoint check failed: #{it}" } }
    end
  end
end
