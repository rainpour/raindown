# frozen_string_literal: true

require 'cgi/escape'
require 'date'
require 'json'
require_relative '../node'
require_relative 'rijksmuseum'

module Raindown
  # The node behind painting:, a painting from the Rijksmuseum's collection, a different one each day, which an app
  # that draws pixels shows like an image, in a gilded frame, as big as fits where it's written: in the blank lines
  # below its block, or in a grid's cell. It writes its title, its painter and when it was made, a line each, and in the
  # HTML it's the painting's image, with them as its caption, linking to it:
  #   painting:
  #   *Misty Sea*
  #   Jan Toorop
  #   1899
  class Painting < Node
    # Where the day's painting is kept, so it's asked for once a day.
    def self.cache_file
      File.join(ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')), 'raindown', 'painting.json')
    end

    # The day's painting, as its title, creator, date, image and url, kept for the day.
    def self.today(day: Date.today, museum: Rijksmuseum.new)
      cached = cached_on(day)
      return cached if cached

      museum.painting_of(day).tap { cache(day, it) }
    end

    def self.cached_on(day)
      kept = JSON.parse(File.read(cache_file), symbolize_names: true)
      Rijksmuseum::Painting.new(**kept[:painting]) if kept[:day] == day.iso8601
    rescue Errno::ENOENT, JSON::ParserError, ArgumentError, TypeError
      nil
    end

    def self.cache(day, painting)
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, JSON.generate(day: day.iso8601, painting: painting.to_h))
    end

    # Its title, painter and date, a line each, or what it wrote before when the museum can't be reached.
    def rewrite(written: [])
      painting = self.class.today
      ["*#{painting.title}*", painting.creator, painting.date].compact.join("\n")
    rescue Rijksmuseum::Error
      written.map(&:chomp).join("\n")
    end

    def render
      painting = self.class.today
      %(<figure class="painting"><img src="#{CGI.escapeHTML(painting.image)}" alt="#{CGI.escapeHTML(painting.caption)}">) +
        %(<figcaption><a href="#{CGI.escapeHTML(painting.url)}">#{CGI.escapeHTML(painting.caption)}</a></figcaption></figure>)
    rescue Rijksmuseum::Error
      ''
    end
  end
end
