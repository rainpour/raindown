# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::MarkdownNodes do
  def project(files)
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, '.raindown'))
    files.each { |name, source| File.write(File.join(dir, '.raindown', name), source) }
    Raindown::Nodes.load(File.join(dir, 'notes.rd'))
    dir
  end

  let(:card) { "---\nrating: 0\n---\n\n**{title}** {rating}/5\n<{ if: value }>\n\n> {value}\n<{ :if }>\n" }

  it 'writes its template with its props, after the defaults in its front matter' do
    project('SpecBookCard.md' => card)

    markdown = Raindown::NodeInjector.rewrite(content: "SpecBookCard: title: The Left Hand rating: 5\n\nAfter\n", bare: true)

    expect(markdown).to eq("SpecBookCard: title: The Left Hand rating: 5\n**The Left Hand** 5/5\n\nAfter\n")
    expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecBookCard: title: Dune -->\n<!-- :SpecBookCard -->\n"))
      .to include("**Dune** 0/5\n")
  end

  it 'gives the value before its props as {value}, and writes braces in code back as braces' do
    project('SpecQuote.rd' => "{value}\n`{kept}`\n")

    expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecQuote: 'Be kind' -->\n<!-- :SpecQuote -->\n"))
      .to eq("<!-- SpecQuote: 'Be kind' -->\nBe kind\n`{kept}`\n<!-- :SpecQuote -->\n")
  end

  it 'is only a file named like a component, so blueprints.md is not one' do
    expect(described_class.file?('.raindown/BookCard.md')).to be(true)
    expect(described_class.file?('.raindown/blueprints.md')).to be(false)
    expect(described_class.file?('.raindown/BookCard.rb')).to be(false)
  end
end
