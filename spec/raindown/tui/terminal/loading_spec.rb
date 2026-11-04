# frozen_string_literal: true

require 'raindown/tui/terminal/screen'

RSpec.describe Raindown::TUI::Loading do
  # A Screen's start and drawing, without curses, which Loading's prepended to.
  let(:screen_class) do
    loading = described_class
    Class.new do
      prepend loading

      attr_reader :navigator

      def initialize(&loading)
        @loading = loading
      end

      def frames = @frames ||= []

      private

      def start = nil
      def draw(lines) = frames << lines
    end
  end

  before { allow(Curses).to receive_messages(cols: 80, lines: 30) }

  it 'draws the rain cloud over the whole screen, a frame each animation tick, until the Navigator is made' do
    screen = screen_class.new { sleep(0.2).then { :navigator } }
    screen.send(:start)

    expect([screen.navigator, screen.frames.length, screen.frames.first.length]).to match([:navigator, be_between(3, 5), 30])
    expect(screen.frames.flatten.map(&:text).join).to include('█')
  end

  it 'raises what went wrong making the Navigator' do
    expect { screen_class.new { raise 'No nodes' }.send(:start) }.to raise_error('No nodes')
  end
end
