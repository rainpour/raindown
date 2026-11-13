# frozen_string_literal: true

require 'date'

module Raindown
  # A forecast's days as little cards side by side, in text, each with an emoji for its weather in its padding at its
  # top right, its day, its high and low, and its weather in words, on two lines, padded inside:
  #   ╭────────────╮╭────────────╮
  #   │        ☁️  ││        🌧️  │
  #   │  Today     ││  Fri       │
  #   │  20° 10°   ││  19° 14°   │
  #   │  overcast  ││  light     │
  #   │            ││  rain      │
  #   ╰────────────╯╰────────────╯
  module ForecastCards
    # How wide a card's padding is on each side, its text inside it, and the card inside its borders.
    PADDING = 2
    TEXT = 8
    WIDTH = TEXT + (2 * PADDING)
    BORDERS = '╭╮╰╯─│'
    # An emoji for each of the WMO's weather codes, each two characters wide, as editors show them.
    EMOJI = {
      0 => '☀️', 1 => '🌤️', 2 => '⛅', 3 => '☁️', 45 => '🌫️', 48 => '🌫️', 51 => '🌦️', 53 => '🌦️', 55 => '🌦️', 56 => '🌨️',
      57 => '🌨️', 61 => '🌧️', 63 => '🌧️', 65 => '🌧️', 66 => '🌨️', 67 => '🌨️', 71 => '❄️', 73 => '❄️', 75 => '❄️',
      77 => '❄️', 80 => '🌦️', 81 => '🌦️', 82 => '🌧️', 85 => '🌨️', 86 => '🌨️', 95 => '⛈️', 96 => '⛈️', 99 => '⛈️'
    }.freeze
    UNKNOWN = '❔'
    # Shorter words for the weather where the WMO's don't fit a card's two lines, and how many lines they have.
    SHORTER = { 86 => 'heavy snow', 95 => 'storms', 96 => 'storms, hail', 99 => 'storms, hail' }.freeze
    WORD_LINES = 2
    EMOJI_WIDTH = 2
    EMOJI_GAP = 2

    module_function

    # The cards' lines, from the days, the first of them today.
    def lines(days)
      days.each_with_index.map { |day, index| card(day, index) }.transpose.map(&:join)
    end

    # A card's lines: its top border, its padding with its weather's emoji at its right, its day, temperatures, its
    # weather in words on two lines, and its bottom.
    def card(day, index)
      texts = [label(day, index), temperatures(day), *words(day)]
      pad = ' ' * PADDING
      ["╭#{'─' * WIDTH}╮", "│#{top_padding(day)}│", *texts.map { "│#{pad}#{fit(it)}#{pad}│" }, "╰#{'─' * WIDTH}╯"]
    end

    # The card's top padding, with its weather's emoji at its right, in the padding's corner, a space from the border,
    # as an app may draw it larger than its text, in line with the text's padding.
    def top_padding(day)
      emoji = EMOJI.fetch(day.code, UNKNOWN)
      "#{' ' * (WIDTH - Unicode::DisplayWidth.of(emoji, emoji: :all) - EMOJI_GAP)}#{emoji}#{' ' * EMOJI_GAP}"
    end

    # Text padded, by how wide it shows, to the card's text's width.
    def fit(text)
      text + (' ' * [TEXT - Unicode::DisplayWidth.of(text, emoji: :all), 0].max)
    end

    # The day's weather in words, like partly cloudy, wrapped to the card's text's width, on WORD_LINES lines.
    def words(day)
      wrapped = SHORTER.fetch(day.code, day.words).split.each_with_object([]) do |word, lines|
        next lines << word if lines.empty? || "#{lines.last} #{word}".length > TEXT

        lines[-1] = "#{lines.last} #{word}"
      end
      (wrapped + ([''] * WORD_LINES)).first(WORD_LINES)
    end

    def label(day, index)
      return 'Today' if index.zero?

      Date.parse(day.date).strftime('%a')
    end

    # Its high and low, without their degrees when they're too long for a card, like -12 -20.
    def temperatures(day)
      text = "#{day.high.round}° #{day.low.round}°"
      return text if text.length <= TEXT

      text.delete('°')
    end

    # Where each card's emoji is, on the cards' second line, as [line, from, to], in columns, for an app to draw as large
    # as a line is tall.
    def emoji(days)
      days.each_index.map do |index|
        from = (index * (WIDTH + 2)) + 1 + WIDTH - EMOJI_WIDTH - EMOJI_GAP
        [1, from, from + EMOJI_WIDTH]
      end
    end

    # Where each card's day is, on the cards' third line, as [line, from, to], for an app to embolden.
    def headings(days)
      days.each_with_index.map do |day, index|
        from = (index * (WIDTH + 2)) + 1 + PADDING
        [2, from, from + label(day, index).length]
      end
    end

    # The characters of a card's lines that are its borders, as [line, from, to], in columns, as an emoji takes two,
    # for an app to dim.
    def borders(lines)
      lines.each_with_index.flat_map do |line, index|
        column = 0
        line.each_grapheme_cluster.filter_map do |character|
          at = column
          column += Unicode::DisplayWidth.of(character, emoji: :all)
          [index, at, at + 1] if BORDERS.include?(character)
        end
      end
    end
  end
end
