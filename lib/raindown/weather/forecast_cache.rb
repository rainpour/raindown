# frozen_string_literal: true

require 'digest'
require 'json'

module Raindown
  class Forecast
    # Where a place's forecast is kept, in ~/.cache/raindown, with when it was kept, and when Open-Meteo last couldn't be
    # reached, so it's fresh for FRESH_FOR seconds after it was kept, or RETRY_AFTER after Open-Meteo couldn't be.
    class Cache
      def initialize(key)
        @key = key
      end

      # The forecast kept, and whether it's still fresh, which it isn't with fewer days than DAYS, or [nil, false].
      def report
        kept = read
        report = Report.new(**kept[:report], place: Place.new(**kept[:report][:place]), days: kept[:report][:days].map { Day.new(**it) })
        [report, fresh?(kept, report)]
      rescue Errno::ENOENT, JSON::ParserError, ArgumentError, TypeError, NoMethodError
        [nil, false]
      end

      def keep(report)
        kept = report.to_h.merge(place: report.place.to_h, days: report.days.map(&:to_h))
        write(at: Time.now.to_i, report: kept)
      end

      # Notes when Open-Meteo couldn't be reached, beside what was kept, keeping when it was kept.
      def unreached
        write(read.merge(unreached_at: Time.now.to_i))
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      private

      def fresh?(kept, report)
        now = Time.now.to_i
        return true if kept[:unreached_at] && now - kept[:unreached_at] < RETRY_AFTER

        now - kept[:at] < FRESH_FOR && report.days.size >= DAYS
      end

      def read = JSON.parse(File.read(file), symbolize_names: true)

      def write(kept)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, JSON.generate(kept))
      end

      def file
        name = Digest::SHA256.hexdigest(@key)[0, 12]
        File.join(ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')), 'raindown', "forecast-#{name}.json")
      end
    end
  end
end
