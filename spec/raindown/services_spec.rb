# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::Services do
  let(:root) { Dir.mktmpdir }
  let(:services) { described_class.new(root:) }

  it "reads, lists and writes its project's files, which can't be outside it" do
    services.write('notes/a.md', "# A\n")

    expect(services.list('**/*.md')).to eq(['notes/a.md'])
    expect(services.read('notes/a.md')).to eq("# A\n")
    expect { services.read('../elsewhere') }.to raise_error(described_class::Error, /outside the project/)
    expect { services.read('missing.md') }.to raise_error(described_class::Error, /no missing.md/)
  end

  it 'keeps values for so many seconds, or until they are kept again' do
    Dir.mktmpdir do |cache|
      stub_const('ENV', ENV.to_h.merge('XDG_CACHE_HOME' => cache))
      services.cache_set('forever', [1, 2])
      services.cache_set('gone', 'old', -1)

      expect(services.cache_get('forever')).to eq([1, 2])
      expect(services.cache_get('gone')).to be_nil
      expect(described_class.new(root: Dir.mktmpdir).cache_get('forever')).to be_nil
    end
  end

  it 'runs git in the project, raising with what git says when it fails' do
    system('git', 'init', '-q', '-b', 'main', root, exception: true)

    expect(services.git('branch', '--show-current')).to eq("main\n")
    expect { services.git('log') }.to raise_error(described_class::Error, /does not have any commits/)
  end

  it 'fetches a response as its status, headers and body' do
    response = Net::HTTPOK.new('1.1', '200', 'OK').tap do
      it['content-type'] = 'application/json'
      allow(it).to receive(:body).and_return('{"ok":true}')
    end
    allow(Net::HTTP).to receive(:start).and_return(response)

    expect(services.fetch('https://example.com/a', method: 'post', body: '{}'))
      .to eq('status' => 200, 'headers' => { 'content-type' => 'application/json' }, 'body' => '{"ok":true}')
  end

  it 'is called by its name, as hosts send it, and only for its own services' do
    services.write('a.txt', 'A')

    expect(services.call('read', ['a.txt'])).to eq('A')
    expect { services.call('instance_eval', ['1']) }.to raise_error(described_class::Error, /no instance_eval service/)
  end

  it 'is given to a Ruby node that takes raindown:, for its project' do
    stub_const('SpecServicesNode', Class.new(Raindown::Node) { def rewrite(raindown:) = raindown.read('hello.txt') })
    File.write(File.join(root, 'hello.txt'), 'hello from the project')
    FileUtils.mkdir_p(File.join(root, '.raindown'))
    metadata = Raindown::Pages.for(File.join(root, 'notes.rd'))

    expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecServicesNode: -->\n<!-- :SpecServicesNode -->\n", metadata:))
      .to include("hello from the project\n")
  end
end
