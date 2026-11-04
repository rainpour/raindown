# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator/navigator'
require 'raindown/tui/terminal/input'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::BlueprintsView do
  def click(pane, index, action = :enter) = Raindown::TUI::Click.new(pane:, index:, action:)
  def view_name(navigator) = navigator.view.class.name.delete_prefix('Raindown::TUI::')
  def text(lines) = lines.map { |segments| segments.map(&:text).join }
  def width(line) = Unicode::DisplayWidth.of(line)
  def texts(navigator, pane) = navigator.content(pane).rows.select(&:selectable?).map(&:text)

  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  def write(name, content)
    File.join(@root, name).tap do
      FileUtils.mkdir_p(File.dirname(it))
      File.write(it, content)
    end
  end

  def blueprint(time, kind, drawing) = "## #{time} · #{kind}\n\n```#{kind}\n#{drawing}\n```\n\n"
  def file = File.join(@root, '.raindown', 'data', 'blueprints.md')

  it "lists Blueprints once Claude Code's are saved, newest first, the filter moving between them, B opening them, and E editing one" do
    navigator = Raindown::TUI::Navigator.new(root: @root)
    expect(texts(navigator, :nav)).not_to include('🌀 Blueprints')

    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'mockup', '╭─ old ─╮') +
                                   blueprint('2026-10-30T02:00:00Z', 'diagram', 'A ─▶ B'))
    navigator.next_step(click(:nav, navigator.content(:nav).rows.index { it.text == '🌀 Blueprints' }))
    expect([view_name(navigator), navigator.view.selected.lines]).to eq(['BlueprintsView', ['A ─▶ B']])

    %i[filter down enter].each { navigator.next_step(it) }
    expect(navigator.view.selected.lines).to eq(['╭─ old ─╮'])
    navigator.next_step(:dashboard)
    navigator.next_step(Raindown::TUI::Input.key_event('b'))
    expect([view_name(navigator), navigator.view.cursor]).to eq(['BlueprintsView', 1])
    expect(navigator.next_step(:edit)).to be_a(Raindown::TUI::Run)

    File.write(file, blueprint('2026-10-30T03:00:00Z', 'chart', '▁▃▅█'), mode: 'a')
    File.utime(Time.now + 5, Time.now + 5, file)
    navigator.next_step(:tick)
    expect([navigator.view.cursor, navigator.view.selected.lines]).to eq([0, ['▁▃▅█']])
  end

  it 'lists Blueprints when the only blueprints are in the comments of the code' do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    write('lib/pane.rb', "# The pane:\n#    ╭─ Pane ─╮\n#    ╰────────╯\nclass Pane\nend\n")
    navigator = Raindown::TUI::Navigator.new(root: @root)

    expect(texts(navigator, :nav)).to include('🌀 Blueprints')
    navigator.open_view(navigator.blueprints)
    expect([navigator.view.selected.where, navigator.view.selected.description]).to eq(['lib/pane.rb:2 · mockup', 'The pane:'])
  end

  it 'filters the blueprints by keywords typed after f, in them or their kind, Enter keeping the filter and Esc clearing it' do
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'mockup', 'Weather one') +
                                     blueprint('2026-10-30T02:00:00Z', 'diagram', 'Rain two') +
                                     blueprint('2026-10-30T03:00:00Z', 'mockup', 'weather three'))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    type = ->(text) { text.each_char { navigator.next_step(Raindown::TUI::Type.new(text: it)) } }

    navigator.next_step(Raindown::TUI::Input.key_event('f'))
    expect([view_name(navigator), navigator.typing?]).to eq(['BlueprintsView', true])
    type.call('WEATHER')
    navigator.next_step(:down)
    expect([view.matches.map(&:words), view.selected.words]).to eq([['weather three', 'Weather one'], 'Weather one'])
    navigator.next_step(:enter)
    expect([navigator.typing?, view.blueprints.length, view.query]).to eq([false, 2, 'WEATHER'])

    navigator.next_step(:filter)
    navigator.next_step(:backspace) until view.query.empty?
    type.call('diagram')
    expect(view.matches.map(&:words)).to eq(['Rain two'])
    navigator.next_step(:escape)
    expect([navigator.typing?, view.query, view.blueprints.length]).to eq([false, '', 3])
  end

  it 'moves down through every match in the filter, listing the ten around the selected one' do
    write('.raindown/data/blueprints.md', (1..12).map { blueprint(format('2026-10-30T%02d:00:00Z', it), 'mockup', "map #{it}\nmore") }.join)
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    navigator.next_step(:filter)
    11.times { navigator.next_step(:down) }

    expect([view.cursor, view.first_match, view.matches.map(&:words).values_at(0, -1)]).to eq([11, 2, ['map 10 more', 'map 1 more']])
    text = text(Raindown::TUI::Layout.new(navigator, width: 90, height: 24).lines).join
    expect(text).to include('map 1 more').and include('map 10 more')
    expect(text).not_to include('map 12 more')
    navigator.next_step(:down)
    expect(view.cursor).to eq(11)
  end

  it "draws Claude Code's blueprints below the keywords they're filtered by, which open a filter like Teleport's" do
    FileUtils.mkdir_p(File.join(@root, '.raindown', 'data'))
    File.write(File.join(@root, '.raindown', 'data', 'blueprints.md'),
               "## 2026-10-30T03:14:07Z · mockup\n\n```mockup\n╭─ Idea ─╮\n╰────────╯\n```\n")
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    draw = -> { Raindown::TUI::Layout.new(navigator, width: 70, height: 22).lines }
    main = ->(lines) { text(lines).map { it.split(/[│┬]/, 2)[1].to_s.rstrip } }

    lines = draw.call
    expect(main[lines][1]).to match(/\A─+ All ▾ ─+\z/)
    expect(main[lines][2..5]).to match([/\A 2026-10-30 03:14 UTC · mockup +1 of 1\z/, '', ' ╭─ Idea ─╮', ' ╰────────╯'])

    navigator.next_step(:filter)
    navigator.next_step(Raindown::TUI::Type.new(text: 'idea'))
    lines = draw.call
    expect(main[lines][1..2]).to match([/\A─+┌─+ Filter ─+┐─+\z/, include('/ idea▏')])
    expect(text(lines).join).to include('Idea')
    expect(text(lines).map { width(it) }).to all(eq(70))

    navigator.next_step(lines.flatten.find { it.event == click(:main, 0) }.event)
    expect(navigator.typing?).to be(false)
    navigator.next_step(Raindown::TUI::Type.new(text: 'x')) # typing does nothing once it's closed
    expect([navigator.view.query, main[draw.call][1]]).to match(['idea', / “idea” ▾ /])
  end

  it 'shows the paragraph above a blueprint in the reply as its description, in the text colour, above the drawing' do
    described = "How the watcher\nhears saves.\n\n```mockup\n╭─ Idea ─╮\n╰────────╯\n```\n"
    write('.raindown/data/blueprints.md', "## 2026-10-30T03:14:07Z · mockup\n\n#{described}")
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    lines = Raindown::TUI::Layout.new(navigator, width: 70, height: 22).lines
    main = text(lines).map { it.split(/[│┬]/, 2)[1].to_s.rstrip }

    expect(main[3..7]).to eq(['', ' How the watcher hears saves.', '', ' ╭─ Idea ─╮', ' ╰────────╯'])
    expect(lines.flatten.find { it.text.include?('How the watcher') }.style).to eq(:text)
    expect(navigator.view.selected.words).to start_with('How the watcher hears saves.')
  end

  it 'traces each blueprint to its code, left and right moving between its boxes, each with the code it names below' do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    write('lib/workers.rb', "class Workers\n  def initialize = nil\n\n  def for(path) = path\nend\n")
    drawing = ['╭─────────╮  ╭──────────────╮  ╭──────╮', '│ Workers │──│ Workers#for  │  │ wind │',
               '╰─────────╯  ╰──────────────╯  ╰──────╯']
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'diagram', drawing.join("\n")))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    draw = -> { Raindown::TUI::Layout.new(navigator, width: 80, height: 18).lines }

    expect([view.box, view.boxes.map { view.codes(it).map(&:name) }]).to eq([0, [['initialize'], ['for'], []]])
    expect(text(draw.call).find { it.include?('╭─ lib/workers.rb:2') }).to include('Workers#initialize')

    navigator.next_step(:right)
    lines = draw.call
    expect(text(lines).find { it.include?('╭─ lib/workers.rb:4') }).to include('Workers#for')
    expect(lines.flatten.find { it.text.include?('Workers#for  ') }.style).to eq(:selected)
    expect(navigator.next_step(:edit)).to be_a(Raindown::TUI::Run)

    navigator.next_step(:right)
    expect(text(draw.call).join).to include('No code').and include('Nothing in this box')
    expect([navigator.next_step(:edit), view.box, text(draw.call).map { width(it) }.uniq]).to match([be_a(Raindown::TUI::Run), 2, [80]])

    navigator.next_step(draw.call.flatten.find { it.text.include?('Workers#for') }.event)
    expect([view.box, view.cursor]).to eq([1, 0])
  end

  it 'moves through the code a box names, in the order it names it, with Space or a click on the box' do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    write('lib/workers.rb', "class Workers\n  def initialize = nil\n\n  def for(path) = path\nend\n")
    drawing = "╭──────────────────╮\n│ for, then Workers │\n╰──────────────────╯"
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'diagram', drawing))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    draw = -> { Raindown::TUI::Layout.new(navigator, width: 100, height: 18).lines }
    title = -> { text(draw.call).find { it.include?('╭─ lib/workers.rb') } }

    expect([view.code.name, title.call]).to match(['for', match(/Workers#for ─+ 1 of 2 ─╮/)])
    navigator.next_step(:toggle)
    expect([view.code.name, title.call]).to match(['initialize', match(/Workers#initialize ─+ 2 of 2 ─╮/)])
    navigator.next_step(draw.call.flatten.find { it.text.include?('for, then') }.event)
    expect(view.code.name).to eq('for')
  end

  it "shows a long method's first lines, like Code feelings' code box, and the rest when how many more is clicked, or with Enter" do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    write('lib/long.rb', "class Long\n  def run\n#{(1..10).map { "    step#{it}\n" }.join}  end\nend\n")
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'mockup', "╭──────╮\n│ Long │\n╰──────╯"))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    draw = -> { Raindown::TUI::Layout.new(navigator, width: 80, height: 30).lines }

    lines = draw.call
    expect(text(lines).join).to include('step5').and include('[6 more lines]')
    expect(text(lines).join).not_to include('step6')
    navigator.next_step(lines.flatten.find { it.text.include?('[6 more lines]') }.event)
    expect([navigator.view.expanded, text(draw.call).join]).to match([true, include('step10').and(include('[Fewer lines]'))])
    expect(draw.call.length).to eq(30)
    navigator.next_step(:enter)
    expect(navigator.view.expanded).to be(false)
  end

  it 'moves up and down to the nearest box above or below, and left and right in reading order' do
    drawing = "╭───╮  ╭───╮\n│ A │  │ B │\n╰───╯  ╰───╯\n╭───╮  ╭───╮\n│ C │  │ D │\n╰───╯  ╰───╯"
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'mockup', drawing))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    name = -> { view.boxes[view.box].text }

    expect(%i[right down left up down].map { navigator.next_step(it).then { name.call } }).to eq(%w[B D C A C])
    navigator.next_step(:down)
    expect(name.call).to eq('C')
  end

  it 'shows a blueprint on a canvas that follows the selected box, with markers where there is more, and scrolls' do
    far = "#{' ' * 80}╭───────╮\n#{' ' * 80}│ Far   │\n#{' ' * 80}╰───────╯"
    drawing = "╭──────╮\n│ Near │\n╰──────╯\n#{"\n" * 20}#{far}"
    write('.raindown/data/blueprints.md',
          blueprint('2026-10-30T01:00:00Z', 'mockup', drawing) + blueprint('2026-10-30T02:00:00Z', 'mockup', 'small'))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.blueprints)
    view = navigator.view
    %i[filter down enter].each { navigator.next_step(it) }
    canvas = -> { text(Raindown::TUI::Layout.new(navigator, width: 70, height: 24).lines)[2..13].join("\n") }

    expect([canvas.call, view.canvas(48, 6)]).to match([include('│ Near │').and(include('▶')).and(include('▼')), [0, 0]])
    navigator.next_step(:down)
    expect([canvas.call, view.canvas(48, 6)]).to match([include('│ Far   │').and(include('◀')).and(include('▲')), [41, 20]])

    navigator.next_step(:scroll_left)
    navigator.next_step(Raindown::TUI::Drag.new(columns: 2, rows: 3))
    expect(view.canvas(48, 6)).to eq([35, 17])
    navigator.next_step(:up)
    expect([view.box, view.canvas(48, 6)]).to eq([0, [0, 0]])
    navigator.next_step(:up)
    expect(view.box).to eq(0)
  end

  it "lists every project's saved blueprints, newest first, narrowed to a project's when one's chosen" do
    guides = File.join(@root, 'guides')
    FileUtils.mkdir_p(File.join(guides, '.raindown'))
    write('.raindown/data/blueprints.md', blueprint('2026-10-30T01:00:00Z', 'mockup', '╭─ root ─╮'))
    write('guides/.raindown/data/blueprints.md', blueprint('2026-10-30T02:00:00Z', 'mockup', '╭─ guides ─╮'))
    view = Raindown::TUI::Navigator.new(root: @root).blueprints
    view.load

    expect(view.blueprints.map(&:lines)).to eq([['╭─ guides ─╮'], ['╭─ root ─╮']])
    view.project = guides
    expect([view.blueprints.map(&:lines), view.selected.path]).to eq([[['╭─ guides ─╮']], 'guides/.raindown/data/blueprints.md'])
    view.project = nil
    expect(view.blueprints.length).to eq(2)
  end
end
