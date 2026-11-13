# frozen_string_literal: true

require 'raindown'
require 'tmpdir'

RSpec.describe Raindown::Weather do
  let(:metadata) { Struct.new(:root).new(@dir) }

  let(:report) do
    place = Raindown::Forecast::Place.new(name: 'Melbourne', latitude: -37.8167, longitude: 144.9667, country: 'AU')
    days = [Raindown::Forecast::Day.new(date: '2026-11-12', high: 20.0, low: 10.4, code: 3, uv: 8.4),
            Raindown::Forecast::Day.new(date: '2026-11-13', high: 19.2, low: 13.9, code: 53, uv: 4.35)]
    conditions = { 'temperature_2m' => 19.7, 'weather_code' => 3, 'cloud_cover' => 100, 'rain' => 0.0, 'uv_index' => 8.6 }
    Raindown::Forecast::Report.new(place:, temperature: 19.7, code: 3, unit: '°C', days:, conditions:, utc_offset: 39_600)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      example.run
    end
  end

  before { allow(Raindown::Forecast).to receive_messages(for: nil, cached: nil) }

  it "writes nothing in a notes project when there's no weather to be found" do
    expect(described_class.new.rewrite).to eq('')
  end

  context 'with the weather' do
    before { allow(Raindown::Forecast).to receive_messages(for: report, cached: report) }

    it "writes the weather now and the next days' where you are" do
      expect(described_class.new.rewrite).to eq(<<~TEXT.chomp)
        ╭────────────╮╭────────────╮
        │        ☁️  ││        🌦️  │
        │  Today     ││  Fri       │
        │  20° 10°   ││  19° 14°   │
        │  UV 8      ││  UV 4      │
        │            ││            │
        ╰────────────╯╰────────────╯
      TEXT
      expect(Raindown::Forecast).to have_received(:for).with(nil)
    end

    it 'writes the weather in a place it names' do
      described_class.new('Brisbane').rewrite
      expect(Raindown::Forecast).to have_received(:for).with('Brisbane')
    end

    it "gives the valley a named place's time of day, but not where you are's" do
      expect(described_class.new('Brisbane').rasterize(metadata:).to_h[:data][:utc_offset]).to eq(39_600)
      expect(described_class.new.rasterize(metadata:).to_h[:data]).not_to have_key(:utc_offset)
    end

    it "dims its cards' borders and emboldens their days" do
      expect(described_class.new.quiet(metadata:)).to eq(report.quiet)
      expect(described_class.new.bold(metadata:)).to eq([[2, 3, 8], [2, 17, 20]])
      expect(described_class.new.large(metadata:)).to eq([[1, 9, 11], [1, 23, 25]])
    end

    it 'gives the valley the weather it kept without waiting for Open-Meteo, asking for it again meanwhile' do
      asked = Queue.new
      allow(Raindown::Forecast).to receive(:for) do
        asked << true
        sleep 0.2
        report
      end

      started = Time.now
      expect(described_class.new.rasterize(metadata:).to_h[:data][:now]).to include(temperature: 19.7)
      expect(Time.now - started).to be < 0.1
      expect(asked.pop(timeout: 1)).to be(true)
    end

    it 'gives the valley the weather now, and its sky' do
      data = described_class.new.rasterize(metadata:).to_h[:data]

      expect(data[:now]).to eq(temperature: 19.7, unit: '°C', code: 3, words: 'overcast', uv: 9)
      expect(data[:sky]).to include(cloud: 1.0, rain: 0.0, temperature: 19.7)
    end
  end

  it "writes nothing for the weather when it can't be reached" do
    allow(Raindown::Forecast).to receive(:for).and_raise(Raindown::Forecast::Error, 'offline')
    expect(described_class.new.rewrite).to eq('')
  end

  context 'in a code project' do
    let(:branches) do
      [Raindown::BranchTree::Branch.new(name: 'login', depth: 0, commits: 4),
       Raindown::BranchTree::Branch.new(name: 'tests', depth: 1, commits: 1)]
    end

    before do
      File.write(File.join(@dir, '.raindown', 'config.yml'), "kind: code\n")
      allow(Raindown::BranchTree).to receive(:new).with(@dir).and_return(instance_double(Raindown::BranchTree, branches:))
    end

    it "doesn't write its branches, which only the valley shows" do
      expect(described_class.new.rewrite).to eq('')
    end

    it 'shows a valley, with its branches for their constellations, for the app to paint' do
      expect(described_class.new.rasterize(metadata:, width: 120).to_h)
        .to eq(painter: 'valley', data: { branches: [{ name: 'login', commits: 4 }, { name: 'tests', commits: 1 }], now: nil,
                                          sky: Raindown::Sky.of({}) })
    end
  end
end
