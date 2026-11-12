# frozen_string_literal: true

require 'raindown'
require 'raindown/rasters'
require 'tmpdir'

RSpec.describe Raindown::Rasters do
  it 'names the nodes that rasterize' do
    expect(described_class.names).to eq(['weather'])
  end

  it "rasterizes the node on a line, in an outdent block too, and says there's none on another" do
    allow(Raindown::Forecast).to receive(:for).and_return(nil)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      path = File.join(dir, 'dashboard.md').tap { File.write(it, "---\nraindown: true\n---\n\n^^^^\n< weather:\n") }

      expect(described_class.rasterize(path:, line: 5, width: 40, height: 20)[:painting])
        .to eq(painter: 'valley', data: { branches: [], now: nil, sky: Raindown::Sky.of({}) })
      expect { described_class.rasterize(path:, line: 4, width: 40, height: 20) }.to raise_error(ArgumentError, /line 5/)
    end
  end

  it "gives an app a node's own pixels as their bytes" do
    raster = Raindown::Raster.new(2, 1).tap { it[1, 0] = 0x88c0d0 }

    expect(raster.to_h).to eq(painter: 'pixels', width: 2, height: 1, pixels: ['000000ff88c0d0ff'].pack('H*').then { [it].pack('m0') })
  end
end
