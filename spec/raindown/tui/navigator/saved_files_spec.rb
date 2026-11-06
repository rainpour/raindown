# frozen_string_literal: true

require 'raindown/tui/navigator/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Navigator do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:toc) { "# Note\n\n<!-- toc: -->\n<!-- :toc -->\n" }
  # Stands in for Saves, telling of the paths saved since they were last taken.
  let(:saves) { Struct.new(:paths) { def take = paths.slice!(0..) }.new([]) }

  def save(navigator, name)
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, toc)
      saves.paths << path
      navigator.next_step(:tick)
    end
  end

  it 'leaves alone a file outside the projects of a folder of them' do
    FileUtils.mkdir_p(File.join(@root, 'docs/.raindown'))
    note = save(described_class.new(root: @root, saves:), 'plain/note.md')

    expect(File.read(note)).to eq(toc)
  end

  it 'writes back a file in a folder with no projects' do
    note = save(described_class.new(root: @root, saves:), 'note.md')

    expect(File.read(note)).to include('- [Note](#note)')
  end
end
