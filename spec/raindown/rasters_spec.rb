# frozen_string_literal: true

require 'raindown'
require 'raindown/rasters'
require 'tmpdir'

RSpec.describe Raindown::Rasters do
  it 'names the nodes that rasterize' do
    expect(described_class.names).to eq(['weather'])
  end

  it "rasterizes the node on a line, in an outdent block too, and says there's none on another" do
    allow(Raindown::Forecast).to receive_messages(for: nil, cached: nil)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      path = File.join(dir, 'dashboard.md').tap { File.write(it, "---\nraindown: true\n---\n\n^^^^\n< weather:\n") }

      expect(described_class.repaint(path:, line: 5, width: 40, height: 20)[:painting])
        .to eq(painter: 'valley', data: { branches: [], now: nil, sky: Raindown::Sky.of({}) })
      expect { described_class.repaint(path:, line: 4, width: 40, height: 20) }.to raise_error(ArgumentError, /line 5/)
    end
  end

  context 'with a JavaScript Component that rasterizes' do
    # A host answering as QuickJS would, with the component the folder's file has.
    let(:host) do
      Class.new do
        def request(**message)
          return {} unless message[:op] == 'load'

          { 'nodes' => [{ 'name' => 'SpecJsSky', 'render' => false, 'rasterize' => true, 'file' => 'spec_js_sky.js' }] }
        end
      end.new
    end
    let(:source) { "export class SpecJsSky { rewrite() { return '' } rasterize(area) {} }\n" }

    around do |example|
      Raindown::JSNodes.host = host
      example.run
    ensure
      Raindown::JSNodes.host = nil
      Raindown::JSNodes.node_classes.delete('SpecJsSky')
    end

    it "names it for its project's files, and gives an app its source and props to run its rasterize with" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'spec_js_sky.js'), source)
        path = File.join(dir, 'dashboard.md').tap { File.write(it, "---\nraindown: true\n---\n\nSpecJsSky: stars: 3\n") }

        expect(described_class.names(path)).to eq(%w[weather SpecJsSky])
        expect(described_class.repaint(path:, line: 4, width: 40, height: 20)[:painting])
          .to eq(painter: 'node', data: { node: 'SpecJsSky', source:, args: [], props: { stars: 3 }, root: File.expand_path(dir) })
      end
    end

    it "finds it in a grid's cell by the column its cell starts at" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'spec_js_sky.js'), source)
        grid = "grid:\n+----------+----------------+\n| a        | SpecJsSky:     |\n+----------+----------------+\n"
        path = File.join(dir, 'dashboard.md').tap { File.write(it, "---\nraindown: true\n---\n\n#{grid}") }

        expect(described_class.repaint(path:, line: 6, column: 12, width: 40, height: 20)[:painting])
          .to include(painter: 'node', data: include(node: 'SpecJsSky'))
        expect { described_class.repaint(path:, line: 6, column: 1, width: 40, height: 20) }.to raise_error(ArgumentError, /line 7/)
      end
    end
  end

  context "with a project's Ruby node that paints its own pixels" do
    let(:source) do
      <<~RUBY
        class SpecRubyDots < Raindown::Node
          def rewrite = ''

          def rasterize(area:, raindown:)
            area.pixels[1, 0] = 0x88c0d0
            area.button(x: 0, y: 0, width: 1, height: 1, set: { dots: 2 })
            raindown.root && 250
          end
        end
      RUBY
    end

    after { Object.send(:remove_const, :SpecRubyDots) if Object.const_defined?(:SpecRubyDots) }

    it 'names it, and gives an app its pixels, those it left clear, its buttons, and when to paint it again' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'spec_ruby_dots.rb'), source)
        path = File.join(dir, 'dashboard.md').tap { File.write(it, "---\nraindown: true\n---\n\nSpecRubyDots:\n") }

        expect(described_class.names(path)).to eq(%w[weather SpecRubyDots])
        expect(described_class.repaint(path:, line: 4, width: 2, height: 1)[:painting])
          .to eq(painter: 'pixels', width: 2, height: 1, pixels: [['0000000088c0d0ff'].pack('H*')].pack('m0'),
                 buttons: [{ x: 0, y: 0, width: 1, height: 1, set: { dots: 2 } }], again: 250)
      end
    end
  end

  it 'paints all of its pixels at once, as 0xRRGGBB, and gives no time to paint it again unless asked' do
    area = Raindown::Area.new(width: 2, height: 1).tap { it.pixels = [0x2e3440, 0x88c0d0] }

    expect(area.to_h).to include(pixels: [['2e3440ff88c0d0ff'].pack('H*')].pack('m0'), again: nil)
  end
end
