# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'

RSpec.describe 'Raindown built-in nodes' do
  def rewrite(content, path: 'notes.md')
    Raindown::NodeInjector.rewrite(content:, path:)
  end

  describe Raindown::TOC do
    it 'writes a list of links to the headings into a toc: block' do
      expect(rewrite("# Title\n\n<!-- toc: -->\n<!-- :toc -->\n\n## Section\n")).to eq(<<~MARKDOWN)
        # Title

        <!-- toc: -->
        - [Section](#section)
        <!-- :toc -->

        ## Section
      MARKDOWN
    end

    it 'writes a bare toc: straight below it' do
      expect(rewrite("# Title\n\ntoc:\n\n## Section\n", path: 'notes.rd'))
        .to eq("# Title\n\ntoc:\n- [Section](#section)\n\n## Section\n")
    end

    it 'lists headings with their variables rendered, and headings written by other nodes' do
      require 'helpers/nodes'
      content = rewrite("---\nname: Mark\n---\n\n# Notes for {name}\n\n# Other\n\ntoc:\n\nSpecHeading: title='Written'\n", path: 'notes.rd')

      expect(content).to include("toc:\n- [Notes for Mark](#notes-for-mark)\n- [Other](#other)\n  - [Written](#written)\n")
    end

    it 'leaves a self-closing :toc alone when writing, and renders it in the HTML' do
      content = "# Title\n\n<{ :toc }>\n\n## Section\n"

      expect(rewrite(content)).to eq(content)
      expect(Raindown.render(markdown: content)).to include('<summary>Table of contents</summary>')
        .and include("<li class='h2'><a href='#section'>Section</a></li>")
    end
  end

  describe Raindown::List do
    let(:metadata) do
      Class.new do
        def list(folder:)
          page = Struct.new(:title, :path, keyword_init: true)
          [{ title: "#{folder} 1", path: "/#{folder}/1" }, { path: "/#{folder}/2" }].map { page.new(**it) }
        end
      end.new
    end

    it 'links a file without a title by its name' do
      pages = [{ path: 'projects/2026/Hyperion.md' }, { path: 'Dune.md', title: 'The Dune' }]
      metadata = Class.new { define_method(:list) { |**| pages.map { Raindown::Page.new(file_path: nil, metadata: it) } } }.new

      expect(Raindown::List.new.rewrite(metadata:)).to eq("- [Hyperion](projects/2026/Hyperion.md)\n- [The Dune](Dune.md)")
    end

    it 'sorts its files by the metadata order: names, with files without it last' do
      pages = [{ path: '/c', title: 'C' }, { path: '/a', created_at: 2 }, { path: '/b', created_at: 1 }].map { Raindown::Page.new(file_path: nil, metadata: it) }
      metadata = Class.new { define_method(:list) { |**| pages } }.new

      expect(Raindown::List.new(order: :created_at).files(metadata:).map(&:path)).to eq(%w[/b /a /c])
    end

    it 'sorts numbers first, then other values as text, when a metadata order has both' do
      pages = [{ path: '/a', rank: 'first' }, { path: '/b', rank: 2 }, { path: '/c', rank: true }, { path: '/d', rank: 1.5 }]
      metadata = Class.new { define_method(:list) { |**| pages } }.new

      expect(Raindown::List.new(order: :rank).files(metadata:).map { it[:path] }).to eq(%w[/d /b /a /c])
    end

    it "reads an unquoted value in <{ }> that can't be a variable's name as an unknown one" do
      expect { Raindown.render(markdown: "<{ :list folder: a-b }>\n", metadata:) }.not_to raise_error
    end

    it 'writes nothing without metadata' do
      expect(rewrite("list: folder: 'notes'\n", path: 'notes.rd')).to eq("list: folder: 'notes'\n")
    end

    it 'renders a link to each file, by title or else by name' do
      html = Raindown.render(markdown: "<!-- list: folder: 'notes' -->\n<!-- :list -->\n", metadata:)

      expect(html).to include('<li><a href="/notes/1">notes 1</a></li>', '<li><a href="/notes/2">2</a></li>')
    end

    it 'renders its links in <{ }>, where folder: is its own prop' do
      html = Raindown.render(markdown: "<{ :list folder: 'notes' }>\n", metadata:)

      expect(html).to include('<li><a href="/notes/1">notes 1</a></li>')
    end

    it 'is replaced by a project List node' do
      stub_const('List', Class.new(Raindown::List) { def rewrite(metadata:) = files(metadata:).map { "* #{it.path}" }.join("\n") })

      expect(Raindown.render(markdown: "list: folder: 'notes'\n", metadata:, bare: true)).to include('<li>/notes/1</li>')
    end
  end
  describe Raindown::Image do
    it 'writes a Markdown image of the file, described by its name' do
      expect(rewrite("image: 'pictures/cat.png'\n", path: 'notes.rd')).to eq("image: 'pictures/cat.png'\n![cat](pictures/cat.png)\n")
    end

    it 'writes its alt text, without brackets that would end it early' do
      expect(rewrite("image: 'cat.png' alt: 'A [very] good cat'\n", path: 'notes.rd')).to include('![A very good cat](cat.png)')
    end

    it 'writes a path with spaces in angle brackets' do
      expect(rewrite("image: 'my pictures/cat.png'\n", path: 'notes.rd')).to include('![cat](<my pictures/cat.png>)')
    end

    it 'warns when it has no source' do
      expect(rewrite("image:\n", path: 'notes.rd')).to include("> [!WARNING]\n> Needs a path to an image or a URL")
    end

    it 'renders its width in characters' do
      expect(Raindown.render(markdown: "<{ :image 'cat.png' width=40 }>\n"))
        .to include('<img src="cat.png" alt="cat" style="width: 40ch">')
    end
  end

  describe Raindown::Grid do
    it 'writes a new grid of two cells, three lines tall' do
      expect(rewrite("grid: width: 21\n", path: 'notes.rd')).to eq(<<~MARKDOWN)
        grid: width: 21
        +---------+---------+
        |         |         |
        |         |         |
        |         |         |
        +---------+---------+
      MARKDOWN
    end

    it "shares its width, borders and all, equally among a row's cells, adding one for each | added, and keeps the lines added" do
      written = "grid: width: 21\n+---+\n| ![cat](cat.png) | a | b\n| two\n|\n|\n+---+\n"

      expect(rewrite(written, path: 'notes.rd')).to eq(<<~MARKDOWN)
        grid: width: 21
        +------+------+-----+
        | ![cat](cat.png)| a    | b   |
        | two  |      |     |
        |      |      |     |
        |      |      |     |
        +------+------+-----+
      MARKDOWN
    end

    it 'marks the cells of the rows on both sides of a rule' do
      written = "grid: width: 13\n+\n| a | b |\n+\n| c | d | e |\n+\n"

      expect(rewrite(written, path: 'notes.rd')).to include("+-----+-----+\n| a   | b   |\n+---+-+-+---+\n| c | d | e |\n+---+---+---+")
    end

    it 'pads a wide character by the width it shows' do
      expect(rewrite("grid: width: 9\n+\n| 🌧️ |\n+\n", path: 'notes.rd')).to include("| 🌧️    |\n")
    end

    it 'renders each row as a grid of its cells' do
      html = Raindown.render(markdown: "grid: width: 21\n+---+\n| ![cat](cat.png) | b |\n+---+\n", bare: true)

      expect(html).to include('<div class="raindown-grid" style="display: grid; grid-template-columns: repeat(2, 1fr)">')
      expect(html).to include('<img src="cat.png" alt="cat"')
    end

    it "renders a cell's image by reference, from the note's definitions" do
      markdown = "grid: width: 21\n+---+\n| ![cat] | b |\n+---+\n\n[cat]: pictures/cat.png\n"

      expect(Raindown.render(markdown:, bare: true)).to include('<img src="pictures/cat.png" alt="cat"')
    end
  end
end
