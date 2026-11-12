# frozen_string_literal: true

module Raindown
  # The weather now as a sky for an app to paint, as how much of each kind of weather there is, from 0 to 1, so its
  # painters blend them: cloud, how much of the sky's covered, rain and snow, how hard they're falling, fog, storm,
  # whether there's thunder, wind, how hard it's blowing, and the temperature in °C. From Open-Meteo's current
  # conditions, and from its weather code, which says what's falling when its amounts are small, like drizzle.
  module Sky
    # How much rain or snow a weather code means, at least, and fog.
    RAIN = { 51 => 0.25, 53 => 0.35, 55 => 0.45, 56 => 0.35, 57 => 0.45, 61 => 0.4, 63 => 0.65, 65 => 0.9, 66 => 0.4,
             67 => 0.6, 80 => 0.4, 81 => 0.65, 82 => 0.9, 95 => 0.85, 96 => 0.85, 99 => 0.9 }.freeze
    SNOW = { 71 => 0.35, 73 => 0.6, 75 => 0.9, 77 => 0.3, 85 => 0.5, 86 => 0.85 }.freeze
    FOG = { 45 => 0.8, 48 => 0.85 }.freeze
    # How much each layer of cloud covers the sky, as its high cloud's thin, like cirrus, so a sky Open-Meteo calls
    # clear can have it all over, and how much cloud there is for each weather code, so the sky's what its words say.
    # Rain, snow, fog and storms have at least WET_CLOUD.
    LAYERS = { cloud_cover_low: 1.0, cloud_cover_mid: 0.8, cloud_cover_high: 0.25 }.freeze
    CLOUD = { 0 => 0.0..0.15, 1 => 0.1..0.4, 2 => 0.3..0.7, 3 => 0.8..1.0 }.freeze
    WET_CLOUD = 0.7
    # The rain, in mm an hour, snow, in cm an hour, wind, in km/h, and visibility, in metres, at which they're at their
    # most.
    HEAVIEST_RAIN = 3.0
    HEAVIEST_SNOW = 1.5
    STRONGEST_WIND = 50.0
    CLEAREST = 5000.0
    # The kinds of weather, which RAINDOWN_SKY can set, like "rain=0.8,cloud=1", to see them.
    KINDS = %i[cloud rain snow fog storm wind temperature].freeze

    module_function

    # The sky from Open-Meteo's current conditions, as cloud_cover, rain, showers, snowfall, wind_speed_10m,
    # visibility, weather_code and temperature_2m, in °C, with RAINDOWN_SKY's on top.
    def of(conditions, overrides: ENV.fetch('RAINDOWN_SKY', ''))
      code = conditions[:weather_code].to_i
      sky = { cloud: cloud(conditions, code), **falling(conditions, code), fog: fog(conditions, code),
              storm: storm(code), wind: clamp(conditions[:wind_speed_10m].to_f / STRONGEST_WIND),
              temperature: conditions[:temperature_2m].to_f }
      sky.merge(overridden(overrides))
    end

    # How much of the sky's covered: its layers of cloud, weighted by how thick they are, or else its cloud cover, in
    # the range its weather code says.
    def cloud(conditions, code)
      layers = LAYERS.filter_map { |layer, weight| conditions[layer] && (conditions[layer].to_f / 100 * weight) }
      cover = layers.max || (conditions[:cloud_cover].to_f / 100)
      range = CLOUD.fetch(code) { WET_CLOUD..1.0 }
      clamp(cover.clamp(range.begin, range.end))
    end

    # How hard rain and snow are falling, by how much falls, or at least as much as the weather code says.
    def falling(conditions, code)
      rain = clamp((conditions[:rain].to_f + conditions[:showers].to_f) / HEAVIEST_RAIN)
      snow = clamp(conditions[:snowfall].to_f / HEAVIEST_SNOW)
      { rain: [rain, RAIN.fetch(code, 0)].max, snow: [snow, SNOW.fetch(code, 0)].max }
    end

    # Whether there's thunder, as 1, or not, as 0.
    def storm(code)
      return 1 if code >= 95

      0
    end

    # How foggy it is, by how far it can be seen, or at least as foggy as the weather code says.
    def fog(conditions, code) = [visibility_fog(conditions[:visibility]), FOG.fetch(code, 0)].max

    # How foggy a visibility, in metres, makes it, from none at CLEAREST to most at none.
    def visibility_fog(visibility)
      return 0 if visibility.nil?

      clamp((CLEAREST - visibility.to_f) / CLEAREST) * 0.8
    end

    def overridden(overrides)
      overrides.split(',').to_h { it.split('=', 2) }.filter_map do |kind, amount|
        [kind.strip.to_sym, amount.to_f] if KINDS.include?(kind.strip.to_sym)
      end.to_h
    end

    def clamp(value) = value.clamp(0.0, 1.0).round(2)
  end
end
