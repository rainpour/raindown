# frozen_string_literal: true

require_relative 'table_formulas'

module Raindown
  # A cell of a table: block's file, as its table shows it: its value, worked out from its formula, and clipped to fit
  # its column, ending in an ellipsis, when the column's fixed. Deleting the padding around a formula's value shows its
  # formula, and deleting a clipped cell's ellipsis shows its full text, wrapped onto |+ rows, each until it's changed,
  # or, for its full text, an ellipsis is typed into it again, which clips it.
  FileCell = Data.define(:saved, :value, :column) do
    # As the table shows it, unless it's revealed.
    def shown
      return value unless column

      column.clip(value)
    end

    # Whether the written cell still shows it: its value, as shown or in full, or clipped at another width, as it was
    # before its column's width changed, or in full with an ellipsis typed into it, its formula, ignoring whitespace, or
    # its clipped start, with the ellipsis deleted.
    def unchanged_by?(cell)
      [shown, value, revealing].include?(cell) || formula_in?(cell) || clip_of_value?(cell) || collapsing?(cell)
    end

    # Whether the written cell shows its formula, or its full text, in place of what the table shows. A full text written
    # on one line, before its column was fixed, isn't, so it's clipped.
    def revealed_by?(cell, squeezed:, wrapped:)
      return formula_in?(cell) || (cell == value && squeezed) if formula?

      clipped? && (cell == revealing || (cell == value && wrapped))
    end

    # The value the written cell gives it: its own while it's unchanged, or else what was typed, with the end that was
    # clipped off back in place of the ellipsis, while it has one, like when its start's edited, or more typed after it.
    def value_from(cell)
      return value if unchanged_by?(cell)

      before, after = cell.split('…', 2)
      hidden = clipped_off(before)
      return cell unless after && hidden

      "#{before}#{hidden}#{after}"
    end

    private

    def formula?
      TableFormulas.formula?(saved)
    end

    def formula_in?(cell)
      formula? && cell.gsub(/\s+/, '') == saved.gsub(/\s+/, '')
    end

    # Its full text with an ellipsis typed into it, like … or ..., anywhere between its words, to clip it again.
    def collapsing?(cell)
      ellipsis = /\s*(?:…|\.\.\.)\s*/
      cell.match?(ellipsis) && cell.sub(ellipsis, ' ').strip == value
    end

    def clip_of_value?(cell)
      cell.end_with?('…') && value.length >= cell.length && value.start_with?(cell.delete_suffix('…'))
    end

    # The end clipped off after the start before the ellipsis: the rest of its value when that's how it starts, or else,
    # when its start's been edited, what's after the start it's clipped to now.
    def clipped_off(before)
      return value.delete_prefix(before) if value.start_with?(before)

      value.delete_prefix(revealing) if clipped?
    end

    def clipped?
      shown != value
    end

    # Its clipped start, without the ellipsis, which shows its full text when that's deleted.
    def revealing
      shown.delete_suffix('…') if clipped?
    end
  end
end
