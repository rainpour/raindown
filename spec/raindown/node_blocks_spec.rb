# frozen_string_literal: true

require 'fileutils'
require 'raindown'
require 'raindown/editing'
require 'raindown/rewriter'
require 'helpers/nodes'
require 'tmpdir'

RSpec.describe Raindown::NodeBlocks do
  def find(markdown, bare: false)
    described_class.find(markdown.lines, front_matter: Raindown::FrontMatter.parse(markdown).first, bare:)
                   .map { |block| block.except(:node).merge(node: block[:node].class) }
  end

  describe '.find' do
    it "finds a block in Antlers' delimiters, which only renders, or in comments, which writes, up to its end tag" do
      expect(find("<{ SpecReleases: limit=2 }>\n\n- old\n\n<{ :SpecReleases }>\n"))
        .to eq([{ open: 0, close: 4, last: 4, writes: false, node: SpecReleases }])
      expect(find("<!-- SpecReleases: limit=2 -->\n\n- old\n\n<!-- :SpecReleases -->\n"))
        .to eq([{ open: 0, close: 4, last: 4, writes: true, node: SpecReleases }])
      expect { find("<!-- SpecReleases: -->\n<{ :SpecReleases }>\n") }
        .to raise_error(described_class::MissingEndTag, /line 1 needs <!-- :SpecReleases -->/)
    end

    it 'raises when a delimited block has no end tag' do
      expect { find("<{ SpecReleases: }>\n\nText.\n") }
        .to raise_error(described_class::MissingEndTag, /line 1 needs <\{ :SpecReleases \}>/)
    end

    it 'ends a bare block at the next blank line, with fenced code kept whole' do
      expect(find("SpecReleases: limit=2\n- a\n```\nb\n\nc\n```\n\nText.\n", bare: true))
        .to eq([{ open: 0, close: nil, last: 6, writes: true, node: SpecReleases }])
      expect(find("SpecReleases:\n\nText.\n", bare: true)).to eq([{ open: 0, close: nil, last: 0, writes: true, node: SpecReleases }])
    end

    it 'only reads bare blocks when asked' do
      expect(find("SpecReleases:\n")).to eq([])
    end

    it 'leaves names that are not nodes alone' do
      expect(find("Note: this is prose.\n\n<{ Unknown: }>\n", bare: true)).to eq([])
    end

    it 'skips code and front matter' do
      expect(find("---\nSpecReleases: 1\n---\n\n```\n<{ SpecReleases: }>\n```\n", bare: true)).to eq([])
    end

    it 'reads a variable in braces in a comment or bare, and without them in Antlers delimiters' do
      markdown = "---\ncount: 1\n---\n<!-- SpecReleases: limit={count} -->\n<!-- :SpecReleases -->\n\n" \
                 "SpecReleases: limit={count}\n\n<{ SpecReleases limit=count }>\n"
      allow(Raindown::Nodes).to receive(:instance).and_call_original
      find(markdown, bare: true)

      expect(Raindown::Nodes).to have_received(:instance).with(SpecReleases, { limit: 1 }).exactly(3).times
    end

    it 'shares one instance between blocks with the same node and props' do
      lines = "SpecReleases: limit=2\n\nSpecReleases: limit=2\n\nSpecReleases: limit=1\n".lines
      nodes = described_class.find(lines, bare: true).map { |block| block[:node] }

      expect(nodes[0]).to be(nodes[1])
      expect(nodes[0]).not_to be(nodes[2])
    end
  end

  describe 'values a node takes' do
    it "names the directive and its line when it's missing a value, rather than Ruby's wrong number of arguments" do
      stub_const('SpecNeedsTwo', Class.new(Raindown::Node) do
        def initialize(first, second = nil); end

        def rewrite
          ''
        end
      end)

      node = described_class.find("# A\n\n<!-- SpecNeedsTwo: -->\n<!-- :SpecNeedsTwo -->\n".lines).first[:node]

      expect(node).to be_a(Raindown::Problem)
      expect([node.message, node.warning]).to eq(['Needs a value after it', 'line 3: SpecNeedsTwo: needs a value after it'])
      expect(find("<!-- SpecNeedsTwo: 'a' -->\n<!-- :SpecNeedsTwo -->\n").first[:node]).to eq(SpecNeedsTwo)
    end

    it 'names the directive and its line when it has a value it takes none of' do
      node = described_class.find("# A\n\ntoc: extra\n".lines, bare: true).first[:node]

      expect(node.message).to eq("Takes no value, so it can't read \"extra\"")
    end
  end

  it 'writes why a directive can\'t run in its place, and the rest of the file as usual' do
    stub_const('SpecBroken', Class.new(Raindown::Node) do
      def rewrite
        raise 'no data today'
      end
    end)
    markdown = "# A\n\n<!-- toc: extra -->\n<!-- :toc -->\n\n<!-- SpecBroken: -->\n<!-- :SpecBroken -->\n\n" \
               "<!-- toc: -->\n<!-- :toc -->\n"
    rewrite = Raindown::Rewriter.rewrite(content: markdown, path: 'notes.md')

    expect(rewrite.content).to include("<!-- toc: extra -->\n> [!WARNING]\n> Takes no value, so it can't read \"extra\"\n")
      .and include("<!-- SpecBroken: -->\n> [!WARNING]\n> Couldn't write: no data today\n")
      .and include("<!-- toc: -->\n- [A](#a)\n")
    expect(rewrite.problems).to eq(["line 3: toc: takes no value, so it can't read \"extra\"", "line 6: couldn't write: no data today"])
    expect(Raindown::Editing.rewrite_markdown(markdown, path: 'notes.md')[:warnings]).to eq(rewrite.problems)
  end

  it "writes messages that don't read as directives, once the directive above them is deleted" do
    markdown = "# A\n\ntoc: extra\n\n## B\n"
    written = Raindown::Rewriter.rewrite(content: markdown, path: 'notes.rd').content
    orphaned = written.sub("toc: extra\n", '')

    expect(Raindown::Rewriter.rewrite(content: orphaned, path: 'notes.rd')).to have_attributes(content: orphaned, problems: [])
  end

  describe '.props' do
    it 'reads quoted text, numbers, booleans and variables' do
      variables = Raindown::Variables.new(author: { name: 'Mark' })
      props = described_class.props(%(a='x y' b="z" c=3 d=1.5 e=true f=author.name g=missing), variables)

      expect(props).to eq(a: 'x y', b: 'z', c: 3, d: 1.5, e: true, f: 'Mark', g: nil)
    end

    it 'reads a word as text, and only a word in braces as a variable, outside Antlers delimiters' do
      variables = Raindown::Variables.new(author: { name: 'Mark' })
      props = described_class.props("a=notes b='x y' c=3 d={author.name} e=author.name", variables, antlers: false)

      expect(props).to eq(a: 'notes', b: 'x y', c: 3, d: 'Mark', e: 'author.name')
    end

    it 'reads unquoted text after name: up to the next prop, like YAML, and one word after name=' do
      props = described_class.props('title: Hello world limit: 3 note: See: below tag=a', Raindown::Variables.new({}), antlers: false)

      expect(props).to eq(title: 'Hello world', limit: 3, note: 'See: below', tag: 'a')
      expect(described_class.args('Big news limit: 2', Raindown::Variables.new({}), antlers: false)).to eq([{ limit: 2 }, ['Big news']])
    end

    it 'reads a comma between values like a space, as people write them' do
      variables = Raindown::Variables.new({})
      read = ->(text) { described_class.args(text, variables, antlers: false) }

      expect(read.call('raindown/data.csv, total: true')).to eq([{ total: true }, ['raindown/data.csv']])
      expect(read.call('"a b.csv", total: true')).to eq([{ total: true }, ['a b.csv']])
      expect(read.call('x.csv,total: true')).to eq([{ total: true }, ['x.csv']])
      expect(read.call('tags: book, order: rating')).to eq([{ tags: 'book', order: 'rating' }])
      expect(read.call('limit=3, total: true')).to eq([{ limit: 3, total: true }])
      expect(read.call('title: Hello, world')).to eq([{ title: 'Hello, world' }])
    end

    it "raises on text that isn't a prop, like a word after quoted text, and on a variable with spaces" do
      expect { described_class.props("limit=3 title: 'Hello' world", Raindown::Variables.new({})) }
        .to raise_error(Raindown::NodeBlocks::BrokenText, /\ACan't read world in limit=3 title: 'Hello' world/)
      expect { described_class.props('title: Hello world', Raindown::Variables.new({})) }
        .to raise_error(Raindown::NodeBlocks::BrokenText, /\ACan't read Hello world as a variable/)
    end

    it 'reads nil, false, negative numbers and symbols as values' do
      props = described_class.props('a=nil b=false c=-2 d=:draft', Raindown::Variables.new(nil: 'x'))

      expect(props).to eq(a: nil, b: false, c: -2, d: :draft)
    end

    it 'reads variables as the data they are, with their braces, by key and index but not method' do
      variables = Raindown::Variables.new(rows: [{ name: '{a}', count: 1 }], tags: %w[x y])

      expect(described_class.props('a=rows b=tags.0 c=tags.size d=tags.clear', variables))
        .to eq(a: [{ name: '{a}', count: 1 }], b: 'x', c: 2, d: nil)
    end
  end

  describe '.args' do
    let(:none) { Raindown::Variables.new({}) }

    it 'reads a value before the props as the argument' do
      expect(described_class.args("'data.csv' format: 'columns'", none)).to eq([{ format: 'columns' }, ['data.csv']])
      expect(described_class.args('stats', Raindown::Variables.new(stats: { a: 1 }))).to eq([{}, [{ a: 1 }]])
    end

    it 'has no argument when the props come first' do
      expect(described_class.args('limit=2 b: 3', none)).to eq([{ limit: 2, b: 3 }])
      expect(described_class.args('', none)).to eq([{}])
    end
  end

  describe '.to_rendered' do
    it 'only renders a node in <{ }>, with the Markdown between its tags as its slot, and never its rewrite' do
      html = Raindown.render(markdown: "<{ SpecWrapper: }>\n**Hi**\n<{ :SpecWrapper }>\n\n<{ :SpecWrapper }>\n")

      expect(html).to include("<aside><p><strong>Hi</strong></p>\n</aside>", '<aside></aside>')
    end

    it 'raises when a node in <{ }> has no render' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'spec_unrendered.rb'), "class SpecUnrendered < LowNode\n  def rewrite = 'Written'\nend\n")
        Raindown::Nodes.load(File.join(dir, 'notes.md'))

        expect { Raindown.render(markdown: "<{ :SpecUnrendered }>\n") }
          .to raise_error(Raindown::Nodes::NoRender, /SpecUnrendered has no render/)
      end
    end

    it "doesn't render a node that writes edits back, without its own render, so a preview never writes" do
      expect { Raindown.render(markdown: "<{ SpecSynced }>\n") }.to raise_error(Raindown::Nodes::NoRender, /SpecSynced writes edits back/)
    end

    it 'swaps a node with HTML for its fragment, and one without for its Markdown, between markers, in bold when bare' do
      markdown = "<!-- SpecReleases: limit=1 -->\n- old\n<!-- :SpecReleases -->\n\n<{ SpecHeading }>\n\nSpecHeading: title='Hi'\n"
      rendered = described_class.to_rendered(Raindown::Context.new(document: markdown, bare: true))

      expect(rendered).to match(/\A<!-- raindown:hidden SpecReleases: limit=1 -->\n<!-- raindown:fragment \d+ -->\n/)
        .and include("<!-- raindown:hidden :SpecReleases -->\n\n<{ SpecHeading }>\n\n")
        .and end_with("<!-- raindown:directive SpecHeading: title='Hi' -->\n## Hi\n")
    end
  end
end
