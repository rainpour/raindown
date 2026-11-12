# frozen_string_literal: true

require 'raindown'
require 'tmpdir'

RSpec.describe Raindown::Weather do
  let(:metadata) { Struct.new(:root).new(@dir) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      example.run
    end
  end

  it "writes nothing in a notes project, as its forecast's still to come" do
    expect(described_class.new.rewrite(metadata:)).to eq('')
  end

  context 'in a code project' do
    let(:branches) do
      [Raindown::BranchTree::Branch.new(name: 'login', depth: 0, commits: 4),
       Raindown::BranchTree::Branch.new(name: 'tests', depth: 1, commits: 1)]
    end

    before do
      File.write(File.join(@dir, '.raindown', 'config.yml'), "kind: code\n")
      allow(Raindown::BranchTree).to receive(:new).with(@dir).and_return(instance_double(Raindown::BranchTree, branches:))
    end

    it 'renders its branches keeping their spaces' do
      expect(described_class.new.render(metadata:))
        .to eq(%(<pre class="weather">login · 4 commits\n    -&gt; tests · 1 commit</pre>))
    end

    it 'shows a valley, with its branches for their constellations, for the app to paint' do
      expect(described_class.new.rasterize(metadata:, width: 120).to_h)
        .to eq(painter: 'valley', data: { branches: [{ name: 'login', commits: 4 }, { name: 'tests', commits: 1 }] })
    end

    it "dims each line's arrow and count" do
      expect(described_class.new.quiet(metadata:)).to eq([[0, 5, 17], [1, 4, 7], [1, 12, 23]])
    end
  end
end
