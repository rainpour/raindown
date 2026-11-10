# frozen_string_literal: true

require 'raindown'
require 'raindown/cli'
require 'open3'
require 'tmpdir'

RSpec.describe Raindown::Pages do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      example.run
    end
  end

  def write(path, content)
    file_path = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, content)
  end

  def pages
    described_class.load(root: @root)
  end

  def pages_metadata
    file_types = Dirload.file_paths(absolute_path: @root).group_by { Dirload.extension(file_path: it) }
    Dirload::Metadata.new(loaded_paths: {}, missed_paths: [], file_types:)
  end

  describe '.watch' do
    after do
      described_class.instance_variable_set(:@watched, nil)
      described_class.pages.clear
    end

    it "lists by the front matter an editor gave, and only reads or lists files again once they've changed" do
      write('a.md', "---\ntags: [old]\n---\n")
      described_class.watch(File.join(@root, 'a.md') => { tags: ['given'] })
      expect(pages.list(tags: 'given').map(&:file_path)).to eq([File.join(@root, 'a.md')])

      write('b.md', "---\ntags: [given]\n---\n")
      expect(pages.list(tags: 'given').size).to eq(1)

      described_class.changed([File.join(@root, 'a.md'), File.join(@root, 'b.md')])
      expect(pages.list(tags: 'given').map(&:file_path)).to eq([File.join(@root, 'b.md')])
      expect(pages.list(tags: 'old').size).to eq(1)

      FileUtils.rm(File.join(@root, 'b.md'))
      write('.hidden/c.md', "---\ntags: [given]\n---\n")
      described_class.changed([File.join(@root, 'b.md'), File.join(@root, '.hidden/c.md')])
      expect(pages.list(tags: 'given')).to be_empty
    end
  end

  describe '#list' do
    before do
      write('docs/_basics/_2-setup.md', "---\ntitle: Setup\ntags: [ruby]\n---\n\n# Setup\n")
      write('docs/_basics/_1-getting-started.md', "---\ntitle: Getting started\ntags: [ruby, intro]\ndate: 2024-01-02\n---\n\nHi.\n")
      write('docs/_basics/extras.md', "---\ntitle: Extras\n---\n")
      write('docs/_1&_guides/deploy.rd', "# Deploy\n")
      write('docs/notes.txt', 'Not a page')
    end

    it 'lists the files in an underscored folder, by order and then path' do
      expect(pages.list(folder: 'basics').map(&:title)).to eq(['Getting started', 'Setup', 'Extras'])
    end

    it 'tags files with each item of their front matter' do
      expect(pages.list(tags: 'intro').map(&:title)).to eq(['Getting started'])
      expect(pages.list(tags: 'ruby').map(&:title)).to eq(['Getting started', 'Setup'])
    end

    it 'gives each file its front matter, folder, order, path from the root and content' do
      page = pages.list(folder: 'basics').first

      expect([page.title, page.folder, page.order, page.path, page.date])
        .to eq(['Getting started', 'basics', 1, 'docs/_basics/_1-getting-started.md', Date.new(2024, 1, 2)])
      expect(page.content).to eq("<p>Hi.</p>\n")
      expect(page.missing).to be_nil
    end

    it 'renders content with bare directives in Raindown files, in bold' do
      write('docs/_basics/_3-toc.rd', "---\ntitle: TOC\n---\n\n# TOC\n\n:toc\n")

      toc = pages.list(folder: 'basics').find { it.title == 'TOC' }

      expect(toc.content).to include('<p><strong>:toc</strong></p>', 'Table of contents')
    end

    it "renders content with the project's config, unless the render options say otherwise" do
      write('.raindown/config.yml', "highlight_code: false\n")
      write('docs/_basics/_3-code.md', "---\ntitle: Code\n---\n\n```ruby\nputs 1\n```\n")
      highlighting = described_class.new(metadata: pages_metadata, root: @root, render_options: { highlight_code: true })

      expect(pages.list(folder: 'basics').find { it.title == 'Code' }.content).to include('<pre><code class="language-ruby">')
      expect(highlighting.list(folder: 'basics').find { it.title == 'Code' }.content).to include('<pre lang="ruby" style=')
    end

    it 'reads folder tags joined by &' do
      expect(pages.list(folder: 'guides').map(&:path)).to eq(['docs/_1&_guides/deploy.rd'])
    end

    it 'lists every Markdown file without tags' do
      expect(pages.list.length).to eq(4)
    end

    it 'reads files as UTF-8 when the locale is not' do
      write('docs/_basics/_3-unicode.md', "---\ntitle: Café — ☕\n---\n\nNaïve.\n")
      external = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII

      page = pages.list(folder: 'basics').find { it.title == 'Café — ☕' }
      expect(page.content).to eq("<p>Naïve.</p>\n")
    ensure
      Encoding.default_external = external
    end
  end

  describe 'a file it can\'t read the front matter of' do
    before { write('_notes/good.md', "---\ntags: [book]\n---\n# Good\n") }

    {
      'invalid YAML' => "---\ntitle: Foo: bar\n---\n# Bad\n",
      'a YAML alias' => "---\na: &x 1\nb: *x\n---\n# Bad\n",
      'text that is not UTF-8' => "caf\xE9\n"
    }.each do |problem, content|
      it "lists the other files, and names the one with #{problem}" do
        write('_notes/bad.md', content)

        expect { expect(pages.list(tags: 'book').map(&:path)).to eq(['_notes/good.md']) }.to output(%r{_notes/bad\.md}).to_stderr
      end
    end

    it 'warns once until the file changes' do
      write('_notes/bad.md', "---\ntitle: Foo: bar\n---\n")
      expect { pages.list(tags: 'book') }.to output(/bad\.md/).to_stderr

      expect { pages.list(tags: 'book') }.not_to output.to_stderr
    end
  end

  describe '.for' do
    it 'loads the files under the folder with .raindown, or else the file\'s folder' do
      write('.raindown/.keep', '')
      write('docs/_basics/a.md', "# A\n")
      write('other.md', "# Other\n")

      expect(described_class.for(File.join(@root, 'docs', 'index.rd')).list.length).to eq(2)
      expect(described_class.for(File.join(Dir.tmpdir, 'no-project', 'index.rd')).list).to eq([])
    end
  end

  describe '.for in an Obsidian vault' do
    before do
      FileUtils.mkdir_p(File.join(@root, '.obsidian'))
      write('books/dune.md', "---\ntags: [book]\n---\n")
    end

    it 'loads the files under the vault, for a note in a folder of it' do
      expect(described_class.for(File.join(@root, 'projects/2026/note.md')).root).to eq(@root)
    end

    it 'keeps to the nearest of a vault and a .raindown folder' do
      FileUtils.mkdir_p(File.join(@root, 'site/.raindown'))

      expect(described_class.for(File.join(@root, 'site/docs/note.md')).root).to eq(File.join(@root, 'site'))
    end

    it 'keeps to a vault inside a project' do
      FileUtils.mkdir_p(File.join(@root, 'vault/.obsidian'))
      FileUtils.mkdir_p(File.join(@root, '.raindown'))

      expect(described_class.for(File.join(@root, 'vault/notes/note.md')).root).to eq(File.join(@root, 'vault'))
    end

    it "works with only Raindown's main file loaded, like in Raindeer" do
      script = "require 'raindown'; print Raindown::Pages.for(ARGV.first).root"
      output, status = Open3.capture2e(RbConfig.ruby, '-Ilib', '-e', script, File.join(@root, 'notes/note.md'))

      expect([output, status.success?]).to eq([@root, true])
    end

    it 'finds a CSV file from the vault, for a table in a note in a folder of it' do
      write('data/books.csv', "title\nDune\n")
      note = File.join(@root, 'projects/note.md')
      markdown = "<!-- table: 'data/books.csv' -->\n<!-- :table -->\n"

      expect(Raindown::Editing.rewrite_markdown(markdown, path: note)[:output]).to include('| Dune')
    end
  end

  it 'gives list: its metadata, bare and in a block, from the CLI' do
    write('docs/_basics/_1-a.md', "---\ntitle: A\n---\n")
    write('index.rd', "list: folder: 'basics'\n\n<{ list: page folder: 'basics' }>\n## {page.title}\n<{ :list }>\n")
    path = File.join(@root, 'index.rd')

    Raindown::CLI.run([path, '--html', File.join(@root, 'index.html')])

    expect(File.read(path)).to start_with("list: folder: 'basics'\n- [A](docs/_basics/_1-a.md)\n")
    expect(File.read(File.join(@root, 'index.html'))).to include('<a href="docs/_basics/_1-a.md">A</a>', '<h2 id="a">A')
  end

  describe 'kept listings' do
    def paths
      pages.list.map { it.metadata[:path] }
    end

    it 'lists files again once one is added, removed or renamed, in any folder' do
      write('a.md', "# A\n")
      write('notes/b.md', "# B\n")
      expect(paths).to eq(%w[a.md notes/b.md])

      write('notes/new/c.md', "# C\n")
      File.delete(File.join(@root, 'a.md'))
      expect(paths).to eq(%w[notes/b.md notes/new/c.md])

      File.rename(File.join(@root, 'notes/b.md'), File.join(@root, 'notes/d.md'))
      expect(paths).to eq(%w[notes/d.md notes/new/c.md])
    end

    it "reads a file's front matter again once it changes" do
      write('a.md', "---\ntitle: First\n---\n")
      expect(pages.list.first.title).to eq('First')

      write('a.md', "---\ntitle: Second\n---\n")
      File.utime(Time.now + 5, Time.now + 5, File.join(@root, 'a.md'))
      expect(pages.list.first.title).to eq('Second')
    end
  end
end
