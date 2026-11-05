# frozen_string_literal: true

require_relative 'code_blocks'
require_relative 'directives'
require_relative 'endpoint/schema_block'
require_relative 'front_matter'

module Raindown
  # Raindown files (.rd/.raindown) can write a content directive, which writes its output back, bare on its own line,
  # like endpoint: or toc:, which shows in bold in the HTML. Markdown files opt in with "raindown: true" in their front
  # matter, or with the --bare flag. Nodes like toc: and files: are handled by NodeBlocks, before the rest.
  # Template directives, like if: and for:, are always in Antlers' delimiters, so they're never bare.
  #
  # A bare schema: shows in bold, with its fields in a code block below it.
  #
  # Bare directives have no end tag. A bare endpoint holds the lines straight below it, its curl snippet, the comment
  # with its response's status, time and date, and its response, up to the next blank line, like a bare node block, so
  # where it needs blank lines, write it in comments with an end tag instead:
  #   <!-- endpoint: -->
  #   ...
  #   <!-- :endpoint -->
  module BareDirectives
    EXTENSIONS = %w[.rd .raindown].freeze
    # A bare endpoint, the one bare directive with a block. Four spaces of indent would make the line a Markdown code
    # block.
    LINE = /\A( {0,3})(endpoint:(?:[ \t]+\S.*?)?)[ \t]*$/

    module_function

    def enabled?(path: nil, content: nil, bare: false)
      bare || file?(path) || front_matter?(content)
    end

    def file?(path)
      return false if path.nil?

      EXTENSIONS.include?(File.extname(path).downcase)
    end

    # Whether the front matter has "raindown: true". Front matter that isn't valid YAML fails when the file renders,
    # so here it only means no.
    def front_matter?(content)
      return false unless content&.start_with?('---')

      FrontMatter.parse(content).first[:raindown] == true
    rescue Psych::Exception
      false
    end

    # Wrap each bare directive in Antlers delimiters and close its block, leaving code and front matter as-is.
    def expand(content)
      lines = content.lines
      index = FrontMatter.line_count(lines)

      while index < lines.length
        block = CodeBlocks.at(lines, index)
        index = (block ? block[:close] : expand_line(lines, index)) + 1
      end

      lines.join
    end

    # The directive in Antlers delimiters, or nil when the line isn't a bare directive.
    def wrap(line)
      line.sub(LINE) { "#{::Regexp.last_match(1)}<{ #{::Regexp.last_match(2)} }>" } if line.match?(LINE)
    end

    # Returns the index of the last line it handled. That's the directive itself, so the lines it holds
    # are expanded too, and a bare directive inside it closes before it does.
    def expand_line(lines, index)
      schema = SchemaBlock.at(lines, index, bare: true)
      return expand_schema(lines, index, schema) if schema

      match = lines[index].match(LINE)
      return index unless match

      lines[index] = "#{Directives.marker(match[2], shown: true)}\n#{wrap(lines[index])}"
      close_block(lines, index, indent: match[1])
      index
    end

    # Returns the index of the code block's last line.
    def expand_schema(lines, index, schema)
      indent = schema.fields.first.to_s[/\A[ \t]*/]
      block = [Directives.marker(lines[index], shown: true), "\n```\n", *schema.fields.map { it.delete_prefix(indent) }, "```\n"]
      lines[index..schema.last] = block
      index + block.length - 1
    end

    # The end tag after the block, then the end tag in bold, as a bare directive's shown.
    def close_block(lines, index, indent:)
      last = CodeBlocks.last_before_blank(lines, index)
      lines[last] = "#{lines[last]}\n" unless lines[last].end_with?("\n")
      lines.insert(last + 1, "#{indent}<{ :endpoint }>\n#{Directives.marker(':endpoint', shown: true)}\n")
    end
  end
end
