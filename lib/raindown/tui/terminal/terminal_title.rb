# frozen_string_literal: true

module Raindown
  module TUI
    # The terminal's title while the Screen's open, which it's prepended to: blank, rather than the command's name,
    # saving the title it had, then putting it back, which terminals that can't ignore. It's a space, as terminals like
    # Ghostty take an empty title to mean their own.
    module TerminalTitle
      BLANK_TITLE = "\e]2; \a"
      SAVE_TITLE = "\e[22;2t"
      RESTORE_TITLE = "\e[23;2t"

      private

      def start
        super
        terminal("#{SAVE_TITLE}#{BLANK_TITLE}")
      end

      def stop
        terminal(RESTORE_TITLE)
        super
      end

      def terminal(sequence)
        $stdout.write(sequence)
        $stdout.flush
      end
    end
  end
end
