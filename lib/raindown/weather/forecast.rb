# frozen_string_literal: true

require 'date'
require 'json'
require_relative '../http_json'
require_relative 'forecast_cache'
require_relative 'forecast_cards'
require_relative 'sky'

module Raindown
  # The weather where you are, or in a place you name, from Open-Meteo, which needs no key: the weather now and the next
  # few days', for weather:. Where you are is your time zone's city, like Melbourne for Australia/Melbourne, from where
  # tzdata's zone.tab puts it, and a place you name is found by Open-Meteo's geocoding. It's kept for a while, and kept
  # longer when Open-Meteo can't be reached, so it isn't lost while you're offline.
  class Forecast
    GEOCODING = 'https://geocoding-api.open-meteo.com/v1/search'
    FORECAST = 'https://api.open-meteo.com/v1/forecast'
    ZONE_TAB = '/usr/share/zoneinfo/zone.tab'
    FRESH_FOR = 15 * 60
    # How long after Open-Meteo couldn't be reached it's asked again, using what was kept meanwhile.
    RETRY_AFTER = 60
    DAYS = 7
    # What it asks Open-Meteo for now, for its sky as well as its temperature and weather.
    CURRENT = 'temperature_2m,weather_code,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,rain,showers,' \
              'snowfall,wind_speed_10m,visibility,uv_index'
    # The countries that measure in Fahrenheit.
    FAHRENHEIT = %w[US LR MM].freeze
    # What the WMO's weather codes, which Open-Meteo answers with, are in words.
    WORDS = {
      0 => 'clear', 1 => 'mostly clear', 2 => 'partly cloudy', 3 => 'overcast', 45 => 'fog', 48 => 'freezing fog',
      51 => 'light drizzle', 53 => 'drizzle', 55 => 'heavy drizzle', 56 => 'freezing drizzle', 57 => 'freezing drizzle',
      61 => 'light rain', 63 => 'rain', 65 => 'heavy rain', 66 => 'freezing rain', 67 => 'freezing rain',
      71 => 'light snow', 73 => 'snow', 75 => 'heavy snow', 77 => 'snow grains', 80 => 'light showers', 81 => 'showers',
      82 => 'heavy showers', 85 => 'snow showers', 86 => 'heavy snow showers', 95 => 'thunderstorms',
      96 => 'thunderstorms with hail', 99 => 'thunderstorms with hail'
    }.freeze

    Error = HTTPJSON::Error
    Place = Data.define(:name, :latitude, :longitude, :country)
    # A day's weather, its high and low, its weather code, and how strong its sun's ultraviolet gets, its UV index.
    Day = Data.define(:date, :high, :low, :code, :uv) do
      def words = WORDS.fetch(code, 'unknown')
    end
    # The weather now and the week's, in a unit, like °C, with the conditions now, as Open-Meteo gives them, for its sky,
    # and how far ahead of UTC the place's clocks are, in seconds.
    Report = Data.define(:place, :temperature, :code, :unit, :days, :conditions, :utc_offset) do
      def words = WORDS.fetch(code, 'unknown')

      # How strong the sun's ultraviolet is now, its UV index, or nil when it wasn't given, like in a forecast kept from
      # before it was asked for. Its conditions' names are text as Open-Meteo gives them, and symbols as they're kept.
      def uv = conditions.transform_keys(&:to_s)['uv_index']

      # Its lines, the days' cards, as ForecastCards draws them.
      def lines = ForecastCards.lines(days)

      # The characters of its lines for an app to dim, the cards' borders, as [line, from, to].
      def quiet = ForecastCards.borders(lines)

      # The characters of its lines for an app to embolden, the cards' days, as [line, from, to].
      def bold = ForecastCards.headings(days)

      # The characters of its lines for an app to draw as large as a line is tall, the cards' emoji, as [line, from, to].
      def large = ForecastCards.emoji(days)

      # The weather now as a sky for an app to paint, its temperature in °C.
      def sky
        celsius = temperature
        celsius = (temperature - 32) * 5 / 9 if unit == '°F'
        Sky.of(conditions.transform_keys(&:to_sym).merge(temperature_2m: celsius))
      end
    end

    # The forecast for a place you name, or else where you are, or nil when there's nowhere to forecast for.
    def self.for(place_name = nil, zone: TimeZone.name)
      new(place_name, zone:).report
    end

    # The forecast last kept for a place you name, or else where you are, however old, or nil, without asking for it.
    def self.cached(place_name = nil, zone: TimeZone.name)
      new(place_name, zone:).cached
    end

    def initialize(place_name, zone:)
      @place_name = place_name
      @zone = zone
      @cache = Cache.new(place_name || zone.to_s)
    end

    # The forecast, from the cache while it's fresh, or else asked for again, for the place it was kept for, so it's not
    # looked up again, or from the cache however old it is when Open-Meteo can't be reached, which isn't asked again for
    # RETRY_AFTER seconds, or nil when it never has been.
    def report
      cached, fresh = @cache.report
      return cached if fresh

      place = cached&.place || self.place
      return unless place

      fetched(place).tap { @cache.keep(it) }
    rescue Error
      raise unless cached

      @cache.unreached
      cached
    end

    # The forecast kept for this place, however old, or nil, without asking Open-Meteo.
    def cached = @cache.report.first

    # The place to forecast for, as its name, latitude, longitude and country.
    def place
      return TimeZone.place(@zone) unless @place_name

      found = HTTPJSON.get("#{GEOCODING}?#{URI.encode_www_form(name: @place_name, count: 1, language: 'en')}")['results']&.first
      raise Error, "Couldn't find #{@place_name}" unless found

      Place.new(name: found['name'], latitude: found['latitude'], longitude: found['longitude'], country: found['country_code'])
    end

    private

    def fetched(place)
      query = { latitude: place.latitude, longitude: place.longitude, current: CURRENT,
                daily: 'weather_code,temperature_2m_max,temperature_2m_min,uv_index_max', timezone: 'auto',
                forecast_days: DAYS }
      query[:temperature_unit] = 'fahrenheit' if fahrenheit?(place)
      report_of(place, HTTPJSON.get("#{FORECAST}?#{URI.encode_www_form(query)}"), unit_of(place))
    end

    def fahrenheit?(place) = FAHRENHEIT.include?(place.country)

    def unit_of(place)
      return '°F' if fahrenheit?(place)

      '°C'
    end

    def report_of(place, answer, unit)
      now = answer.fetch('current')
      Report.new(place:, temperature: now['temperature_2m'], code: now['weather_code'], unit:, days: days_of(answer),
                 conditions: now.except('time', 'interval'), utc_offset: answer['utc_offset_seconds'].to_i)
    end

    def days_of(answer)
      daily = answer.fetch('daily')
      daily.fetch('time').each_index.map do |index|
        Day.new(date: daily['time'][index], high: daily['temperature_2m_max'][index], low: daily['temperature_2m_min'][index],
                code: daily['weather_code'][index], uv: daily['uv_index_max']&.at(index))
      end
    end

    # Your time zone, like Australia/Melbourne, and its city, from tzdata.
    module TimeZone
      module_function

      # Your time zone's name, from TZ or else where /etc/localtime points, or nil.
      def name
        zone = ENV.fetch('TZ', nil)&.delete_prefix(':')
        zone = File.readlink('/etc/localtime')[%r{zoneinfo/(.+)\z}, 1] if zone.nil? || zone.empty?
        zone
      rescue SystemCallError
        nil
      end

      # The zone's city, where zone.tab puts it, its name from the zone's, like Melbourne, or nil for a zone without one.
      def place(zone, zone_tab: ZONE_TAB)
        line = File.foreach(zone_tab).find { !it.start_with?('#') && it.split("\t")[2] == zone }
        return unless line

        country, coordinates = line.split("\t")
        latitude, longitude = coordinates.scan(/[+-]\d+/).map { degrees(it) }
        Place.new(name: zone.split('/').last.tr('_', ' '), latitude:, longitude:, country:)
      rescue SystemCallError
        nil
      end

      # Degrees from ISO 6709's ±DDMM, ±DDDMM, ±DDMMSS or ±DDDMMSS.
      def degrees(text)
        digits = text[1..]
        whole = 2 + (digits.length % 2)
        parts = [digits[0, whole], digits[whole, 2], digits[whole + 2, 2]].map(&:to_i)
        value = (parts[0] + (parts[1] / 60.0) + (parts[2] / 3600.0)).round(4)
        return -value if text.start_with?('-')

        value
      end
    end
  end
end
