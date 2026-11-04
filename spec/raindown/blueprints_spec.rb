# frozen_string_literal: true

require 'raindown/blueprints'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Blueprints do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:box) { "╭──────╮\n│ Idea │\n╰──────╯\n" }
  let(:reply) do
    "Here:\n\n```\n#{box}```\n\nand code:\n\n```ruby\nputs '─'\n```\n\n```\nplain text\n```\n\n```diagram\nA then B\nthen C\n```\n"
  end

  # A transcript of Claude Code's, as JSON lines: what was typed, the replies to it, and a tool's result between them.
  def transcript(*entries)
    File.join(@root, 'transcript.jsonl').tap { |path| File.write(path, entries.map(&:to_json).join("\n")) }
  end

  def said(type, *content) = { type:, message: { role: type, content: } }
  def text(text) = { type: 'text', text: }
  def kind(drawing) = described_class.kind(drawing.lines(chomp: true))

  it 'keeps the code blocks that are drawn, or marked with a kind, each with its kind, but not other code or text' do
    expect(described_class.drawn(reply).map { [it.kind, it.lines] })
      .to eq([['mockup', box.lines(chomp: true)], ['diagram', ['A then B', 'then C']]])
  end

  it 'describes each blueprint by the paragraph above it, joined into a line, but not by a list, a heading or another block' do
    reply = "First.\n\nThe watcher\nlistens:\n```\n#{box}```\n\n- a list\n\n```\n#{box}```\n```\n#{box}```\n"

    expect(described_class.drawn(reply).map(&:description)).to eq(['The watcher listens:', nil, nil])
  end

  it 'leaves out drawings of a line, and ones whose first line opens a box they never close, like a piece of one quoted' do
    quoted = "```\n╭─ lib/workers.rb:4 · Workers#for ─╮\n```\n\n```mockup\n╭─ Half ─╮\n│ open   │\n```\n"

    expect(described_class.drawn(quoted + reply).map(&:kind)).to eq(%w[mockup diagram])
    expect(described_class.whole?([' ▀█  ▀▀█', '  █  █▀▀', ' ▀▀▀ ▀▀▀', 'open issues'])).to be(false)
    expect(described_class.whole?(['▄█████▄', '█▓▓█▓▓█', '█░░█░░█', '▀█████▀', 'a waffle'])).to be(false)
    expect(described_class.whole?([' ▄███▄', '█░▒███', ' ▀███▀', '   │', '   ╎'])).to be(false)
  end

  it 'works out what a blueprint is from what it is drawn with, the same each time' do
    flow = "╭─────╮     ╭─────╮\n│ CLI │ ──▶ │ TUI │\n╰─────╯     ╰─────╯\n"
    down = "╭─────╮\n╰──┬──╯\n   │\n   ▼\n Rewriter\n"
    screen = " Dashboard  │ RAINDOWN EXCHANGE\n Feelings   │ CLI  0.17  ▼ 0.33   ▆▅▃▂▁▁\n            │ DOCS 1.00  ▲ 0.83   ▁▁▁▃▆█\n"
    chart = "Jun  ██████▊      640\nJul  ████████▍    820\n"
    table = "name │ score\n─────┼──────\nCLI  │ 0.17\n"

    expect([flow, down, screen, chart, table].map { kind(it) }).to eq(%w[diagram diagram mockup chart table])
    expect([kind(screen), kind(screen)]).to eq(%w[mockup mockup])
  end

  it "reads the replies since the last thing typed, past tools' results, but not the replies before it" do
    path = transcript(said('user', 'first'), said('assistant', text('old ```')),
                      said('user', text('draw it')), said('assistant', text('Drawing.'), { type: 'tool_use', name: 'Bash' }),
                      said('user', { type: 'tool_result', content: 'ok' }), said('assistant', text('Done.')))

    expect(described_class.last_reply(path)).to eq("Drawing.\nDone.")
  end

  it "saves the last reply's blueprints with their kinds to .raindown/data/blueprints.md, and reads them back newest first" do
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'draw'), said('assistant', text(reply))))
    chart = "```\n▁▃▅█ 9\n────\n```"
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'again'), said('assistant', text(chart))))

    blueprints = described_class.read(@root)
    expect(blueprints.map do
      [it.kind, it.lines]
    end).to eq([['chart', ['▁▃▅█ 9', '────']], ['diagram', ['A then B', 'then C']], ['mockup', box.lines(chomp: true)]])
    expect(blueprints.map(&:time)).to all(match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/))
    expect(blueprints.map(&:description)).to eq([nil, nil, 'Here:'])
    lines = File.readlines(File.join(@root, described_class::FILE), chomp: true)
    expect(blueprints.map { lines[it.line - 1] }).to eq(['▁▃▅█ 9', 'A then B', '╭──────╮'])
  end

  it 'saves nothing outside a project, or from a reply without blueprints' do
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'hi'), said('assistant', text(reply))))
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'hi'), said('assistant', text('No drawings.'))))

    expect(File.exist?(File.join(@root, described_class::FILE))).to be(false)
  end

  it 'finds the boxes drawn in a blueprint, in reading order, with the text inside them and in their top borders' do
    drawing = ['┌─ TOC ──┐  ╭─────────╮', '│ (o.o)  │  │ Workers │', '└────────┘  ╰─────────╯', '┌── open', '│ no end']
    boxes = described_class.boxes(drawing)

    expect(boxes.map { [it.top, it.left, it.bottom, it.right, it.text] }).to eq([[0, 0, 2, 9, 'TOC (o.o)'], [0, 12, 2, 22, 'Workers']])
    expect([boxes.first.cover?(1, 5), boxes.first.cover?(1, 10)]).to eq([true, false])
  end

  it "straightens a box's right side down from its bottom corner, where its top or a row is drawn a column off" do
    drawing = ['╭─ Rewriter ╮ x', '│ short     │', '│ long        │ y', '╰────────────╯']
    grid = described_class.columns(drawing)

    expect(described_class.tidied(grid, described_class.boxes(drawing)).map { it.join.rstrip })
      .to eq(['╭─ Rewriter ─╮x', '│ short      │', '│ long       │  y', '╰────────────╯'])
  end

  it 'finds boxes by the columns a terminal shows, past wide characters, and with a top drawn a column short' do
    drawing = ['╭──────╮  ╭─────╮', '│ 📊   │  │ Far  │', '╰──────╯  ╰──────╯']

    expect(described_class.boxes(drawing).map { [it.left, it.right, it.text] }).to eq([[0, 7, '📊'], [10, 17, 'Far']])
  end
end
