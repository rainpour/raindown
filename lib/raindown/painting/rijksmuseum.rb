# frozen_string_literal: true

require_relative '../http_json'

module Raindown
  # The Rijksmuseum's collection, from its search API and the Linked Art its objects resolve to, which needs no key. A
  # day's painting is found by a year the day picks, from the search for paintings with images made in that year, then
  # its object, the visual item it shows and the digital object of that, which has its image's IIIF address.
  class Rijksmuseum
    SEARCH = 'https://data.rijksmuseum.nl/search/collection'
    # The years a day picks from, and how many it tries, from its own on, before it gives up, as a few have no paintings.
    YEARS = (1450..1920)
    TRIES = 8
    # How big the image is asked for, fitting within a square, which is as large as an app shows it.
    IMAGE_SIZE = 1200
    ENGLISH = 'http://vocab.getty.edu/aat/300388277'

    Error = HTTPJSON::Error

    Painting = Data.define(:title, :creator, :date, :image, :url) do
      def caption = [title, creator, date].compact.join(', ')
    end

    # The painting of a day, the same all day, and a different one each day.
    def painting_of(day)
      ids = nil
      year = TRIES.times.lazy.map { year_of(day.jd + it) }.find { (ids = paintings_made_in(it)).any? }
      raise Error, "No paintings found from #{year}" unless ids&.any?

      painting(ids[(day.jd * 104_729) % ids.size])
    end

    def painting(id)
      object = get(id)
      visual = object.fetch('shows', []).first&.fetch('id')
      digital = visual && get(visual).fetch('digitally_shown_by', []).first&.fetch('id')
      image = digital && get(digital).fetch('access_point', []).first&.fetch('id')
      raise Error, "#{id} has no image" unless image

      Painting.new(title: title_of(object), creator: creator_of(object), date: date_of(object), image: sized(image), url: id)
    end

    private

    def year_of(number) = YEARS.begin + ((number * 7919) % YEARS.size)

    def paintings_made_in(year)
      query = URI.encode_www_form(type: 'painting', imageAvailable: true, creationDate: year)
      get("#{SEARCH}?#{query}").fetch('orderedItems', []).map { it['id'] }
    end

    # Its English title, or else its first.
    def title_of(object)
      names = object.fetch('identified_by', []).select { it['type'] == 'Name' }
      english = names.find { |name| name.fetch('language', []).any? { it['id'] == ENGLISH } }
      (english || names.first)&.fetch('content')
    end

    # Who made it, in English, the first of its makers, or else, for one it's attributed to, the museum's statement of
    # who did, like "Philips Wouwerman (mentioned on object)".
    def creator_of(object)
      parts = object.dig('produced_by', 'part') || [object['produced_by']].compact
      notations = parts.flat_map { it.fetch('carried_out_by', []) }.flat_map { it.fetch('notation', []) }
      named = (notations.find { it['@language'] == 'en' } || notations.first)&.fetch('@value')
      named || statement_of(parts)
    end

    def statement_of(parts)
      statements = parts.flat_map { it.fetch('referred_to_by', []) }
      english = statements.select { |statement| statement.fetch('language', []).any? { it['id'] == ENGLISH } }
      english.map { it['content'] }.find { !it.include?(':') }
    end

    def date_of(object)
      object.dig('produced_by', 'timespan', 'identified_by')&.first&.fetch('content')
    end

    # Its IIIF address, asked for at IMAGE_SIZE, fitting within a square.
    def sized(image) = image.sub(%r{/full/[^/]+/}, "/full/!#{IMAGE_SIZE},#{IMAGE_SIZE}/")

    def get(url) = HTTPJSON.get(url, headers: { 'Accept' => 'application/ld+json' })
  end
end
