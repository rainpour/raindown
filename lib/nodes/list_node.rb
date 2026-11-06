# frozen_string_literal: true

require 'antlers/api'
require_relative '../raindown/context'
require_relative '../raindown/node_blocks'
require_relative '../raindown/nodes'
require_relative 'write_in_node'

module Raindown
  # <{ list: page folder: 'notes' }> ... <{ :list }>, which renders its template for each file the list: node lists,
  # with the file as page. Without a block, <{ :list folder: 'notes' }> renders the node's links, as a WriteInNode.
  class ListNode < Antlers::BranchNode
    DEF_KEY = :node_def
    END_KEY = :node_end

    def initialize(name:, args:)
      super(name:)

      @variable, @tags = args.split(/\s+/, 2)
    end

    def render(current_binding: nil, context: Context.new, **)
      tags = NodeBlocks.props(@tags.to_s, BoundVariables.new(current_binding))
      Nodes.instance(Nodes.node_class('list'), tags).files(metadata: context.metadata).map do |file|
        current_binding.local_variable_set(@variable, file)
        super
      end.join
    end

    def end_name
      'list'
    end

    class << self
      def match?(segment:)
        segment[DEF_KEY] == 'list'
      end

      def build(segment:, **)
        new(name: :list, args: segment[:args])
      end
    end
  end
end
