# frozen_string_literal: true

require 'raindown/project/project'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Project do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  let(:project) { described_class.new(root: @root) }
  let(:notes) { File.join(@root, 'notes.md') }
  let(:endpoint) { "<!-- endpoint: -->\n```sh\ncurl https://example.com/users\n```\n<!-- :endpoint -->\n" }

  def write(text, at:)
    File.write(notes, text)
    File.utime(at, at, notes)
  end

  it "finds the endpoints in the files that have one, reading a file again once it's changed" do
    write("# Notes\n", at: Time.at(1))
    expect(project.endpoints).to eq([])

    write("# Notes\n\n#{endpoint}", at: Time.at(2))
    expect(project.endpoints.map(&:url)).to eq(['https://example.com/users'])
    expect(project.outline(notes).directives.map(&:name)).to eq(['endpoint'])
  end

  context 'with nodes of its own' do
    after do
      Object.send(:remove_const, :SpecProjectStars) if Object.const_defined?(:SpecProjectStars)
      Raindown::MarkdownNodes.node_classes.delete('SpecProjectCard')
    end

    it 'lists them, Ruby and Markdown, with their files and whether they rasterize' do
      ruby = "class SpecProjectStars < Raindown::Node\n  def rewrite = ''\n  def rasterize(area:) = nil\nend\n"
      File.write(File.join(@root, '.raindown', 'spec_project_stars.rb'), ruby)
      File.write(File.join(@root, '.raindown', 'SpecProjectCard.md'), "A card\n")

      expect(project.nodes).to eq(
        nodes: [{ name: 'SpecProjectCard', kind: 'markdown', file: '.raindown/SpecProjectCard.md', rasterizes: false },
                { name: 'SpecProjectStars', kind: 'ruby', file: '.raindown/spec_project_stars.rb', rasterizes: true }],
        errors: []
      )
    end
  end
end
