# frozen_string_literal: true

require 'raindown/bare_directives'

RSpec.describe Raindown::BareDirectives do
  describe '.expand' do
    it 'leaves nodes like toc:, :toc and files: to NodeBlocks' do
      content = "toc:\n\n:toc\n\nfiles: folder: 'notes'\n"

      expect(described_class.expand(content)).to eq(content)
    end

    it 'leaves for, if and list as text, since template directives are always in delimiters' do
      content = "if: draft\nThis is a draft.\n\nfor: tag in: tags\n- {tag}\n"

      expect(described_class.expand(content)).to eq(content)
    end

    it 'leaves front matter alone' do
      content = "---\nlist: a\nif: b\n---\n\nText.\n"

      expect(described_class.expand(content)).to eq(content)
    end

    # A bare endpoint shows in bold, so it's between markers in bold, around the delimited endpoint that renders.
    def bold(text) = "<!-- raindown:directive #{text} -->\n"
    def curl = "```sh\ncurl x\n```\n"

    it 'closes an endpoint after the code blocks it holds, in bold' do
      content = "endpoint:\n\n#{curl}\n```json\n{}\n```\n\nAfter\n"

      expect(described_class.expand(content))
        .to eq("#{bold('endpoint:')}<{ endpoint: }>\n\n#{curl}\n```json\n{}\n```\n<{ :endpoint }>\n#{bold(':endpoint')}\nAfter\n")
    end

    it 'shows a schema in bold, with its fields in a code block' do
      expect(described_class.expand("schema: 'User'\n  name: String\n  address:\n    city: String\nAfter\n"))
        .to eq("#{bold("schema: 'User'").chomp}\n```\nname: String\naddress:\n  city: String\n```\nAfter\n")
    end

    it 'only closes around code blocks directly below' do
      content = "endpoint:\n#{curl}Text\n```\nother\n```\n"

      expect(described_class.expand(content))
        .to eq("#{bold('endpoint:')}<{ endpoint: }>\n#{curl}<{ :endpoint }>\n#{bold(':endpoint')}Text\n```\nother\n```\n")
    end

    it 'closes an endpoint before another curl example' do
      content = "endpoint:\n\n#{curl}\n```sh\ncurl y\n```\n"

      expect(described_class.expand(content))
        .to eq("#{bold('endpoint:')}<{ endpoint: }>\n\n#{curl}<{ :endpoint }>\n#{bold(':endpoint')}\n```sh\ncurl y\n```\n")
    end

    it 'closes an endpoint with nothing below it straight away, or at the end of the file' do
      expect(described_class.expand("endpoint:\n\nText"))
        .to eq("#{bold('endpoint:')}<{ endpoint: }>\n<{ :endpoint }>\n#{bold(':endpoint')}\nText")
      expect(described_class.expand("endpoint:\n```sh\ncurl x\n```"))
        .to eq("#{bold('endpoint:')}<{ endpoint: }>\n#{curl}<{ :endpoint }>\n#{bold(':endpoint')}")
    end

    it 'keeps up to three spaces of indent' do
      expect(described_class.expand("   endpoint:  \n"))
        .to eq("#{bold('endpoint:')}   <{ endpoint: }>\n   <{ :endpoint }>\n#{bold(':endpoint')}")
    end

    {
      'inline in prose' => "Use :toc here.\n",
      'indented as code' => "    :toc\n",
      'in a backtick fence' => "```\n:toc\n```\n",
      'in a tilde fence' => "~~~\n:toc\n~~~\n",
      'an unknown keyword' => ":foo\n",
      'an end tag, since bare directives have none' => ":list\n",
      'a keyword without a space before its arguments' => "endpoint:api\n",
      'a capitalised keyword' => "Endpoint:\n",
      'an emoji shortcode' => ":toc:\n",
      'already wrapped' => "<{ :toc }>\n"
    }.each do |description, content|
      it "leaves a directive #{description} alone" do
        expect(described_class.expand(content)).to eq(content)
      end
    end
  end

  describe '.enabled?' do
    it 'is enabled by the flag or a Raindown file' do
      expect(described_class.enabled?(path: 'notes.md', bare: true)).to be(true)
      expect(described_class.enabled?(path: 'notes.rd')).to be(true)
    end

    it 'is disabled for Markdown files' do
      expect(described_class.enabled?(path: 'notes.md')).to be(false)
    end
  end

  describe '.file?' do
    it 'is true for Raindown extensions' do
      expect(%w[notes.rd notes.raindown NOTES.RD].map { |path| described_class.file?(path) }).to all(be(true))
    end

    it 'is false for Markdown and no path' do
      expect([described_class.file?('notes.md'), described_class.file?(nil)]).to all(be(false))
    end
  end

  describe '.enabled?' do
    it 'is true for Raindown files, raindown: true front matter and --bare' do
      expect(described_class.enabled?(path: 'notes.rd')).to be(true)
      expect(described_class.enabled?(path: 'notes.md', content: "---\nraindown: true\n---\n")).to be(true)
      expect(described_class.enabled?(path: 'notes.md', bare: true)).to be(true)
    end

    it 'is false for other Markdown files' do
      expect(described_class.enabled?(path: 'notes.md', content: "# Notes\n")).to be(false)
    end
  end

  describe '.front_matter?' do
    it 'is true when the front matter sets raindown: true' do
      expect(described_class.front_matter?("---\ntitle: Notes\ndate: 2026-10-13\nraindown: true\n---\n\n# Notes\n")).to be(true)
    end

    {
      'raindown: false' => "---\nraindown: false\n---\n",
      'a string' => "---\nraindown: 'yes'\n---\n",
      'no raindown key' => "---\ntitle: Notes\n---\n",
      'a nested raindown key' => "---\nsite:\n  raindown: true\n---\n",
      'raindown: true outside front matter' => "# Notes\n\nraindown: true\n",
      'front matter that is not at the start' => "# Notes\n\n---\nraindown: true\n---\n",
      'unclosed front matter' => "---\nraindown: true\n",
      'front matter that is not YAML' => "---\nraindown: [\n---\n"
    }.each do |description, content|
      it "is false for #{description}" do
        expect(described_class.front_matter?(content)).to be(false)
      end
    end
  end
end
