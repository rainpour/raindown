# frozen_string_literal: true

require 'raindown'
require 'raindown/editing'
require 'tmpdir'

RSpec.describe Raindown::World do
  it 'writes nothing, as an app paints it' do
    expect(described_class.new.rewrite).to eq('')
  end

  it 'leaves its line, the blank lines below it and a grid cell it is in as they are' do
    Dir.mktmpdir do |dir|
      markdown = "world:\n\n\n\n+----------+\n| :world   |\n+----------+\n"
      expect(Raindown::Editing.rewrite_markdown(markdown, path: File.join(dir, 'world.rd'))[:output]).to eq(markdown)
    end
  end
end
