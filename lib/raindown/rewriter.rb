# frozen_string_literal: true

require_relative 'node_injector'
require_relative 'endpoint/endpoint_runner'
require_relative 'table/table_formatter'
require_relative 'utils'

module Raindown
  # Rewrites the generated parts of a Markdown file in place before it's rendered:
  # node output, like the TOC, endpoint responses and table alignment.
  module Rewriter
    # The content written back, and the endpoint checks it failed, like "api.md:3: expected status 200, received 404".
    Rewrite = Data.define(:original, :content, :failures) do
      def changed?
        content != original
      end
    end

    module_function

    def rewrite(content:, path:, bare: false, execute: false, metadata: NoMetadata)
      injected = NodeInjector.rewrite(content:, path:, bare:, metadata:)
      endpoints = EndpointRunner.new(content: injected, path:, bare: BareDirectives.enabled?(path:, content: injected, bare:), execute:)
      Rewrite.new(original: content, content: TableFormatter.rewrite(content: endpoints.rewrite), failures: endpoints.failures)
    end

    # Writes the file only when it changed.
    def update(path:, bare: false, execute: false, metadata: NoMetadata)
      rewrite(content: Utils.read_markdown(path), path:, bare:, execute:, metadata:).tap do |rewrite|
        File.write(path, rewrite.content) if rewrite.changed?
      end
    end
  end
end
