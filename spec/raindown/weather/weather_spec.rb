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

  it "renders a code project's branches keeping their spaces" do
    File.write(File.join(@dir, '.raindown', 'config.yml'), "kind: code\n")
    tree = instance_double(Raindown::BranchTree, lines: ['login -> tests', '         search'])
    allow(Raindown::BranchTree).to receive(:new).with(@dir).and_return(tree)

    expect(described_class.new.render(metadata:)).to eq(%(<pre class="weather">login -&gt; tests\n         search</pre>))
  end
end
