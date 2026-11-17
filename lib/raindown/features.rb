# frozen_string_literal: true

require 'plugs'

module Raindown
  # What an edition can have, each loading its files the first time an edition that has it asks for it, so one that
  # hasn't never loads them. Components are found in the order they're here: Ruby, then JavaScript, then Markdown.
  class Features
    include Plugs

    # Write-in nodes, in <{ }>, like <{ Card }>, <{ :toc }> or <{ Card: }>...<{ :Card }>, rendered in the template pass.
    plug(:write_in) do
      plug(:lexeme) do
        lazy do
          require_relative '../lexemes/node_lexeme'
          NodeLexeme
        end
      end

      # A list: block loops over its files, so it comes before other nodes' blocks.
      plug(:node) do
        lazy do
          require_relative '../nodes/list_node'
          ListNode
        end
      end

      plug(:node) do
        lazy do
          require_relative '../nodes/write_in_node'
          WriteInNode
        end
      end

      plug(:node) do
        lazy do
          require_relative '../nodes/write_in_node'
          SoloWriteInNode
        end
      end
    end

    plug(:code_components) do
      plug(:components) do
        lazy do
          require_relative 'ruby_nodes'
          RubyNodes
        end
      end

      plug(:components) do
        lazy do
          require_relative 'js/js_nodes'
          JSNodes
        end
      end
    end

    plug(:markdown_components) do
      plug(:components) do
        lazy do
          require_relative 'markdown_nodes'
          MarkdownNodes
        end
      end
    end

    # Raindown's own nodes, like toc:, each loaded the first time a note names it.
    plug(:built_ins) do
      lazy { Nodes::BUILT_INS }
    end

    # A project's notes, which list: lists and wiki links link to, listed with Dirload.
    plug(:pages) do
      lazy { Pages }
    end

    plug(:endpoints) do
      plug(:endpoint_runner) do
        lazy do
          require_relative 'endpoint/endpoint_runner'
          EndpointRunner
        end
      end

      plug(:lexeme) do
        lazy do
          require_relative '../lexemes/endpoint_lexeme'
          EndpointLexeme
        end
      end

      plug(:node) do
        lazy do
          require_relative '../nodes/endpoint_node'
          EndpointNode
        end
      end
    end

    # Schemas, like schema: User, which endpoints check responses against.
    plug(:schemas) do
      plug(:schema_block) do
        lazy do
          require_relative 'endpoint/schema_block'
          SchemaBlock
        end
      end
    end

    # Lining up tables' columns as a note's written back.
    plug(:tables) do
      plug(:table_formatter) do
        lazy do
          require_relative 'table/table_formatter'
          TableFormatter
        end
      end
    end
  end
end
