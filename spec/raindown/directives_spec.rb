# frozen_string_literal: true

require 'raindown/directives'

RSpec.describe Raindown::Directives do
  describe '.marker' do
    it 'marks a bare directive to show in bold, and one in delimiters or a comment to be left out' do
      expect(described_class.marker("files: folder: 'notes'")).to eq("<!-- raindown:directive files: folder: 'notes' -->")
      expect(described_class.marker("<{ :files }>\n")).to eq('<!-- raindown:hidden :files -->')
      expect(described_class.marker("<!-- files: folder: 'notes' -->\n")).to eq("<!-- raindown:hidden files: folder: 'notes' -->")
      expect(described_class.marker(':endpoint', shown: false)).to eq('<!-- raindown:hidden :endpoint -->')
    end

    it "reads a directive's text without its delimiters, whichever they are" do
      expect(['<{ toc: }>', '<!-- toc: -->', 'toc:'].map { described_class.text(it) }).to eq(%w[toc: toc: toc:])
      expect([described_class.bare?('toc:'), described_class.bare?('<!-- toc: -->')]).to eq([true, false])
    end

    it 'keeps -- from ending the comment early' do
      expect(described_class.marker('A: title=a--b')).to eq('<!-- raindown:directive A: title=a- -b -->')
    end
  end

  describe '.render' do
    let(:html) { "#{described_class.marker('A: x=<b>')}\n<p>Text.</p>" }

    it 'shows each directive in bold, escaped' do
      expect(described_class.render(html)).to eq("<p><strong>A: x=&lt;b&gt;</strong></p>\n<p>Text.</p>")
    end

    it 'leaves hidden directives out, but keeps other comments' do
      hidden = "#{described_class.marker('<!-- A: -->')}\n<p>Text.</p>\n<!-- a note -->\n"

      expect(described_class.render(hidden)).to eq("<p>Text.</p>\n<!-- a note -->\n")
    end
  end
end
