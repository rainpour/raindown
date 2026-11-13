# frozen_string_literal: true

require 'raindown'
require 'raindown/weather/forecast'
require 'tmpdir'

RSpec.describe Raindown::Forecast do
  let(:answer) do
    { 'current' => { 'temperature_2m' => 19.7, 'weather_code' => 3 },
      'daily' => { 'time' => %w[2026-11-12 2026-11-13], 'weather_code' => [3, 61], 'temperature_2m_max' => [20.0, 19.2],
                   'uv_index_max' => [8.4, 4.35],
                   'temperature_2m_min' => [10.4, 13.9] } }
  end

  around do |example|
    Dir.mktmpdir do |dir|
      original = ENV.fetch('XDG_CACHE_HOME', nil)
      ENV['XDG_CACHE_HOME'] = dir
      example.run
    ensure
      ENV['XDG_CACHE_HOME'] = original
    end
  end

  before { allow(Raindown::HTTPJSON).to receive(:get).and_return(answer) }

  it "forecasts for your time zone's city, from where zone.tab puts it" do
    report = described_class.for(zone: 'Australia/Melbourne')

    expect(report.lines).to eq(['╭────────────╮╭────────────╮', '│        ☁️  ││        🌧️  │',
                                '│  Today     ││  Fri       │',
                                '│  20° 10°   ││  19° 14°   │', '│  UV 8      ││  UV 4      │',
                                '│            ││            │',
                                '╰────────────╯╰────────────╯'])
    expect(Raindown::HTTPJSON).to have_received(:get).with(a_string_including('latitude=-37.8167&longitude=144.9667'))
  end

  it 'forecasts for a place it finds by name, in Fahrenheit in the US' do
    found = { 'results' => [{ 'name' => 'Chicago', 'latitude' => 41.85, 'longitude' => -87.65, 'country_code' => 'US' }] }
    allow(Raindown::HTTPJSON).to receive(:get).with(a_string_including('geocoding')).and_return(found)

    expect(described_class.for('Chicago', zone: 'Australia/Melbourne').unit).to eq('°F')
    expect(Raindown::HTTPJSON).to have_received(:get).with(a_string_including('temperature_unit=fahrenheit'))
  end

  it 'keeps the forecast a while, and keeps it when Open-Meteo can be reached no longer' do
    stub_const("#{described_class}::DAYS", 2)
    described_class.for(zone: 'Australia/Melbourne')
    expect(described_class.for(zone: 'Australia/Melbourne').temperature).to eq(19.7)
    expect(Raindown::HTTPJSON).to have_received(:get).once

    allow(Time).to receive(:now).and_return(Time.at(Time.now.to_i + described_class::FRESH_FOR + 1))
    allow(Raindown::HTTPJSON).to receive(:get).and_raise(Raindown::HTTPJSON::Error, 'offline')
    expect(described_class.for(zone: 'Australia/Melbourne').temperature).to eq(19.7)
  end

  it "asks again for the place it kept, without finding it again, and waits a minute when it can't be reached" do
    found = { 'results' => [{ 'name' => 'Hobart', 'latitude' => -42.88, 'longitude' => 147.33, 'country_code' => 'AU' }] }
    allow(Raindown::HTTPJSON).to receive(:get).with(a_string_including('geocoding')).and_return(found)
    described_class.for('Hobart')
    later = Time.now.to_i + described_class::FRESH_FOR + 1
    allow(Time).to receive(:now).and_return(Time.at(later))

    allow(Raindown::HTTPJSON).to receive(:get).and_raise(Raindown::HTTPJSON::Error, 'offline')
    expect(described_class.for('Hobart').temperature).to eq(19.7)
    expect(Raindown::HTTPJSON).to have_received(:get).with(a_string_including('geocoding')).once

    described_class.for('Hobart')
    expect(Raindown::HTTPJSON).to have_received(:get).with(a_string_including('api.open-meteo.com/v1/forecast')).twice
    allow(Time).to receive(:now).and_return(Time.at(later + described_class::RETRY_AFTER))
    described_class.for('Hobart')
    expect(Raindown::HTTPJSON).to have_received(:get).with(a_string_including('api.open-meteo.com/v1/forecast')).thrice
  end

  it 'has nowhere to forecast for without a time zone with a city' do
    expect(described_class.for(zone: 'Etc/UTC')).to be_nil
  end

  it "dims the cards' borders" do
    quiet = described_class.for(zone: 'Australia/Melbourne').quiet

    expect(quiet).to include([0, 0, 1], [2, 0, 1], [2, 13, 14], [2, 14, 15], [2, 27, 28])
    expect(quiet).not_to include([2, 3, 4])
  end

  it "puts each card's weather's emoji in its padding at its top right, as wide as editors show it" do
    day = described_class::Day.new(date: '2026-11-13', high: 20, low: 10, code: 2, uv: 5)
    expect(Raindown::ForecastCards.card(day, 1)[1]).to eq('│        ⛅  │')
    expect(Raindown::ForecastCards.emoji([day, day])).to eq([[1, 9, 11], [1, 23, 25]])
    expect(Raindown::ForecastCards.borders(Raindown::ForecastCards.lines([day, day]))).to include([1, 13, 14], [1, 14, 15])
  end

  it "emboldens the cards' days" do
    expect(described_class.for(zone: 'Australia/Melbourne').bold).to eq([[2, 3, 8], [2, 17, 20]])
  end

  it 'writes temperatures without their degrees when they would be too long for a card' do
    day = described_class::Day.new(date: '2026-11-12', high: -14.2, low: -20.4, code: 71, uv: 1.2)
    expect(Raindown::ForecastCards.temperatures(described_class::Day.new(date: '2026-11-12', high: -4.2, low: -9.4, code: 71, uv: 1.0)))
      .to eq('-4° -9°')
    expect(Raindown::ForecastCards.card(day, 0)[3]).to eq('│  -14 -20   │')
  end

  it "reads zone.tab's degrees and minutes, and seconds" do
    expect(described_class::TimeZone.degrees('-3749')).to eq(-37.8167)
    expect(described_class::TimeZone.degrees('+404251')).to eq(40.7142)
    expect(described_class::TimeZone.degrees('-0740023')).to eq(-74.0064)
  end
end
