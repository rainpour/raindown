# frozen_string_literal: true

require 'raindown/tui/navigator/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Navigator, 'wormholes' do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  def write(name, content = "# #{name}\n")
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  subject(:navigator) { described_class.new(root: @root, path: write('notes.md', wormholes)) }

  let(:wormholes) { "# Notes\n\nSee [setup](#setp).\n\n## Setup\n\n[Guide](guide.md)\n" }

  before { write('guides/setup.md', "# Install\n\n## Getting started\n") }

  def type(navigator, text) = text.each_char { navigator.next_step(Raindown::TUI::Type.new(text: it)) }
  def found(navigator) = navigator.matches.map { [it.text, it.where] }
  def select(navigator, text) = navigator.view.cursor = navigator.view.rows.index { it.text == text }

  it 'marks each link that leads nowhere in the outline, with why, under its heading like a directive' do
    expect(navigator.view.rows.map { [it.kind, it.text, it.depth] })
      .to eq([[:heading, '# Notes', 0], [:wormhole, '🕳 #setp: no such heading', 1], [:heading, '## Setup', 1],
              [:wormhole, '🕳 guide.md: no such file', 2]])
  end

  it 'lists them in the search by wormhole or 🕳, and teleports to their line' do
    navigator.next_step(:search)
    type(navigator, 'wormhole')
    expect(found(navigator)).to eq([['🕳 Wormhole #setp: no such heading', 'notes.md:3'],
                                    ['🕳 Wormhole guide.md: no such file', 'notes.md:7']])

    navigator.next_step(:escape)
    navigator.next_step(:search)
    type(navigator, '🕳 guide')
    navigator.next_step(:enter)
    expect(navigator.view.rows[navigator.view.cursor].text).to eq('🕳 guide.md: no such file')
  end

  it 'closes one with Enter, by teleporting to the nearest heading, which its link then goes to' do
    select(navigator, '🕳 #setp: no such heading')
    navigator.next_step(:enter)

    expect([navigator.searching?, navigator.query, navigator.closing.target]).to eq([true, 'setp', '#setp'])
    expect(found(navigator).first).to eq(['## Setup', 'notes.md:5'])

    navigator.next_step(:enter)
    expect(File.read(File.join(@root, 'notes.md'))).to include('See [setup](#setup).')
    expect(navigator.status).to eq([:info, 'Closed the wormhole on line 3, to #setup'])
    expect(navigator.view.rows.map(&:text)).not_to include('🕳 #setp: no such heading')
  end

  it 'closes a link to a missing file with a file, or a heading in another one, relative to it, or not with Esc' do
    select(navigator, '🕳 guide.md: no such file')
    navigator.next_step(:enter)
    expect(navigator.query).to eq('guide.md')
    expect(found(navigator).first).to eq(['guides/setup.md', ''])

    navigator.next_step(:escape)
    expect(navigator.closing).to be_nil

    select(navigator, '🕳 guide.md: no such file')
    navigator.next_step(:enter)
    8.times { navigator.next_step(:backspace) }
    type(navigator, 'getting')
    expect(found(navigator).first).to eq(['## Getting started', 'guides/setup.md:3'])
    navigator.next_step(:enter)
    expect(File.read(File.join(@root, 'notes.md'))).to include('[Guide](guides/setup.md#getting-started)')
  end

  it "shows an error when the link's changed since it was read" do
    select(navigator, '🕳 #setp: no such heading')
    navigator.next_step(:enter)
    File.write(File.join(@root, 'notes.md'), "# Notes\n\nGone.\n")
    navigator.next_step(:enter)

    expect(navigator.status).to eq([:error, 'That wormhole has changed since it was read'])
  end
end
