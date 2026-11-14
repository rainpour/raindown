# frozen_string_literal: true

require_relative '../raindown'
require_relative 'rewriter'

module Raindown
  # What an editor asks of Raindown about Markdown it's editing, which needn't be saved: its HTML, or the Markdown as it
  # would be written back to the file, with its failed endpoint checks. "raindown FILE --stdin" and "raindown server"
  # both answer with it.
  module Editing
    module_function

    # Without commonmark, it's Markdown, for the editor to render itself.
    def render_markdown(markdown, path:, bare: false, commonmark: true)
      Nodes.load(path)
      Raindown.render(markdown:, metadata: Pages.for(path), bare: bare || BareDirectives.file?(path), commonmark:,
                      **Config.render_options(path))
    end

    # Its warnings say why any of the project's nodes couldn't be loaded too.
    def rewrite_markdown(markdown, path:, bare: false, execute: false)
      load_errors = Nodes.load(path)
      rewrite = Rewriter.rewrite(content: markdown, path:, bare:, execute:, metadata: Pages.for(path))
      failures = rewrite.failures.map { "Endpoint check failed: #{it}" }
      { output: rewrite.content, warnings: load_errors + failures + rewrite.problems }
    end
  end
end
