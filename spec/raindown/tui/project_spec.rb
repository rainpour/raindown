# frozen_string_literal: true

require 'raindown/tui/project'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Project do
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
end
