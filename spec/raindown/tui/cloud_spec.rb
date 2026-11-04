# frozen_string_literal: true

require 'raindown/tui/cloud'
require 'raindown/tui/feelings/celebration/scene'
require 'unicode/display_width'

RSpec.describe Raindown::TUI::Cloud do
  def scene(width, height) = Raindown::TUI::Scene.new(width:, height:, animations: [described_class])
  def text(lines) = lines.map { it.map(&:text).join }

  it "draws raindown.dev's rain cloud, each block in its blue, filling the screen, with its rain falling to the bottom" do
    lines = scene(70, 36).lines(0)
    cloud = text(lines).index { it.include?('█') }

    expect(text(lines).map { Unicode::DisplayWidth.of(it) }).to all(eq(70))
    expect(lines.flatten.map(&:style).uniq - [:blank]).to all(match(/\Acloud_\d+\z/))
    expect(text(lines)[cloud].strip).to eq('█▓▓▓▓▐█▓▓')
    expect(text(lines).last(12).join).to match(/[│╎┊',]/)
  end

  it 'rains down a row a tick, thinning out, while the cloud stays put' do
    frames = (0..8).map { text(scene(70, 36).lines(it)) }
    cloud = ->(frame) { frame.first(24).join }

    drops = frames[1][26].chars.each_index.reject { frames[1][26][it] == ' ' }
    expect([drops, drops.map { frames[1][26][it] }]).to match([be_any, drops.map { frames[0][25][it] }])
    expect(frames.map(&cloud).uniq.length).to eq(1)
  end

  it 'cuts the cloud to fit a small screen' do
    expect(text(scene(20, 8).lines(0)).map { Unicode::DisplayWidth.of(it) }).to all(eq(20))
  end
end
