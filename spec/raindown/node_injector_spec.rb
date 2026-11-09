# frozen_string_literal: true

require 'raindown/node_injector'
require 'helpers/nodes'

RSpec.describe Raindown::NodeInjector do
  def rewrite(content, path: 'notes.md')
    described_class.rewrite(content:, path:)
  end

  it 'writes a node between its tags, with no blank lines around it' do
    expect(rewrite("<!-- SpecReleases: limit=2 -->\n<!-- :SpecReleases -->\n\nText.\n"))
      .to eq("<!-- SpecReleases: limit=2 -->\n- **1.2.0** Bare\n- **1.1.0** Fetched\n<!-- :SpecReleases -->\n\nText.\n")
  end

  it "leaves a node in Antlers' delimiters alone, as it only renders" do
    content = "<{ SpecReleases: limit=2 }>\n<{ :SpecReleases }>\n\nText.\n"

    expect(rewrite(content)).to eq(content)
  end

  it 'writes bare nodes in Markdown with raindown: true front matter' do
    expect(rewrite("---\nraindown: true\n---\n\nSpecReleases: limit=1\n"))
      .to eq("---\nraindown: true\n---\n\nSpecReleases: limit=1\n- **1.2.0** Bare\n")
  end

  it 'writes a bare node straight below it' do
    expect(rewrite("SpecReleases: limit=1\n\nText.\n", path: 'notes.rd')).to eq("SpecReleases: limit=1\n- **1.2.0** Bare\n\nText.\n")
  end

  it 'replaces what it wrote before' do
    content = "SpecReleases: limit=1\n- old\n- older\n\nText.\n"

    expect(rewrite(content, path: 'notes.rd')).to eq("SpecReleases: limit=1\n- **1.2.0** Bare\n\nText.\n")
  end

  it 'is idempotent' do
    once = rewrite("<!-- SpecParagraphs: -->\n<!-- :SpecParagraphs -->\n\nSpecReleases:\n", path: 'notes.rd')

    expect(rewrite(once, path: 'notes.rd')).to eq(once)
  end

  it 'raises when a bare node writes blank lines' do
    expect { rewrite("SpecParagraphs:\n", path: 'notes.rd') }
      .to raise_error(described_class::BlankLine, /needs <!-- SpecParagraphs: --> and <!-- :SpecParagraphs -->/)
  end

  it "writes a node's comment straight below its directive, and gives it back to it the next time" do
    once = rewrite("<!-- SpecRuns: -->\n<!-- :SpecRuns -->\n")

    expect(once).to eq("<!-- SpecRuns: -->\n<!-- run 1 -->\nRan.\n<!-- :SpecRuns -->\n")
    expect(rewrite(once)).to eq("<!-- SpecRuns: -->\n<!-- run 2 -->\nRan.\n<!-- :SpecRuns -->\n")
    expect(rewrite(rewrite("SpecRuns:\n", path: 'notes.rd'), path: 'notes.rd')).to eq("SpecRuns:\n<!-- run 2 -->\nRan.\n")
  end

  it "writes over a comment below a node's directive when the node has none" do
    expect(rewrite("SpecReleases: limit=1\n<!-- run 1 -->\n- old\n", path: 'notes.rd')).to eq("SpecReleases: limit=1\n- **1.2.0** Bare\n")
  end

  it "leaves a node's comment out of its HTML" do
    html = Raindown.render(markdown: "<{ :SpecRuns }>\n")

    expect(html).to include('Ran.')
    expect(html).not_to include('run')
  end

  it 'leaves content without node blocks unchanged' do
    content = "Note: this is prose.\n"

    expect(rewrite(content, path: 'notes.rd')).to eq(content)
  end
end
