# frozen_string_literal: true

require_relative 'node'

module Raindown
  # What a directive writes in place of its output when it can't run, like toc: extra, or a node that raised, so the
  # rest of the file still writes back. In the file it's under its directive, so only its warning says its line and
  # name. It never starts with the name, like toc:, which would read as a directive once the one above it's deleted.
  class Problem < Node
    attr_reader :message, :line

    def initialize(message, line, name = nil)
      @message = message
      @line = line
      @name = name
      super()
    end

    # A message as a Markdown alert, which Obsidian, GitHub and Raindown show as a warning, and which can't read as a
    # directive, as it starts with >.
    def self.alert(message)
      "> [!WARNING]\n#{message.lines.map { "> #{it}" }.join}"
    end

    def rewrite
      self.class.alert(@message)
    end

    # For a terminal, or an editor to underline the line, like "line 6: toc: takes no value".
    def warning
      ["line #{@line}", @name, @message.sub(/\A[A-Z](?![A-Z])/, &:downcase)].compact.join(': ')
    end
  end
end
