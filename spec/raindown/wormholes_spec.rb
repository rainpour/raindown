# frozen_string_literal: true

require 'raindown'
require 'raindown/nodes'
require 'raindown/rewriter'
require 'raindown/wormholes'
require 'helpers/nodes'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Wormholes do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  def write(name, content)
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  def found(path) = described_class.new(@root).in_file(path).map { [it.line, it.text, it.target, it.reason] }

  describe '#in_file' do
    it 'finds links to files that are not there, and to anchors no heading has, here or in another file' do
      write('guides/setup.md', "# Install\n")
      path = write('notes.md', "# Notes\n\n## Setup\n\n[Setup](#setup) [Typo](#setp)\n\n" \
                               "[Guide](guides/setup.md) [Install](guides/setup.md#install) [Run](guides/setup.md#run)\n\n" \
                               "[Gone](old.md) [Gone too](old.md#notes)\n")

      expect(found(path)).to eq([[5, 'Typo', '#setp', :heading], [7, 'Run', 'guides/setup.md#run', :heading],
                                 [9, 'Gone', 'old.md', :file], [9, 'Gone too', 'old.md#notes', :file]])
    end

    it "matches Commonmarker's ids, with -1 and -2 for the same heading again" do
      path = write('notes.md', "## Setup\n\n## Setup\n\n## Héllo *World*!\n\n" \
                               "[a](#setup-1) [b](#setup-2) [c](#héllo-world) [d](#h%C3%A9llo-world)\n")

      expect(found(path).map { it[2] }).to eq(['#setup-2'])
    end

    it 'counts headings a node wrote back into the file' do
      path = write('notes.md', "<{ SpecHeading: title='Written' }>\n<{ :SpecHeading }>\n\n[Written](#written)\n")
      expect(found(path).map { it[2] }).to eq(['#written'])

      Raindown::Rewriter.update(path:)
      expect(found(path)).to be_empty
    end

    it 'leaves out links in code, links to other sites, and templates' do
      path = write('notes.md', "`[a](#nope)`\n\n```md\n[b](missing.md)\n```\n\n" \
                               "[c](https://example.com/missing) [d](mailto:me@example.com) <https://example.com> [e]({url})\n")

      expect(found(path)).to be_empty
    end

    it 'finds reference links, links from the root, and links with a query or %-encoded spaces' do
      write('docs/my notes.md', "# Top\n")
      path = write('docs/index.md', "[ref][guide] [root](/docs/my%20notes.md?x=1#top) [rooted](/missing.md)\n\n[guide]: guide.md\n")

      expect(found(path)).to eq([[1, 'ref', 'guide.md', :file], [1, 'rooted', '/missing.md', :file]])
    end

    it 'reads anchors in files that are not Markdown as they are' do
      write('script.rb', "puts 1\n")
      path = write('notes.md', "[code](script.rb#L1)\n")

      expect(found(path)).to be_empty
    end
  end

  describe '#all' do
    it "finds the wormholes in each of the project's files, and the projects' inside it when asked" do
      write('a.md', "[x](missing.md)\n")
      write('inner/.raindown/.keep', '')
      write('inner/b.md', "[y](#nope)\n")

      expect(described_class.new(@root).all.map(&:target)).to eq(['missing.md'])
      expect(described_class.new(@root).all(nested: true).map(&:target)).to eq(['missing.md', '#nope'])
    end
  end

  describe '.close' do
    def close(content, target, to)
      path = write('notes.md', content)
      wormhole = described_class.new(@root).in_file(path).find { it.target == target }
      described_class.close(content, wormhole, to)
    end

    it 'points the link somewhere else, leaving the rest of the line alone, even after wide characters' do
      expect(close("é [#setp](#setp) [x](#setp)\n", '#setp', '#setup')).to eq("é [#setp](#setup) [x](#setp)\n")
    end

    it 'points a link over two lines somewhere else' do
      expect(close("A [long\nlink](old.md \"title\") here\n", 'old.md', 'new.md')).to eq("A [long\nlink](new.md \"title\") here\n")
    end

    it "changes a reference link's definition" do
      expect(close("[ref][guide]\n\n[guide]: old.md\n", 'old.md', 'new.md')).to eq("[ref][guide]\n\n[guide]: new.md\n")
    end
  end

  describe '.link' do
    it 'goes to a heading in its own file by its anchor, and to other files relative to it' do
      from = File.join(@root, 'docs/notes.md')

      expect(described_class.link(from:, to: from, id: 'setup')).to eq('#setup')
      expect(described_class.link(from:, to: File.join(@root, 'README.md'), id: 'install')).to eq('../README.md#install')
      expect(described_class.link(from:, to: File.join(@root, 'docs/guide.md'))).to eq('guide.md')
    end
  end

  describe Raindown::WormholeCount do
    it 'counts the wormholes in the project, as a stat written by wormholes:' do
      write('.raindown/.keep', '')
      write('other.md', "[a](#nope) [b](gone.md)\n")
      path = write('notes.md', "# Notes\n\n<{ wormholes: }>\n<{ :wormholes }>\n\n[c](#notes)\n")

      Raindown::Rewriter.update(path:, metadata: Raindown::Pages.for(path))

      expect(File.read(path)).to include("```\n▀▀█\n█▀▀\n▀▀▀\n2 wormholes\n```")
    end

    it 'says 1 wormhole' do
      write('notes.md', "[a](#nope)\n")
      stat = Raindown::WormholeCount.new

      expect(stat.card_lines(metadata: Raindown::Pages.load(root: @root)).last).to eq('1 wormhole')
    end
  end
end
