# frozen_string_literal: true

require 'cgi/escape'
require_relative '../config'
require_relative '../node'
require_relative '../scene'
require_relative 'branch_tree'
require_relative 'forecast'

module Raindown
  # The node behind weather:, the weather where you are, from Open-Meteo, now and for the week, which apps draw a sky
  # behind, like over a valley in the app. Where you are is your time zone's city, or a place you name, like
  # weather: Brisbane:
  #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #   < weather:
  #   < ╭────────────╮╭────────────╮ …
  #   < │        ☁️  ││        🌧️  │
  #   < │  Today     ││  Fri       │
  #   < │  20° 10°   ││  19° 14°   │
  #   < │  overcast  ││  light     │
  #   < │            ││  rain      │
  #   < ╰────────────╯╰────────────╯
  # In an app that draws pixels, it shows a valley behind its text, by day or by night, which the app paints itself,
  # from the weather now it gives it, and in a code project, a constellation for each of its branches that aren't merged
  # into main, a star a commit.
  class Weather < Node
    # How long its branches and weather are kept, as an app asks for its sky about once a second, and how long it waits
    # to ask for the weather again when there's none, as Open-Meteo couldn't be reached.
    FRESH_FOR = 5
    RETRY_AFTER = 60

    def initialize(place = nil)
      @place = place
      super()
    end

    def rewrite
      forecast_lines.join("\n")
    end

    # Its valley, with its branches' names and commits for their constellations, and the weather now, with its UV index
    # now and today's at its strongest, to a decimal place, and its sky, how much cloud, rain, snow, fog, storm and wind there is,
    # as Sky gives it, at any size, which the app paints. Without the weather, its sky's clear, but for what RAINDOWN_SKY
    # sets. For a place it names, it's that place's time of day too, from how far ahead of UTC its clocks are, in
    # seconds, as utc_offset.
    def rasterize(metadata: NoMetadata, **)
      report = forecast_now
      now = report && { temperature: report.temperature, unit: report.unit, code: report.code, words: report.words,
                        uv: report.uv&.round(1), uv_peak: report.uv_peak&.round(1) }
      branches = branches(metadata).map { { name: it.name, commits: it.commits } }
      data = { branches:, now:, sky: report&.sky || Sky.of({}) }
      data[:utc_offset] = report.utc_offset if @place && report
      Scene.new(name: 'valley', data:)
    end

    # The characters of its lines an app dims, so the weather stands out, its cards' borders, as [line, from, to], its
    # lines counted from the first it writes.
    def quiet(**)
      forecast_now&.quiet || []
    end

    # The characters of its lines an app emboldens, its cards' days, as [line, from, to].
    def bold(**)
      forecast_now&.bold || []
    end

    # The characters of its lines an app draws as large as a line is tall, its cards' emoji, as [line, from, to].
    def large(**)
      forecast_now&.large || []
    end

    # Its lines as they're written, keeping their spaces, so its cards stay as they're drawn.
    def render
      %(<pre class="weather">#{CGI.escapeHTML(rewrite)}</pre>)
    end

    private

    # The weather now and the week's, as ForecastCards draws it, or none when it can't be found.
    def forecast_lines
      forecast&.lines || []
    end

    # The weather, kept FRESH_FOR seconds, or RETRY_AFTER when there's none, waiting for it when it's asked for again.
    def forecast
      return @forecast.last if kept?

      found(fetched_report)
    end

    # The weather without waiting for it, for an app painting it, which never waits for the network: what it last had,
    # or else what was kept, however old, while it's asked for again in the background.
    def forecast_now
      return @forecast.last if kept?

      refresh
      @forecast&.last || Forecast.cached(@place)
    end

    def kept?
      found_at, report = @forecast
      found_at && Time.now - found_at < (report ? FRESH_FOR : RETRY_AFTER)
    end

    def found(report)
      @forecast = [Time.now, report]
      report
    end

    def fetched_report
      Forecast.for(@place)
    rescue Forecast::Error
      nil
    end

    # The weather, asked for again in a thread of its own, one at a time.
    def refresh
      return if @refreshing

      @refreshing = true
      Thread.new do
        found(fetched_report)
      ensure
        @refreshing = false
      end
    end

    # Its branches, found again once they're FRESH_FOR seconds old, or none in a notes project.
    def branches(metadata)
      root = root(metadata)
      return [] unless Config.kind(root) == 'code'

      found_at, branches = @branches
      return branches if found_at && Time.now - found_at < FRESH_FOR

      BranchTree.new(root).branches.tap { @branches = [Time.now, it] }
    end

    # The project's folder, from the page being written, or else the current one.
    def root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end
  end
end
