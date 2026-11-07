# frozen_string_literal: true

require 'open3'
require 'raindown'
require 'raindown/cli'
require 'raindown/skeleton'
require 'tmpdir'

RSpec.describe Raindown::Skeleton do
  def strip(markdown, path: 'note.md')
    described_class.strip(markdown, path:)
  end

  describe '.strip' do
    it 'leaves a file without skeleton: true as it is, to the byte' do
      markdown = "# A\r\n\r\n<!-- toc: -->\r\n- [A](#a)\r\n<!-- :toc -->\r\n\xE9"

      expect(strip(markdown)).to eq(markdown)
    end

    it 'takes out what a directive in comments wrote' do
      expect(strip("---\nskeleton: true\n---\n<!-- toc: -->\n- [A](#a)\n<!-- :toc -->\n\n## A\n"))
        .to eq("---\nskeleton: true\n---\n<!-- toc: -->\n<!-- :toc -->\n\n## A\n")
    end

    it 'takes out what a bare directive wrote, up to the blank line' do
      expect(strip("---\nraindown: true\nskeleton: true\n---\ntoc:\n- [A](#a)\n\n## A\n"))
        .to eq("---\nraindown: true\nskeleton: true\n---\ntoc:\n\n## A\n")
    end

    it "takes out a table and its comment, as it's written again from its file" do
      table = "<!-- table: 'a.csv' -->\n<!-- table 1 row · 09ae51 -->\n| a |\n| - |\n| 1 |\n<!-- :table -->\n"

      expect(strip("---\nskeleton: true\n---\n#{table}")).to eq("---\nskeleton: true\n---\n<!-- table: 'a.csv' -->\n<!-- :table -->\n")
    end

    it "keeps an endpoint's request, and takes out its response" do
      request = "<!-- endpoint: -->\n```sh\ncurl https://example.com\n```\n"
      response = "<!-- response 200 · 10ms · 2026-11-07 -->\n```json\n{ \"secret\": 1 }\n```\n"

      expect(strip("---\nskeleton: true\n---\n#{request}#{response}<!-- :endpoint -->\n"))
        .to eq("---\nskeleton: true\n---\n#{request}<!-- :endpoint -->\n")
    end

    it 'leaves what it finds in code, and the Markdown around directives' do
      markdown = "---\nskeleton: true\n---\n# Mine\n\n```md\n<!-- toc: -->\n- keep\n<!-- :toc -->\n```\n\nMine too.\n"

      expect(strip(markdown)).to eq(markdown)
    end

    it 'leaves write-in directives, as what is between their tags is yours' do
      markdown = "---\nskeleton: true\n---\n<{ toc: }>\nMine\n<{ :toc }>\n"

      expect(strip(markdown)).to eq(markdown)
    end

    it 'changes nothing the second time' do
      stripped = strip("---\nskeleton: true\n---\n<!-- toc: -->\n- [A](#a)\n<!-- :toc -->\n")

      expect(strip(stripped)).to eq(stripped)
    end

    it "fails rather than keep output it can't find the end of" do
      expect { strip("---\nskeleton: true\n---\n<!-- toc: -->\n- secret\n") }.to raise_error(Raindown::NodeBlocks::MissingEndTag)
    end

    it "fails on front matter it can't read, rather than miss bare directives" do
      expect { strip("---\nskeleton: true\nraindown: true\nbad: [\n---\ntoc:\n- secret\n") }.to raise_error(Psych::Exception)
    end
  end

  describe 'in a git repo' do
    around do |example|
      Dir.mktmpdir do |root|
        @root = File.realpath(root)
        example.run
      end
    end

    let(:raindown) { "#{RbConfig.ruby} -I#{File.expand_path('../../lib', __dir__)} #{File.expand_path('../../bin/raindown', __dir__)}" }
    let(:note) { "---\nskeleton: true\n---\n<!-- toc: -->\n- [Secret](#secret)\n<!-- :toc -->\n\n## Secret\n" }

    def git(*args)
      output, _errors, status = Open3.capture3('git', '-c', 'user.name=a', '-c', 'user.email=a@b', *args, chdir: @root)
      [output, status.success?]
    end

    def run_raindown(*args)
      Open3.capture2e(*raindown.split, *args, chdir: @root)
    end

    def write(path, content)
      FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
      File.write(File.join(@root, path), content)
    end

    def commit(path)
      git('add', path)
      git('commit', '-m', 'Add')
    end

    before do
      git('init', '-q')
      run_raindown('skeleton')
      git('config', 'filter.raindown.clean', "#{raindown} skeleton %f")
    end

    it 'sets up the filter, once' do
      run_raindown('skeleton')

      expect(File.read(File.join(@root, '.gitattributes')).scan('*.md filter=raindown').length).to eq(1)
      expect(git('config', 'filter.raindown.required').first.strip).to eq('true')
    end

    it 'keeps output out of git, and in the file' do
      write('note.md', note)

      expect(commit('note.md').last).to be(true)
      expect(git('show', 'HEAD:note.md').first).to eq("---\nskeleton: true\n---\n<!-- toc: -->\n<!-- :toc -->\n\n## Secret\n")
      expect(File.read(File.join(@root, 'note.md'))).to eq(note)
      expect(git('status', '--short', 'note.md').first).to eq('')
    end

    it 'leaves other files alone' do
      write('plain.md', "<!-- toc: -->\n- [A](#a)\n<!-- :toc -->\n")
      commit('plain.md')

      expect(git('show', 'HEAD:plain.md').first).to include('- [A](#a)')
    end

    it "takes out a project's own node, from a file in a folder, whatever it prints" do
      write('.raindown/Revenue.rb', "puts 'loaded'\nclass Revenue < Raindown::Node\n  def rewrite = 'x'\nend\n")
      write('docs/note.md', "---\nskeleton: true\n---\n<!-- Revenue: -->\n$14,100\n<!-- :Revenue -->\n")
      commit('docs/note.md')

      expect(git('show', 'HEAD:docs/note.md').first).to eq("---\nskeleton: true\n---\n<!-- Revenue: -->\n<!-- :Revenue -->\n")
    end

    it "refuses the commit when it can't strip a file" do
      write('note.md', "---\nskeleton: true\n---\n<!-- toc: -->\n- secret\n")

      expect(git('add', 'note.md').last).to be(false)
      expect(git('show', ':note.md').last).to be(false)
    end

    describe '--check' do
      it 'passes when no output is staged' do
        write('note.md', note)
        commit('note.md')

        expect(run_raindown('skeleton', '--check').last.success?).to be(true)
      end

      it 'names a file whose output got in before the filter was set up' do
        write('note.md', note)
        git('-c', 'filter.raindown.clean=cat', 'add', 'note.md')
        output, status = run_raindown('skeleton', '--check')

        expect(status.success?).to be(false)
        expect(output).to include('note.md')
      end
    end
  end
end
