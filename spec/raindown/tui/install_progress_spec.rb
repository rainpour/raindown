# frozen_string_literal: true

require 'stringio'
require_relative '../../../lib/raindown/tui/install_progress'

RSpec.describe Raindown::TUI::InstallProgress do
  let(:output) { StringIO.new }
  let(:progress) { described_class.new(output) }

  it 'sweeps its mark across the bar and back' do
    bars = [0, 1, 21, 22].map { |frame| progress.line(frame)[/\[(.*)\]/, 1] }
    expect(bars).to eq(["===#{' ' * 21}", " ===#{' ' * 20}", "#{' ' * 21}===", "#{' ' * 20}=== "])
  end

  it 'shows the step it is on and the seconds so far' do
    progress.step = 'Building'
    expect(progress.line(0)).to match(/\ABuilding curses for Raindown's terminal app \[.*\] 0s\z/)
  end

  it 'says what it is doing once without a terminal to draw in' do
    checks = 0
    progress.show_until { (checks += 1) > 2 }
    expect(output.string).to eq("Installing curses for Raindown's terminal app...\n")
  end
end
