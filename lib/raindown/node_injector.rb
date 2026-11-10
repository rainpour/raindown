# frozen_string_literal: true

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'node_blocks'
require_relative 'written'

module Raindown
  # Writes each node block's Markdown below its directive, replacing what it wrote before, when it's in comments or
  # bare. Ones in Antlers' delimiters, and self-closing ones, only render, so they're left alone.
  class NodeInjector
    class BlankLine < StandardError; end

    # A comment on its own line that isn't a directive, like <!-- 2 rows · 3f2a9c -->, which straight below a directive
    # is its node's comment, passed to its rewrite as comment:.
    COMMENT = /\A\s*<!--(?!\s*(?::[A-Za-z]|[A-Za-z][\w-]*(?:::[A-Z]\w*)*:))\s*(.*?)\s*-->\s*\z/

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
      comment, written = comment_and_written(written_lines(lines, block))
      # The document as it's written so far, from the bottom up, so a node sees what the nodes below it just wrote, like
      # the TOC the headings they write.
      context = { document: lines.join, metadata: @metadata, bare: @bare, comment:, written: }
      written = written_lines_of(node_written(block, context))
      return [line(lines[block[:open]]), *bare(written, block)] unless block[:close]

      delimited(lines, block, written)
    end

    # A node that raises writes why in its place, like a Problem, so the rest of the file still writes back.
    def node_written(block, context)
      @problems << block[:node].warning if block[:node].is_a?(Problem)
      written = Nodes.call(block[:node], :rewrite, **context)
      return written if written.is_a?(Written)

      Written.new(written.to_s)
    rescue StandardError => e
      problem = Problem.new("Couldn't write: #{e.message}", block[:open] + 1)
      @problems << problem.warning
      Written.new(problem.rewrite)
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

    # Its lines: its comment, straight below its directive, then its Markdown.
    def written_lines_of(written)
      markdown = written.to_s.chomp
      lines = markdown.empty? ? [] : "#{markdown}\n".lines
      return lines unless written.comment

      ["<!-- #{written.comment} -->\n", *lines]
    end

    # The comment the block's node wrote straight below its directive, if it wrote one, and the lines it wrote below that.
    def comment_and_written(lines)
      return [nil, lines] unless lines.first&.match?(COMMENT)

      [lines.first[COMMENT, 1], lines.drop(1)]
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
