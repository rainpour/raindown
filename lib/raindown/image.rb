# frozen_string_literal: true

require 'cgi/escape'
require_relative 'node'
require_relative 'problem'

module Raindown
  # The node behind image:, which writes a Markdown image into the file, so it shows wherever Markdown does:
  #   image: 'pictures/cat.png'      image: 'pictures/cat.png' alt: 'A cat' width: 40
  # The source is a path relative to the note, as Markdown's are, or a URL. Alt describes the image, and is its file's
  # name by default. Width is how many characters wide to show it, in the HTML and in editors that draw images in text,
  # which read it from the directive.
  class Image < Node
    def initialize(source = nil, alt: nil, width: nil)
      @source = source
      @alt = alt
      @width = width
      super()
    end

    def rewrite
      return Problem.alert('Needs a path to an image or a URL') if ['', nil].include?(@source)

      "![#{alt}](#{destination})"
    end

    def render
      return super unless @width

      %(<p><img src="#{CGI.escapeHTML(@source.to_s)}" alt="#{CGI.escapeHTML(alt)}" style="width: #{@width.to_i}ch"></p>)
    end

    private

    def alt
      (@alt || File.basename(@source.to_s, '.*')).delete('[]')
    end

    # A path with spaces goes in angle brackets, which Markdown allows.
    def destination
      @source.match?(/\s/) ? "<#{@source}>" : @source
    end
  end
end
