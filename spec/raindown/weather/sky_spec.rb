# frozen_string_literal: true

require 'raindown'
require 'raindown/weather/sky'

RSpec.describe Raindown::Sky do
  let(:conditions) do
    { cloud_cover: 74, rain: 0.0, showers: 0.0, snowfall: 0.0, wind_speed_10m: 12.5, visibility: 52_920.0, weather_code: 2,
      temperature_2m: 19.7 }
  end

  it "covers the sky by its layers of cloud, high cloud thin, as much as its weather code says, like clear's little" do
    layers = conditions.merge(cloud_cover: 100, cloud_cover_low: 48, cloud_cover_mid: 44, cloud_cover_high: 99)

    expect(described_class.of(layers.merge(weather_code: 0), overrides: '')[:cloud]).to eq(0.15)
    expect(described_class.of(layers.merge(weather_code: 2), overrides: '')[:cloud]).to eq(0.48)
    expect(described_class.of(layers.merge(weather_code: 3, cloud_cover_low: 10), overrides: '')[:cloud]).to eq(0.8)
    expect(described_class.of(layers.merge(weather_code: 61, cloud_cover_low: 0, cloud_cover_mid: 0), overrides: '')[:cloud])
      .to eq(0.7)
  end

  it 'reads how much cloud, rain, snow, fog, storm and wind there is from the conditions now' do
    expect(described_class.of(conditions, overrides: ''))
      .to eq(cloud: 0.7, rain: 0.0, snow: 0.0, fog: 0.0, storm: 0, wind: 0.25, temperature: 19.7)
  end

  it "rains by how much falls, or at least as much as its weather code says, like drizzle's" do
    expect(described_class.of(conditions.merge(rain: 1.5), overrides: '')[:rain]).to eq(0.5)
    expect(described_class.of(conditions.merge(weather_code: 53), overrides: '')[:rain]).to eq(0.35)
  end

  it 'is foggy in fog, or when it can only be seen so far, and stormy in thunderstorms' do
    expect(described_class.of(conditions.merge(weather_code: 45), overrides: '')[:fog]).to eq(0.8)
    expect(described_class.of(conditions.merge(visibility: 2500), overrides: '')[:fog]).to eq(0.4)
    expect(described_class.of(conditions.merge(weather_code: 95), overrides: '')[:storm]).to eq(1)
  end

  it 'takes what RAINDOWN_SKY sets over the conditions, ignoring what it does not know' do
    expect(described_class.of(conditions, overrides: 'rain=0.8, cloud=1,hail=1')).to include(rain: 0.8, cloud: 1.0)
    expect(described_class.of(conditions, overrides: 'hail=1')).not_to have_key(:hail)
  end
end
