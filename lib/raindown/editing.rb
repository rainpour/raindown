# frozen_string_literal: true

require_relative '../raindown'
require_relative 'action'
require_relative 'rewriter'

module Raindown
  # What an editor asks of Raindown about Markdown it's editing, which needn't be saved: its HTML, or the Markdown as it
  # would be written back to the file, with its failed endpoint checks. "raindown FILE --stdin" and "raindown server"
  # both answer with it.
  module Editing
    # What an editor does at once in JavaScript, as Markdown's typed, as raindownEditing, like lining up tables, the
    # same as TableFormatter, and what Enter and Tab do in a table's cells, which the Obsidian plugin and the app share.
    SCRIPT = File.join(__dir__, 'js', 'editing.js')

    module_function

    # Without commonmark, it's Markdown, for the editor to render itself.
    def render_markdown(markdown, path:, bare: false, commonmark: true)
      Nodes.load(path)
      Raindown.render(markdown:, metadata: Raindown.edition.metadata(path), bare: bare || BareDirectives.file?(path), commonmark:,
                      **Config.render_options(path))
    end

    # Its warnings say why any of the project's nodes couldn't be loaded too. Each action an input took, like a button's,
    # as { line:, set: }, or with column: for a directive in a grid's cell, is taken first, as Action takes it.
    def rewrite_markdown(markdown, path:, bare: false, execute: false, actions: [])
      load_errors = Nodes.load(path)
      markdown = acted(markdown, actions, path:, bare:)
      rewrite = Rewriter.rewrite(content: markdown, path:, bare:, execute:, metadata: Raindown.edition.metadata(path))
      failures = rewrite.failures.map { "Endpoint check failed: #{it}" }
      { output: rewrite.content, warnings: load_errors + failures + rewrite.problems }
    end

    def acted(markdown, actions, path:, bare:)
      actions.reduce(markdown) do |text, action|
        Action.new(**action.transform_keys(&:to_sym)).apply(text, bare: BareDirectives.enabled?(path:, content: text, bare:))
      end
    end
  end
end
