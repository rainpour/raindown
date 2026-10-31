# frozen_string_literal: true

require 'pathname'
require 'uri'

require_relative 'document'
require_relative 'pages'
require_relative 'projects'

module Raindown
  # Wormholes are links in a project's Markdown files that lead nowhere: to a file that isn't there, or to an #anchor
  # that no heading in the file has, like "#setp" for "## Setup", or "guides/setup.md#install" when it has no Install.
  # A heading's id is the one Commonmarker gives it, with -1, -2 and so on for the same heading again, and the
  # headings are the ones in the file, including those a node like toc: wrote back into it. Links to other sites,
  # like https: and mailto:, are left alone, as are links in code, which are text.
  class Wormholes
    REASONS = { file: 'no such file', heading: 'no such heading' }.freeze
    # A link with a scheme, like https:, mailto: or tel:, or that starts with //, goes to another site.
    EXTERNAL = %r{\A(?:[a-z][a-z0-9+.-]*:|//)}i

    # A link that leads nowhere: the file it's in, its line, its text and where it goes, as it's written, and why it
    # leads nowhere, :file or :heading. Span is where the link is, from its [ to its ).
    Wormhole = Data.define(:path, :line, :text, :target, :reason, :span) do
      def why = REASONS[reason]

      # Where it goes and why it leads nowhere, like "#setp: no such heading".
      def label = "#{target}: #{why}"

      # The file it goes to, like "guides/setup.md", or "" for an anchor in its own file.
      def file = target.split('#', 2).first

      # The anchor it goes to, like "setp", or nil when it only goes to a file.
      def anchor = target.split('#', 2)[1]
    end

    # The link written where a link goes instead, like "#setup" for a heading in its own file, or "../setup.md#install"
    # for one in another, relative to the file the link's in.
    def self.link(from:, to:, id: nil)
      anchor = "##{id}" if id
      return anchor.to_s if File.expand_path(to) == File.expand_path(from) && anchor

      relative = Pathname.new(File.expand_path(to)).relative_path_from(File.dirname(File.expand_path(from))).to_s
      "#{relative}#{anchor}"
    end

    # The content with the wormhole's link going to the target instead, like "#setup". A reference link's target is in
    # its definition, like "[guide]: setup.md", which changes instead.
    def self.close(content, wormhole, target)
      start, stop = offsets(content, wormhole.span)
      link = content.byteslice(start...stop)
      index = link.rindex(wormhole.target)
      return defined(content, wormhole, target) unless index

      content.byteslice(0, start) + link[0...index] + target + link[(index + wormhole.target.length)..] + content.byteslice(stop..)
    end

    # The byte offsets of the start and the end of a span of the content.
    def self.offsets(content, span)
      lines = content.lines
      before = ->(line) { lines.first(line - 1).sum(&:bytesize) }
      [before.call(span[:start_line]) + span[:start_column] - 1, before.call(span[:end_line]) + span[:end_column]]
    end

    # The content with the wormhole's target changed in the reference definition it's in.
    def self.defined(content, wormhole, target)
      definition = /^( {0,3}\[[^\]]+\]:[ \t]*<?)#{Regexp.escape(wormhole.target)}(?=[>\s]|\z)/
      raise ArgumentError, "Can't find the link on line #{wormhole.line}" unless content.match?(definition)

      content.sub(definition) { "#{::Regexp.last_match(1)}#{target}" }
    end

    private_class_method :offsets, :defined

    attr_reader :root

    # A link that starts with / goes from the project's root.
    def initialize(root)
      @root = File.expand_path(root)
      @ids = {}
    end

    # The wormholes in each of the project's Markdown files, and those of the projects inside it when they're asked for.
    def all(nested: false) = Projects.files(root, nested:).flat_map { in_file(it) }

    # The wormholes in a file, in the order they're in it.
    def in_file(path)
      path = File.expand_path(path)
      links(path).filter_map do |link|
        reason = reason(path, link.url)
        next unless reason

        span = link.source_position
        Wormhole.new(path:, line: span[:start_line], text: Document.text(link), target: link.url, reason:, span:)
      end
    end

    private

    # The file's links, leaving out those in code, which are text.
    def links(path)
      markdown = File.read(path, encoding: Encoding::UTF_8)
      Commonmarker.parse(markdown, options: MARKDOWN_OPTIONS).walk.select { it.type == :link }
    end

    # Why the link leads nowhere, or nil when it leads somewhere, or to another site, or is a template, like {url}.
    def reason(path, url)
      return if url.empty? || url.match?(EXTERNAL) || url.include?('{')

      file, anchor = url.split('#', 2)
      target = target(path, file)
      return :file unless File.exist?(target)
      return :heading if anchor && !anchor.empty? && markdown?(target) && !ids(target).include?(decode(anchor))

      nil
    end

    # The file a link goes to, from the file it's in, or from the root when it starts with /, without its ?query.
    def target(path, file)
      file = decode(file.split('?', 2).first.to_s)
      return path if file.empty?
      return File.expand_path(file.delete_prefix('/'), root) if file.start_with?('/')

      File.expand_path(file, File.dirname(path))
    end

    def markdown?(path) = File.file?(path) && Pages::EXTENSIONS.include?(File.extname(path).delete_prefix('.').downcase)

    # The heading ids of a file, read once while looking for wormholes.
    def ids(path) = @ids[path] ||= Document.read(path).headings.map(&:id)

    # A link's %-encoded characters, like %20 for a space, or %C3%A9 for é, as they are in a heading's id, or the text as
    # it is when it isn't %-encoded properly.
    def decode(text)
      URI.decode_uri_component(text)
    rescue ArgumentError
      text
    end
  end
end
