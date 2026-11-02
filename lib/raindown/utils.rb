# frozen_string_literal: true

module Raindown
  module Utils
    module_function

    # A Markdown file's text, with its line endings as LF, "\n", whatever they are in the file.
    #
    # Windows ends lines with CRLF, "\r\n", and Git for Windows checks files out that way, so a file written or cloned on
    # Windows can reach Raindown with them on any platform. Raindown finds directives, like a bare toc:, front matter
    # and code fences line by line, with patterns that end at "\n", so a "\r" left at the end of a line stops them
    # matching: toc: would be left as text instead of writing its table of contents.
    #
    # Text mode ("rt") reads CRLF as LF on every platform, as Ruby does on Windows by default, so the rest of Raindown
    # only ever sees "\n". Writing a file back then gives it LF line endings, except on Windows, where text mode writes
    # CRLF again.
    def read_markdown(path)
      File.read(path, mode: 'rt', encoding: Encoding::UTF_8)
    end
  end
end
