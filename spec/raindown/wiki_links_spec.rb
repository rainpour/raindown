# frozen_string_literal: true

require 'raindown'
require 'raindown/rewriter'
require 'tmpdir'

RSpec.describe Raindown::WikiLinks do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      FileUtils.mkdir_p(File.join(dir, 'notes'))
      File.write(File.join(dir, 'notes', 'Reading list.md'), "# Reading list\n\nbacklinks:\n")
      File.write(File.join(dir, 'today.md'), "---\ntitle: Today\n---\n\nSee [[reading list#To read]].\n")
      example.run
    end
  end

  def to_markdown(markdown)
    described_class.to_markdown(markdown, metadata: Raindown::Pages.for(File.join(@dir, 'today.md')))
  end

  it 'links to the file a name matches, by its path, whatever its case, with a heading or a label' do
    expect(to_markdown("[[Reading list]], [[notes/reading list#To read]] and [[Reading list|books]]\n"))
      .to eq('[Reading list](<notes/Reading list.md>), [notes/reading list > To read](<notes/Reading list.md#to-read>) ' \
             "and [books](<notes/Reading list.md>)\n")
  end

  it 'leaves links to no file, embeds, and links in code or front matter as they are' do
    markdown = "---\nrelated: '[[Reading list]]'\n---\n\n[[Nowhere]] ![[Reading list]] `[[Reading list]]`\n"

    expect(to_markdown(markdown)).to eq(markdown)
  end

  it 'lists the files that link to a file as its backlinks, written into it' do
    path = File.join(@dir, 'notes', 'Reading list.md')
    Raindown::Rewriter.update(path:, bare: true, metadata: Raindown::Pages.for(path))

    expect(File.read(path)).to eq("# Reading list\n\nbacklinks:\n- [Today](<today.md>)\n")
  end

  it 'knows the file pages were listed for' do
    expect(Raindown::Pages.for(File.join(@dir, 'today.md')).current.title).to eq('Today')
    expect(Raindown::NoMetadata.current).to be_nil
  end
end
