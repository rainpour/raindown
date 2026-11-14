# frozen_string_literal: true

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'node_blocks'
require_relative 'outdent'
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
      @ahead = {}
    end

    # Outdented blocks' directives are written first, then the rest of the file's.
    def call
      front_matter = FrontMatter.parse(@content).first
      outdented = Outdent.rewrite(@content) { |content, range| write(content, front_matter:, within: range) }
      write(outdented, front_matter:)
    end

    private

    # Writes the blocks whose directives are within the range of lines, or all of them.
    def write(content, front_matter:, within: nil)
      lines = content.lines
      blocks = NodeBlocks.find(lines, front_matter:, bare: @bare).select do |block|
        block[:writes] && (within.nil? || within.cover?(block[:open]))
      end
      return content if blocks.empty?

      @ahead = written_ahead(lines, blocks)
      # From the bottom up, so the lines above each block stay where they are, so its problems are put back in order.
      problems = @problems
      @problems = []
      blocks.reverse_each { |block| lines[block[:open]..block[:last]] = block_lines(lines, block) }
      @problems = problems + @problems.reverse
      lines.join
    end

    def block_lines(lines, block)
      written = written_lines_of(node_written(block, context_of(lines, block)))
      return [*directive(lines, block), *bare(written, block)] unless block[:close]

      delimited(lines, block, written)
    end

    # The document as it's written so far, from the bottom up, so a node sees what the nodes below it just wrote, like
    # the TOC the headings they write.
    def context_of(lines, block)
      comment, written = comment_and_written(Problem.without_alert(written_lines(lines, block)))
      { document: lines.join, metadata: @metadata, bare: @bare, comment:, written: }
    end

    # What the JavaScript nodes among the blocks write, by each block's line, asked of their host together, as a request
    # costs about as much as a node. So they see the document as it was before the blocks wrote, not what the nodes
    # below them just wrote. A host that can't be asked leaves each to be asked alone, to say why in its place.
    def written_ahead(lines, blocks)
      ahead = blocks.select { it[:node].is_a?(JSNode) }
      calls = ahead.map { it[:node].call_for(:rewrite, context_of(lines, it)) }
      ahead.map { it[:open] }.zip(JSNodes.call(calls)).to_h
    rescue JSNodes::Error
      {}
    end

    # A node that raises writes why in its place, like a Problem, so the rest of the file still writes back.
    def node_written(block, context)
      @problems << block[:node].warning if block[:node].is_a?(Problem)
      written = written_by(block, context)
      return written if written.is_a?(Written)

      Written.new(written.to_s)
    rescue StandardError => e
      problem = Problem.new("Couldn't write: #{e.message}", block[:open] + 1)
      @problems << problem.warning
      Written.new(problem.rewrite(written: context[:written]))
    end

    # What the block's node writes, as it was asked ahead, or asked now.
    def written_by(block, context)
      output = @ahead.fetch(block[:open]) { return Nodes.call(block[:node], :rewrite, **context) }
      raise output if output.is_a?(JSNodes::Error)

      output
    end

    # The directive, what the node wrote and the end tag, straight after each other, as a comment on its own line ends
    # at its -->, so what's written below it, like a list, is its own block.
    def delimited(lines, block, written) = [*directive(lines, block), *written, line(lines[block[:close]])]

    # Its directive's line, or none for a bare grid, which has none.
    def directive(lines, block) = lines[block[:open]...block[:first]].map { line(it) }

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
      lines[block[:first]...(block[:close] || (block[:last] + 1))]
    end

    def line(line)
      line.end_with?("\n") ? line : "#{line}\n"
    end
  end
end
