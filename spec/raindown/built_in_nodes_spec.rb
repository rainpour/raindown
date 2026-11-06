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
        - [Title](#title)
          - [Section](#section)
        <!-- :toc -->

        ## Section
      MARKDOWN
    end

    it 'writes a bare toc: straight below it' do
      expect(rewrite("# Title\n\ntoc:\n\n## Section\n", path: 'notes.rd'))
        .to eq("# Title\n\ntoc:\n- [Title](#title)\n  - [Section](#section)\n\n## Section\n")
    end

    it 'lists headings with their variables rendered, and headings written by other nodes' do
      require 'helpers/nodes'
      content = rewrite("---\nname: Mark\n---\n\n# Notes for {name}\n\ntoc:\n\nSpecHeading: title='Written'\n", path: 'notes.rd')

      expect(content).to include("toc:\n- [Notes for Mark](#notes-for-mark)\n  - [Written](#written)\n")
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

    it 'sorts its files by the metadata order: names, with files without it last' do
      pages = [{ path: '/c', title: 'C' }, { path: '/a', created_at: 2 }, { path: '/b', created_at: 1 }].map { Raindown::Page.new(file_path: nil, metadata: it) }
      metadata = Class.new { define_method(:list) { |**| pages } }.new

      expect(Raindown::List.new(order: :created_at).files(metadata:).map(&:path)).to eq(%w[/b /a /c])
    end

    it "reads an unquoted value in <{ }> that can't be a variable's name as an unknown one" do
      expect { Raindown.render(markdown: "<{ :list folder: a-b }>\n", metadata:) }.not_to raise_error
    end

    it 'writes nothing without metadata' do
      expect(rewrite("list: folder: 'notes'\n", path: 'notes.rd')).to eq("list: folder: 'notes'\n")
    end

    it 'renders a link to each file, by title or else by path' do
      html = Raindown.render(markdown: "<!-- list: folder: 'notes' -->\n<!-- :list -->\n", metadata:)

      expect(html).to include('<li><a href="/notes/1">notes 1</a></li>', '<li><a href="/notes/2">/notes/2</a></li>')
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
end
