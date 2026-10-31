# frozen_string_literal: true

require_relative '../events'
require_relative '../views/endpoint_view'
require_relative '../../workers/worker'

module Raindown
  module TUI
    # Teleport: "/" opens a search of the Dashboard, Code feelings, every file, heading, directive and wormhole in the files,
    # and every endpoint, matched as it's typed by letters in order, so "stp" finds "## Setup". Up and down move between
    # the matches, Enter or a click opens the one selected, and Esc closes it. Other keys and clicks do nothing while
    # it's open.
    # Closing a wormhole opens it on the files and headings alone, with where the wormhole was meant to go typed in,
    # like "setp", matched with the letters that aren't there left out, so the nearest are first, and the one chosen
    # is where its link goes instead.
    module Search
      # The most matches it shows.
      LIMIT = 10

      # A place to teleport to: its text, where it is, like "guides/setup.md:12", and the step that opens it.
      Place = Data.define(:text, :where, :open) do
        # How well the query matches, or nil when it doesn't: in the text alone, which ranks above a match that needs
        # where it is too, like "setup notes" for "## Setup" in notes.md. A partial match leaves out the letters that
        # aren't there, rather than not matching, so "setp" is near "## Steps" too.
        def score(query, partial: false)
          in_text = letters_score(text, query, partial:)
          return in_text + query.length if in_text

          letters_score("#{text} #{where}", query, partial:)
        end

        private

        # How well the query's letters appear in order in the text, ignoring case: higher for runs of them and for
        # the starts of words, or nil when they don't all appear, or for a partial match, when none do.
        def letters_score(text, query, partial: false)
          haystack = text.downcase
          last = -1
          score = 0
          query.downcase.each_char do |char|
            index = haystack.index(char, last + 1)
            next if index.nil? && partial
            return nil unless index

            score += 1
            score += 2 if index == last + 1
            score += 2 if index.zero? || haystack[index - 1].match?(%r{[\s/#:._-]})
            last = index
          end
          score if score.positive? || query.empty?
        end
      end

      # What's typed, while the search is open, and the selected match.
      attr_reader :query, :match

      # The wormhole being closed, while the search is finding where it goes.
      attr_reader :closing

      def searching? = !query.nil?

      # The places that match what's typed, best first, then in the order they're in the files.
      def matches
        partial = !closing.nil?
        @places.each_with_index.filter_map { |place, index| (score = place.score(query, partial:)) && [-score, index, place] }
               .min(LIMIT).map(&:last)
      end

      # Opens the search to close the wormhole, with the heading or file it was meant to go to typed in.
      def seek_exit(wormhole)
        open_search(closing: wormhole)
        type_query(sought(wormhole))
      end

      private

      def open_search(closing: nil)
        @closing = closing
        @places = places
        @match = 0
        @query = ''
        nil
      end

      def search_event(name)
        case name
        when :up, :down then move_match(name == :up ? -1 : 1)
        when :enter then teleport
        when :escape then close_search
        when :backspace then type_query(query[0...-1])
        end
      end

      def type_query(query)
        @query = query
        @match = 0
        nil
      end

      def move_match(by)
        @match = (@match + by).clamp(0, [matches.length - 1, 0].max)
        nil
      end

      def teleport
        place = matches[@match]
        close_search
        place&.open&.take(self)
      end

      def close_search
        @query = nil
        @closing = nil
        nil
      end

      def places
        return exits if closing

        [*pages.map { |text, view| Place.new(text:, where: '', open: OpenView.new(view:)) },
         *@files.files.flat_map { file_places(it) },
         *@endpoints.all.map { Place.new(text: it.text, where: "#{relative(it.path)}:#{it.line}", open: open_endpoint(it)) }]
      end

      # The file, then its headings, directives and wormholes, in the order they're in it.
      def file_places(path)
        outline = outline(path)
        where = relative(path)
        items = (outline.headings + outline.directives + outline.wormholes).sort_by(&:line)
        [Place.new(text: where, where: '', open: Open.new(path:, line: nil)),
         *items.map { Place.new(text: item_text(it), where: "#{where}:#{it.line}", open: Open.new(path:, line: it.line)) }]
      rescue Workers::Worker::Error
        []
      end

      # The heading the wormhole was meant to go to, like "setp", or the file, when there's no such file.
      def sought(wormhole)
        return wormhole.file if wormhole.reason == :file

        wormhole.anchor.to_s
      end

      # Where the wormhole being closed can go instead: each file, then its headings.
      def exits
        @files.files.flat_map do |path|
          where = relative(path)
          [Place.new(text: where, where: '', open: Reroute.new(wormhole: closing, path:, id: nil)),
           *outline(path).headings.map { exit_place(it, path:, where:) }]
        rescue Workers::Worker::Error
          []
        end
      end

      def exit_place(heading, path:, where:)
        Place.new(text: item_text(heading), where: "#{where}:#{heading.line}", open: Reroute.new(wormhole: closing, path:, id: heading.id))
      end

      def outline(path) = @workers.for(path).call(:outline, path)

      def item_text(item)
        return "#{'#' * item.level} #{item.text}" if item.is_a?(Document::Heading)
        return "🕳 Wormhole #{item.label}" if item.is_a?(Wormholes::Wormhole)

        "#{item.name}: #{item.args}".strip
      end

      def open_endpoint(endpoint) = OpenView.new(view: EndpointView.new(endpoint, workers: @workers))
    end
  end
end
