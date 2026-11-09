# frozen_string_literal: true

require_relative 'code'
require_relative 'front_matter'
require_relative 'toc/markdown_headings'

module Raindown
  # Obsidian's links between notes, which render as Markdown links to the file they name, by its path in the project,
  # like list: links, while the file keeps them as they are:
  #   [[Reading list]]                   [Reading list](<notes/Reading list.md>)
  #   [[Reading list|books]]             [books](<notes/Reading list.md>)
  #   [[Reading list#To read]]           [Reading list > To read](<notes/Reading list.md#to-read>)
  # A name matches a file's name, or the end of its path, like [[notes/Reading list]], without its extension and
  # whatever its case. One that matches no file, and ones in code or front matter, are left as they are, as are
  # embeds, like ![[photo.png]].
  module WikiLinks
    LINK = /(?<!!)\[\[([^\[\]|#\n]+)(?:#([^\[\]|\n]+))?(?:\|([^\[\]\n]+))?\]\]/

    module_function

    def to_markdown(markdown, metadata:)
      return markdown unless markdown.include?('[[')

      pages = metadata.list
      links(markdown).reverse_each.with_object(markdown.b) do |link, bytes|
        page = page_for(link[1], pages)
        bytes[link.byteoffset(0)[0]...link.byteoffset(0)[1]] = markdown_link(link, page).b if page
      end.force_encoding('UTF-8')
    end

    # The links in the Markdown, outside its code and front matter, as matches.
    def links(markdown)
      start = markdown.bytesize - FrontMatter.parse(markdown).last.bytesize
      code = Code.ranges(markdown)
      found = []

      markdown.scan(LINK) do
        link = ::Regexp.last_match
        offset = link.byteoffset(0)[0]
        found << link if offset >= start && code.none? { it.cover?(offset) }
      end

      found
    end

    # The page a name links to: one whose path without its extension is the name, or ends with it.
    def page_for(name, pages)
      name = name.strip.downcase.sub(/\.(?:md|rd|markdown|raindown)\z/, '')
      stems = pages.to_h { [it, it.path.to_s.downcase.sub(%r{\.[^./]+\z}, '')] }

      pages.find { stems[it] == name } || pages.find { stems[it].end_with?("/#{name}") }
    end

    def markdown_link(link, page)
      name, heading, label = link.captures.map { it&.strip }
      label ||= [name, heading].compact.join(' > ')
      anchor = "##{MarkdownHeadings.anchor(heading)}" if heading

      "[#{label.gsub(/[\[\]]/) { "\\#{it}" }}](<#{page.path}#{anchor}>)"
    end
  end
end
