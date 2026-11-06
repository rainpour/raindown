# frozen_string_literal: true

require 'plugs'

module Raindown
  class Elements
    include Plugs

    # Write-in nodes, in <{ }>, like <{ Card }>, <{ :toc }> or <{ Card: }>...<{ :Card }>, rendered in the template pass.
    plug(:write_in) do
      plug(:lexeme) do
        require_relative 'lexemes/node_lexeme'
        NodeLexeme
      end

      # A list: block loops over its files, so it comes before other nodes' blocks.
      plug(:node) do
        require_relative 'nodes/list_node'
        ListNode
      end

      plug(:node) do
        require_relative 'nodes/write_in_node'
        WriteInNode
      end

      plug(:node) do
        require_relative 'nodes/write_in_node'
        SoloWriteInNode
      end
    end

    plug(:endpoint) do
      plug(:lexeme) do
        require_relative 'lexemes/endpoint_lexeme'
        EndpointLexeme
      end

      plug(:node) do
        require_relative 'nodes/endpoint_node'
        EndpointNode
      end
    end
  end
end
