# frozen_string_literal: true

require 'raindown'

RSpec.describe Raindown::TOC do
  describe '#headings' do
    def headings(html) = described_class.new.headings(markdown: '', html:)

    it 'reads the level, text and id of each heading' do
      html = %(<h1 id="notes">Notes</h1><p>Hi</p><h2 id="set-up">Set up</h2>)

      expect(headings(html)).to eq([{ level: 1, text: 'Notes', id: 'notes' }, { level: 2, text: 'Set up', id: 'set-up' }])
    end

    it 'reads text inside tags and decodes entities' do
      html = %(<h2 id="a-b"><a href="#a-b" class="anchor"></a><code>A</code> &amp; <em>B</em></h2>)

      expect(headings(html)).to eq([{ level: 2, text: 'A & B', id: 'a-b' }])
    end

    it 'reads ids in single quotes, without quotes and among other attributes' do
      html = %(<h3 class='x' id='one'>One</h3><H4 id=two>Two</H4><h5 data-x="1" id="three" title="t">Three</h5>)

      expect(headings(html).map { it[:id] }).to eq(%w[one two three])
    end

    it 'leaves out headings without an id' do
      expect(headings(%(<h2>No id</h2><h2 id="yes">Yes</h2>)).map { it[:id] }).to eq(['yes'])
    end

    it 'leaves out headings in comments and scripts' do
      html = %(<!-- <h2 id="commented">X</h2> --><script>"<h2 id='scripted'>Y</h2>"</script><h2 id="real">Real</h2>)

      expect(headings(html).map { it[:id] }).to eq(['real'])
    end

    it 'reads a heading over several lines' do
      expect(headings(%(<h2 id="long">\n  Long\n  heading\n</h2>))).to eq([{ level: 2, text: "Long\n  heading", id: 'long' }])
    end
  end

  describe '#rewrite' do
    def rewrite(document) = described_class.new.rewrite(document:)

    it 'leaves out a lone top-level heading, and moves the rest up a level' do
      expect(rewrite("# Books\n\n## Reading\n\n### Sci-fi\n\n## Finished\n")).to eq(
        "- [Reading](#reading)\n  - [Sci-fi](#sci-fi)\n- [Finished](#finished)"
      )
    end

    it 'keeps top-level headings when there are several' do
      expect(rewrite("# Books\n\n## Reading\n\n# Films\n")).to eq(
        "- [Books](#books)\n  - [Reading](#reading)\n- [Films](#films)"
      )
    end

    it "keeps a top-level heading that doesn't start the document" do
      expect(rewrite("## Reading\n\n# Films\n")).to eq("  - [Reading](#reading)\n- [Films](#films)")
    end

    it 'keeps the title of a note with no other headings' do
      expect(rewrite("# Books\n")).to eq('- [Books](#books)')
    end
  end

  describe '#render' do
    it 'leaves out a lone top-level heading' do
      html = described_class.new.render(document: "# Books\n\n## Reading\n")

      expect(html).to include('Reading')
      expect(html).not_to include('Books')
    end
  end
end
