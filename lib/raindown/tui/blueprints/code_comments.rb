# frozen_string_literal: true

require_relative '../../blueprints'
require_relative '../feelings/code_methods'

module Raindown
  module TUI
    # The blueprints drawn in the comments above a project's classes and methods, like this codebase's renderers', each a
    # run of lines indented further than the comment's prose, described by the prose above it, but not a code block,
    # like an example of a file.
    module CodeComments
      # A comment's line, by what's after its marker and a space, in the languages Code feelings reads.
      COMMENT = %r{\A\s*(?:#|//)(?: |\z)(.*)\z}
      # A line of a comment that's drawn, indented further than its prose.
      DRAWN_LINE = /\A  /

      module_function

      # The blueprints in the comments of the projects' code, by file from the root, from the top of each. In a folder of
      # projects, like ~/dev, only the projects' code is read.
      def blueprints(root, projects: [root])
        files = projects.flat_map { CodeMethods.files(it) }.uniq
        files.flat_map { |path| in_file(path, path.delete_prefix(File.join(root, ''))) }
      end

      def in_file(path, relative)
        lines = File.readlines(path, chomp: true)
        comments(lines).flat_map { |start, texts| drawings(texts, start, relative) }
      rescue SystemCallError, ArgumentError
        []
      end

      # Each block of comment lines above a class or method, by the index of its first line, with each line's text.
      def comments(lines)
        lines.each_index.filter_map do |index|
          next unless lines[index].match?(COMMENT)
          next if index.positive? && lines[index - 1].match?(COMMENT)

          texts = lines[index..].take_while { it.match?(COMMENT) }.map { it[COMMENT, 1] }
          [index, texts] if defines?(lines[index + texts.length])
        end
      end

      def defines?(line) = line.to_s.match?(CodeMethods::DEFINITION) || line.to_s.match?(CodeMethods::OWNER)

      # The comment's runs of indented lines that are blueprints, each described by the prose above it, if any.
      def drawings(texts, start, path)
        index = start
        [[], *runs(texts)].each_cons(2).filter_map do |prose, drawn|
          index += prose.length
          next unless drawn.first.match?(DRAWN_LINE)

          blueprint(drawn, prose.join(' ').strip, path:, line: index + 1)
        end
      end

      # The comment's lines in runs of prose and of indented lines, by turns.
      def runs(texts) = texts.slice_when { |before, after| before.match?(DRAWN_LINE) != after.match?(DRAWN_LINE) }

      # The drawn lines, without the indent they share, as a blueprint when they're a drawing.
      def blueprint(lines, prose, path:, line:)
        indent = lines.map { it[/\A */].length }.min
        lines = lines.map { it[indent..] }
        return unless drawing?(lines)

        Blueprints::Blueprint.new(time: nil, kind: Blueprints.kind(lines), lines:, path:, line:, description: (prose unless prose.empty?))
      end

      # Whether the lines are drawn, and whole, rather than a code block.
      def drawing?(lines) = lines.none? { it.start_with?('```') } && lines.join.match?(Blueprints::DRAWN) && Blueprints.whole?(lines)
    end
  end
end
