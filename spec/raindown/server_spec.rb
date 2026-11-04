# frozen_string_literal: true

require 'raindown/server'
require 'stringio'
require 'timeout'
require 'tmpdir'

RSpec.describe Raindown::Server do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, '.raindown'))
      shout('Loud')
      example.run
    end
  end

  def shout(text)
    File.write(File.join(@dir, '.raindown', 'shout.rb'), "class Shout < Raindown::Node\n  def replace = '#{text}'\nend\n")
  end

  # The server's answers to the requests, after it says it's ready.
  def answers(*requests)
    output = StringIO.new
    described_class.new(input: StringIO.new(requests.map { "#{it.is_a?(String) ? it : JSON.generate(it)}\n" }.join), output:).start
    ready, *answers = output.string.lines.map { JSON.parse(it) }
    expect(ready).to eq('ready' => true, 'version' => Raindown::VERSION)
    answers
  end

  def request(id, markdown, **options)
    { id:, path: File.join(@dir, 'notes.md'), markdown:, **options }
  end

  it 'answers with the Markdown as it would be written back, or its HTML, in order' do
    rewritten, html = answers(request(1, "# A\n\n<!-- toc: -->\n<!-- :toc -->\n", rewrite: true), request(2, "# A\n"))

    expect(rewritten).to eq('id' => 1, 'output' => "# A\n\n<!-- toc: -->\n- [A](#a)\n<!-- :toc -->\n", 'warnings' => [])
    expect(html['output']).to include('<h1 id="a">A')
  end

  it 'answers errors like the CLI writes them, and keeps answering' do
    broken, unreadable, html = answers(request(1, "<!-- toc: -->\n", rewrite: true), 'not json', request(3, "# A\n"))

    expect(broken).to eq('id' => 1, 'error' => "raindown: #{File.join(@dir, 'notes.md')}: <!-- toc: --> on line 1 needs <!-- :toc -->")
    expect(unreadable['error']).to start_with('raindown: unexpected token')
    expect(html['id']).to eq(3)
  end

  it "renders with a project's nodes as they are now, after one changes", :fork do
    input, writer = IO.pipe
    # A worker closes the pipes it's given, so its fork doesn't keep the server's input open.
    Raindown::Workers::Worker.pipes.push(input, writer)
    output = StringIO.new
    server = Thread.new { described_class.new(input:, output:).start }
    ask = lambda do |id|
      writer.puts(JSON.generate(request(id, "<!-- Shout: -->\n<!-- :Shout -->\n", rewrite: true)))
      Timeout.timeout(20) { sleep(0.1) until output.string.lines.length > id }
      JSON.parse(output.string.lines[id])['output']
    end

    expect(ask.call(1)).to eq("<!-- Shout: -->\nLoud\n<!-- :Shout -->\n")
    shout('Quiet')
    File.utime(Time.now + 5, Time.now + 5, File.join(@dir, '.raindown', 'shout.rb'))
    expect(ask.call(2)).to eq("<!-- Shout: -->\nQuiet\n<!-- :Shout -->\n")
  ensure
    writer.close
    Timeout.timeout(20) { server.join }
  end
end
