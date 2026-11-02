# frozen_string_literal: true

module Raindown
  module TUI
    # The blueprints filtered by keywords, each a word in one or in its kind, ignoring case, typed into a box like
    # Teleport's, which f or a click on the title opens. Up and down move between all the blueprints that match, as
    # they're shown, with the box listing those around the selected one, Enter or a click keeps the filter, and Esc
    # clears it.
    module Filter
      # The most matches the box lists at once.
      LIMIT = 10

      # The keywords typed, and whether the box is open, taking what's typed.
      attr_reader :query

      def typing? = @filtering == true

      # The blueprints with every keyword, or all of them, filtered again only when the keywords or the blueprints change,
      # as what's drawn asks for the selected one many times a frame.
      def blueprints
        @filtered = [query, @all, filtered(query.to_s.downcase.split)] unless filtered_now?
        @filtered.last
      end

      # The box's matches, from the first it lists, each with its text and where it is, and the selected one, which is
      # the one shown.
      def matches = blueprints[first_match, LIMIT].to_a
      def match = @cursor

      # The first match the box lists, scrolled as little as it takes to list the selected one.
      def first_match
        first = @first_match.to_i.clamp(@cursor - LIMIT + 1, @cursor)
        @first_match = [first, 0].max
      end

      # The f key opens the filter here, rather than Code feelings.
      def own_key?(key) = key == :feelings

      private

      def filtered_now? = @filtered && @filtered[0] == query && @filtered[1].equal?(@all)

      def filtered(keywords)
        return @all if keywords.empty?

        @all.select { |blueprint| keywords.all? { blueprint.words.downcase.include?(it) || blueprint.kind.include?(it) } }
      end

      def open_filter
        @query = query.to_s
        @filtering = true
        nil
      end

      def filter_step(key)
        case key
        when Type then filter_to(query + key.text)
        when :backspace then filter_to(query[0...-1])
        when :up, :down then self.cursor = @cursor + self.class::MOVES[key]
        when :enter then @filtering = false
        when :escape then close_filter
        end
        nil
      end

      def filter_to(keywords)
        @query = keywords
        self.cursor = 0
      end

      def close_filter
        filter_to('')
        @filtering = false
      end
    end
  end
end
