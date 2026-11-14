# frozen_string_literal: true

require 'raindown'

RSpec.describe Raindown::Code do
  describe '.scanned_ranges' do
    def code(markdown)
      described_class.scanned_ranges(markdown).map { markdown.byteslice(it) }
    end

    it 'finds code spans, between runs of as many backticks' do
      expect(code("A `span`, ``one ` inside`` and ```three```.\n")).to eq(['`span`', '``one ` inside``', '```three```'])
    end

    it 'passes over a run of backticks that opens no span' do
      expect(code("An odd `` run, then `a span`, and a last `\n")).to eq(['`a span`'])
    end

    it 'leaves a run of another length inside a span' do
      expect(code("`a``b` and ``c`d``\n")).to eq(['`a``b`', '``c`d``'])
    end

    it 'counts bytes, so text of several bytes before a span moves it' do
      expect(code("Ünï `cödé` ünd `more`\n")).to eq(['`cödé`', '`more`'])
    end

    it 'finds fenced blocks whole, with spans on the lines around them' do
      markdown = "A `span`\n```rb\n`not` a span\n```\nand `another`\n"

      expect(code(markdown)).to eq(['`span`', "```rb\n`not` a span\n```\n", '`another`'])
    end

    it 'finds nothing in lines without backticks' do
      expect(code("Plain text\n\nand {braces}\n")).to be_empty
    end
  end

  describe '.hide_braces' do
    it 'swaps the braces in code for placeholders, and leaves the rest' do
      hidden = Raindown.rendering(highlight_code: true, commonmark: false) { described_class.hide_braces("{a} `{b}`\n") }

      expect(hidden).to eq("{a} `\u{E000}b\u{E001}`\n")
    end
  end
end
