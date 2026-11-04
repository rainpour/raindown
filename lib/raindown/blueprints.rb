# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'unicode/display_width'
require_relative 'projects'

module Raindown
  # Blueprints from Claude Code's replies, kept in a project's .raindown/data/blueprints.md, which the terminal UI's Blueprints page
  # shows, newest first. Each is a code block under a heading of when it was saved and its kind:
  #   ## 2026-10-30T03:14:07Z · mockup
  #
  #   ```mockup
  #   ╭──────╮
  #   │ Idea │
  #   ╰──────╯
  #   ```
  # A blueprint is a code block marked with its kind, like "mockup", or one with no language that's drawn, with box-drawing
  # lines or blocks, whose kind is worked out from what it's drawn with when it's saved (see Blueprints.kind).
  module Blueprints
    # A blueprint, saved at a time, or drawn in a comment in the code, in the file at its path, from the project's root,
    # from its line, with the paragraph above it, if there was one, as its description.
    Blueprint = Data.define(:time, :kind, :lines, :path, :line, :description) do
      # Its description and words, without the lines drawn among them, which its filter matches and lists it by.
      def words = [description, *lines].join(' ').gsub(DRAWN, ' ').squeeze(' ').strip
      alias_method :text, :words

      # When it was saved, to the minute, or where it's drawn in the code, and its kind.
      def where
        return "#{path}:#{line}#{SEPARATOR}#{kind}" unless time

        "#{time.sub('T', ' ').sub(/:\d\dZ\z/, ' UTC')}#{SEPARATOR}#{kind}"
      end

      # As it's saved in .raindown/data/blueprints.md, under when it was saved and its kind, then its description.
      def markdown(saved_at)
        about = "#{description}\n\n" if description
        "## #{saved_at}#{SEPARATOR}#{kind}\n\n#{about}```#{kind}\n#{lines.join("\n")}\n```\n\n"
      end
    end
    # A box drawn in a blueprint, by the rows and columns of its corners, as a terminal shows them, and the text inside it and in
    # its top border, like a card's title.
    Box = Data.define(:top, :left, :bottom, :right, :text) do
      def cover?(row, column) = row.between?(top, bottom) && column.between?(left, right)
      def above?(other) = bottom < other.top
      def below?(other) = top > other.bottom

      # How far it is from the other box, in rows, then in columns between their middles.
      def distance(other) = [(top - other.top).abs, (left + right - other.left - other.right).abs]
    end

    FILE = File.join('.raindown', 'data', 'blueprints.md')
    # The kinds a code block can be marked with to be a blueprint.
    KINDS = %w[mockup diagram chart table other].freeze
    # What a blueprint's drawn with: lines, like boxes' and arrows', and blocks, like charts' bars.
    LINES = /[─━│┃┌┐└┘├┤┬┴┼╭╮╯╰═║╔╗╚╝╱╲]/
    BLOCKS = /[▁▂▃▄▅▆▇█▀▏▔▕░▒▓]/
    DRAWN = Regexp.union(LINES, BLOCKS)
    BLOCK = /^```(\w*)\n(.*?)^```$/m
    # Arrows that join things, across, which make a blueprint a diagram, like a flow chart's or a sequence diagram's.
    ACROSS = /─▶|◀─|─>|<─|->|<-|[→←↔]/
    # Arrows that join things up or down, when there's a line above or below them.
    UP_DOWN = %w[▼ ▲].freeze
    # The share of a blueprint's characters that are blocks, from which it's a chart.
    CHART = 0.25
    SEPARATOR = ' · '
    # A box's corners, and the lines its left side is drawn with.
    TOP_LEFT = %w[╭ ┌ ╔].freeze
    TOP_RIGHT = %w[╮ ┐ ╗].freeze
    BOTTOM_LEFT = %w[╰ └ ╚].freeze
    BOTTOM_RIGHT = %w[╯ ┘ ╝].freeze
    SIDE = %w[│ ├ ┤ ┼ ║ ╟ ╢].freeze

    module_function

    # The project's blueprints, newest first, each with the line its drawing starts on, counting from 1, like an editor.
    def read(root)
      path = File.join(root, FILE)
      return [] unless File.exist?(path)

      lines = File.readlines(path, chomp: true)
      lines.each_index.select { lines[it].start_with?('## ') }.filter_map { blueprint(lines, it) }.reverse
    end

    # Saves the blueprints in Claude Code's last reply, from its Stop hook's JSON, to the project it's working in, if any,
    # each with its kind.
    def save(hook)
      root = Projects.root(hook['cwd'].to_s) || return
      drawn = drawn(last_reply(hook['transcript_path'].to_s))
      return if drawn.empty?

      time = Time.now.utc.iso8601
      path = File.join(root, FILE).tap { FileUtils.mkdir_p(File.dirname(it)) }
      File.open(path, 'a') { |file| drawn.each { file.write(it.markdown(time)) } }
    end

    # The text's code blocks that are blueprints, each with its kind and the paragraph above it.
    def drawn(text)
      text.to_enum(:scan, BLOCK).filter_map do
        language, body = Regexp.last_match.captures
        lines = body.lines(chomp: true)
        next unless whole?(lines)

        kind = drawn_kind(language, lines) || next
        Blueprint.new(time: nil, kind:, lines:, path: FILE, line: nil, description: description(text[0...Regexp.last_match.begin(0)]))
      end
    end

    # The kind the block's marked with, or, without a language, the kind it's drawn as, or nil when it isn't drawn.
    def drawn_kind(language, lines)
      return language if KINDS.include?(language)

      kind(lines) if language.empty? && lines.join.match?(DRAWN)
    end

    # The paragraph at the end of the text before a block, joined into a line, unless it's another block, or a list.
    def description(before)
      paragraph = before.split(/\n[ \t]*\n/).last.to_s.strip
      return if paragraph.empty? || paragraph.include?('```') || paragraph.match?(/\A(?:[-*+] |\d+\. |#)/)

      paragraph.split("\n").map(&:strip).join(' ')
    end

    # Whether a drawing's more than a line, and closes each box its first line opens, unlike a piece of one quoted, and
    # isn't art.
    def whole?(lines)
      return false if lines.length < 2 || art?(lines)

      boxes(lines).count { it.top.zero? } == columns(lines.first(1)).first.count { TOP_LEFT.include?(it) }
    end

    # What a blueprint is, from what it's drawn with: a diagram when arrows join its parts, a chart when it's mostly blocks,
    # a table when its lines cross, a mockup when it's otherwise boxes and lines, and other when it's none of those.
    def kind(lines)
      text = lines.join("\n")
      return 'diagram' if text.match?(ACROSS) || joined_up_or_down?(lines)
      return 'chart' if text.scan(BLOCKS).length >= CHART * text.delete(" \n").length
      return 'table' if text.include?('┼')
      return 'mockup' if text.match?(DRAWN)

      'other'
    end

    # Whether an up or down arrow has a line above or below it, joining it to what it points from.
    def joined_up_or_down?(lines)
      lines.each_with_index.any? do |line, index|
        line.each_char.with_index.any? do |char, column|
          UP_DOWN.include?(char) && [lines[index - 1], lines[index + 1]].any? { it&.[](column) == '│' }
        end
      end
    end

    # Whether it's art: drawn in blocks and words but no lines, like a stat's number in block digits, or a waffle, or
    # with no words or numbers at all, like rain or balloons.
    def art?(lines)
      text = lines.join
      !text.match?(/[[:alnum:]]/) || (text.match?(BLOCKS) && !text.match?(LINES))
    end

    # The boxes drawn in the blueprint's lines, in reading order, each a top-left corner, the next top-right corner along its
    # row, and the bottom corners below them, its left side drawn down to the bottom.
    def boxes(lines)
      grid = columns(lines)
      grid.each_with_index.flat_map do |row, top|
        row.each_index.filter_map { |left| box(grid, top, left) if TOP_LEFT.include?(row[left]) }
      end
    end

    def box(grid, top, left)
      corner = (left + 1...grid[top].length).find { TOP_RIGHT.include?(grid[top][it]) } || return
      bottom = (top + 1...grid.length).find { !SIDE.include?(grid[it][left]) } || return
      right = bottom_right(grid[bottom], left, corner) || return

      Box.new(top:, left:, bottom:, right:, text: box_text(grid[top...bottom], left, right))
    end

    # The lines' characters by the columns a terminal shows them in, with an empty string in the second column of a wide
    # one, like an emoji, so what's drawn below it lines up.
    def columns(lines)
      lines.map { |line| line.grapheme_clusters.flat_map { [it, *Array.new([Unicode::DisplayWidth.of(it) - 1, 0].max, '')] } }
    end

    # The column of the box's bottom right corner, below its top's, or a column either side, as Claude Code sometimes draws
    # a box's top a column short or long, or nil when the row isn't its bottom.
    def bottom_right(row, left, corner) = [corner, corner + 1, corner - 1].find { closed?(row, left, it) }

    # The grid with each box's right side straight down from its bottom right corner, as Claude Code sometimes draws a
    # box's top, or a row of it, a column short or long, leaving the text inside it as it is.
    def tidied(grid, boxes)
      grid = grid.map(&:dup)
      boxes.each do |box|
        straighten(grid[box.top], box.right, TOP_RIGHT, '─')
        (box.top + 1...box.bottom).each { straighten(grid[it], box.right, SIDE, ' ') }
      end
      grid
    end

    # Moves the row's edge, one of the edges, from a column either side of the right one, filling where it was, when
    # what's at the right column is blank.
    def straighten(row, right, edges, fill)
      return if edges.include?(row[right]) || !row[right].to_s.strip.empty?

      off = [right - 1, right + 1].find { edges.include?(row[it]) } || return
      row[right] = row[off]
      row[off] = fill
    end

    # Whether the row is a box's bottom, from its left corner to its right.
    def closed?(row, left, right) = BOTTOM_LEFT.include?(row[left]) && BOTTOM_RIGHT.include?(row[right])

    # The text across the rows, between the box's sides, without the lines drawn among it.
    def box_text(rows, left, right) = rows.map { it[(left + 1)...right].to_a.join }.join(' ').gsub(DRAWN, ' ').squeeze(' ').strip

    # The text of the assistant's messages since the last thing the user typed, in a transcript of JSON lines.
    def last_reply(path)
      return '' unless File.exist?(path)

      entries = File.readlines(path).filter_map { entry(it) }
      asked = entries.rindex { it['type'] == 'user' && typed?(it.dig('message', 'content')) } || -1
      entries[(asked + 1)..].select { it['type'] == 'assistant' }.flat_map { texts(it.dig('message', 'content')) }.join("\n")
    end

    # A line of the transcript, or nil for one that isn't JSON, like one still being written.
    def entry(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    # A user's message is typed when it's text, rather than a tool's result.
    def typed?(content) = content.is_a?(String) || Array(content).any? { it['type'] == 'text' }

    def texts(content) = Array(content).filter_map { it['text'] if it.is_a?(Hash) && it['type'] == 'text' }

    def blueprint(lines, start)
      opening = (start + 1...lines.length).find { lines[it].start_with?('```') } || return
      closing = (opening + 1...lines.length).find { lines[it] == '```' } || return
      Blueprint.new(**heading(lines[start]), lines: lines[(opening + 1)...closing], path: FILE, line: opening + 2,
                                             description: saved_description(lines[(start + 1)...opening]))
    end

    # When a blueprint was saved and its kind, from its heading, which is other when it's none of the kinds.
    def heading(line)
      time, kind = line.delete_prefix('## ').split(SEPARATOR, 2)
      kind = 'other' unless KINDS.include?(kind)
      { time:, kind: }
    end

    # The lines between a blueprint's heading and its drawing, joined, or nil when there are none.
    def saved_description(lines)
      description = lines.reject(&:empty?).join(' ')
      description unless description.empty?
    end
  end
end
