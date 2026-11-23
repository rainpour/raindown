# frozen_string_literal: true

require 'stringio'
require_relative '../../../lib/raindown/tui/curses_installer'

RSpec.describe Raindown::TUI::CursesInstaller do
  let(:output) { StringIO.new }
  let(:input) { StringIO.new.tap { |io| io.define_singleton_method(:tty?) { true } } }

  before do
    allow(described_class).to receive(:loadable?).and_return(false, true)
    allow(described_class).to receive(:bundled?).and_return(false)
  end

  # What "gem install curses" says and whether it worked.
  def gem_install(succeeded, log)
    allow(described_class).to receive(:run_gem_install).and_return([succeeded, log])
  end

  it 'loads curses without installing it when it is installed already' do
    allow(described_class).to receive(:loadable?).and_return(true)
    allow(described_class).to receive(:run_gem_install)
    expect([described_class.ensure_loaded(input:, output:), output.string]).to eq([true, ''])
    expect(described_class).not_to have_received(:run_gem_install)
  end

  it 'installs curses without asking, and loads it' do
    gem_install(true, "Building native extensions. This could take a while...\nSuccessfully installed curses-1.7.0\n")
    expect([described_class.ensure_loaded(input:, output:), output.string.lines.last]).to eq([true, "Installed curses in 0s\n"])
  end

  it 'says to add curses to the Gemfile when running through Bundler, as an installed gem would not load' do
    allow(described_class).to receive(:bundled?).and_return(true)
    expect([described_class.ensure_loaded(input:, output:), output.string])
      .to eq([false, "Add gem 'curses' to your Gemfile for Raindown's terminal app.\n"])
  end

  it 'says how to install curses without a terminal to install it for' do
    quiet = StringIO.new
    expect([described_class.ensure_loaded(input: quiet, output:), output.string.include?('gem install curses')]).to eq([false, true])
  end

  it 'asks for ncurses headers when curses fails to build' do
    gem_install(false, "Building native extensions.\nERROR:  Error installing curses:\n\tERROR: Failed to build gem native extension.\n")
    expect([described_class.ensure_loaded(input:, output:), output.string.include?('libncurses-dev')]).to eq([false, true])
  end

  it "asks to install curses for yourself without permission to write to Ruby's gems" do
    gem_install(false, "ERROR:  While executing gem ... (Gem::FilePermissionError)\n" \
                       "    You don't have write permissions for the /usr/lib/ruby/gems directory.\n")
    expect([described_class.ensure_loaded(input:, output:), output.string.include?('--user-install')]).to eq([false, true])
  end

  it 'says what went wrong otherwise, like being offline' do
    gem_install(false, "ERROR:  Could not find a valid gem 'curses' (~> 1.7), here is why:\n")
    described_class.ensure_loaded(input:, output:)
    expect(output.string.lines.first(2).map(&:strip))
      .to eq(["ERROR:  Could not find a valid gem 'curses' (~> 1.7), here is why:", 'Try again, or install it with: gem install curses'])
  end
end
