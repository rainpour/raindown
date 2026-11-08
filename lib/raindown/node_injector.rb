# frozen_string_literal: true

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'node_blocks'

module Raindown
  # Writes each node block's Markdown below its directive, replacing what it wrote before, when it's in comments or
  # bare. Ones in Antlers' delimiters, and self-closing ones, only render, so they're left alone.
  class NodeInjector
    class BlankLine < StandardError; end

    # Rewriter interface. Content without a node block is returned unchanged.
    def self.rewrite(content:, path: nil, bare: false, metadata: NoMetadata, **)
      new(content:, path:, bare:, metadata:).call
    end

    # Warnings for the directives that couldn't run, written in their place, each with its line, like
    # "line 6: toc: takes no value".
    attr_reader :problems

    def initialize(content:, path: nil, bare: false, metadata: NoMetadata)
      @content = content
      @problems = []
      @bare = BareDirectives.enabled?(path:, content:, bare:)
      @metadata = metadata
    end

    def call
      lines = @content.lines
      blocks = NodeBlocks.find(lines, front_matter: FrontMatter.parse(@content).first, bare: @bare)
                         .select { |block| block[:writes] }
      return @content if blocks.empty?

      # From the bottom up, so the lines above each block stay where they are, so its problems are put back in order.
      blocks.reverse_each { |block| lines[block[:open]..block[:last]] = block_lines(lines, block) }
      @problems.reverse!
      lines.join
    end

    private

    def block_lines(lines, block)
      context = { document: @content, metadata: @metadata, bare: @bare, written: written_lines(lines, block) }
      markdown = node_markdown(block, context)
      written = markdown.empty? ? [] : "#{markdown}\n".lines
      return [line(lines[block[:open]]), *bare(written, block)] unless block[:close]

      delimited(lines, block, written)
    end

    # A node that raises writes why in its place, like a Problem, so the rest of the file still writes back.
    def node_markdown(block, context)
      @problems << block[:node].warning if block[:node].is_a?(Problem)
      Nodes.call(block[:node], :rewrite, **context).to_s.chomp
    rescue StandardError => e
      problem = Problem.new("Couldn't write: #{e.message}", block[:open] + 1)
      @problems << problem.warning
      problem.rewrite
    end

    # The directive, what the node wrote and the end tag, straight after each other, as a comment on its own line ends
    # at its -->, so what's written below it, like a list, is its own block.
    def delimited(lines, block, written) = [line(lines[block[:open]]), *written, line(lines[block[:close]])]

    # A bare block ends at the next blank line, so what it writes can't have one.
    def bare(written, block)
      return written unless written.any? { |line| line.strip.empty? }

      name = block[:node].class.name
      raise BlankLine, "#{name} writes blank lines, so it needs <!-- #{name}: --> and <!-- :#{name} --> around it"
    end

    # What the block's node wrote last time, between its directive and its end tag, or the next blank line.
    def written_lines(lines, block)
      lines[(block[:open] + 1)...(block[:close] || (block[:last] + 1))]
    end

    def line(line)
      line.end_with?("\n") ? line : "#{line}\n"
    end
  end
end
