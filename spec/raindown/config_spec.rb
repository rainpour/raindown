# frozen_string_literal: true

require 'raindown'
require 'tmpdir'

RSpec.describe Raindown::Config do
  it 'reads config.yml in the project .raindown folder' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      File.write(File.join(dir, '.raindown', 'config.yml'), "highlight_code: false\n")

      expect(described_class.for(File.join(dir, 'docs', 'notes.rd'))).to eq(highlight_code: false)
    end
  end

  it 'has defaults outside a project or without a config file' do
    Dir.mktmpdir do |dir|
      expect(described_class.for(File.join(dir, 'notes.rd'))).to eq(highlight_code: true)

      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      expect(described_class.for(File.join(dir, 'notes.rd'))).to eq(highlight_code: true)
    end
  end

  it 'leaves code unhighlighted when a project file is rendered' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      File.write(File.join(dir, '.raindown', 'config.yml'), "highlight_code: false\n")
      path = File.join(dir, 'notes.md').tap { File.write(it, "```ruby\nputs 1\n```\n") }

      expect(Raindown.render_file(path:)).to include('<pre><code class="language-ruby">')
    end
  end
end
