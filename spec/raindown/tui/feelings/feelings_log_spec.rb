# frozen_string_literal: true

require 'raindown/tui/feelings/feelings_log'
require 'raindown/tui/feelings/code_methods'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::FeelingsLog do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:log) { described_class.new(root: @root) }
  let(:method) do
    Raindown::TUI::CodeMethod.new(path: File.join(@root, 'lib', 'text.rb'), owner: 'Text', name: 'fit', line: 12, lines: [],
                                  changes: 0, drift: 0)
  end

  let(:other) { method.with(name: 'spread', line: 30) }

  def feeling(temper, note = nil, about: method) = Raindown::TUI::Feeling.new(method: about, temper:, note:)

  it 'notes each feeling down in .raindown/data/feelings.csv, when in UTC, with its code\'s checksum, and counts them by temper' do
    log.add(feeling('malice', 'two negations | and a hidden @rows'))
    log.add(feeling('numb', about: other))

    expect(log.rows.map { it.values_at(:location, :method, :temper, :note, :checksum) })
      .to eq([['lib/text.rb:12', 'Text#fit', 'malice', 'two negations | and a hidden @rows', method.checksum],
              ['lib/text.rb:30', 'Text#spread', 'numb', nil, other.checksum]])
    expect(log.counts).to eq('frolic' => 0, 'numb' => 1, 'woe' => 0, 'dread' => 0, 'malice' => 1)
    expect(log.rows.map { it[:timestamp] }).to all(match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/))
  end

  def memories = CSV.read(File.join(@root, '.raindown', 'data', 'memories.csv'), headers: true)
                    .map { it.to_h.values_at('method', 'temper') }

  it "replaces a feeling about a method whose code hasn't changed, and moves it to the memories once the code has" do
    log.add(feeling('malice'))
    log.add(feeling('numb'))
    expect(log.rows.map { it[:temper] }).to eq(['numb'])

    changed = method.with(lines: ['def fit = 1'])
    expect([log.felt?(method), log.felt?(changed)]).to eq([true, false])
    expect([log.temper(method), log.temper(changed)]).to eq(['numb', nil])

    log.add(feeling('woe', about: changed))
    expect([log.rows.map { it[:temper] }, memories]).to eq([['woe'], [%w[Text#fit numb]]])
  end

  it 'moves the feelings about methods that have changed or gone to the memories, keeping the rest' do
    log.add(feeling('malice'))
    log.add(feeling('numb', about: other))
    log.add(feeling('dread', about: other.with(name: 'gone', line: 50)))

    log.move_stale_to_memories([method, other.with(lines: ['def spread = 2'])])
    expect([log.rows.map { it[:temper] }, memories]).to eq([['malice'], [%w[Text#spread numb], %w[Text#gone dread]]])
    expect(log.counts.values.sum).to eq(1)

    log.move_stale_to_memories([method])
    expect(memories.length).to eq(2)
  end

  it 'writes only .raindown/data/feelings.csv' do
    log.add(feeling('woe'))

    expect(Dir.glob('**/*', File::FNM_DOTMATCH, base: @root).select { File.file?(File.join(@root, it)) })
      .to eq(['.raindown/data/feelings.csv'])
  end

  it 'asks Claude Code to refactor the method, with how it felt' do
    expect(feeling('dread', 'too clever').prompt).to start_with("Refactor Text#fit in #{method.path}:12. It felt like dread: too clever.")
    expect(feeling(nil).prompt).to include('It needs a second look.')
  end
end

RSpec.describe Raindown::TUI::FeelingsLogs do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    end
  end

  let(:projects) { %w[docs site].map { File.join(@dir, it) } }
  let(:logs) { described_class.new(projects:) }

  def feeling(temper, project)
    method = Raindown::TUI::CodeMethod.new(path: File.join(project, 'lib', 'text.rb'), owner: 'Text', name: 'fit', line: 1,
                                           lines: [], changes: 0, drift: 0)
    Raindown::TUI::Feeling.new(method:, temper:, note: nil)
  end

  it "keeps each feeling in its method's project, counting them all, or a folder's, and leaves the folder of projects alone" do
    logs.add(feeling('woe', projects.first))
    logs.add(feeling('frolic', projects.last))

    expect(Dir.glob('**/*.csv', File::FNM_DOTMATCH, base: @dir))
      .to contain_exactly('docs/.raindown/data/feelings.csv', 'site/.raindown/data/feelings.csv')
    expect(logs.counts.values_at('woe', 'frolic')).to eq([1, 1])
    expect(logs.temper(feeling(nil, projects.last).method)).to eq('frolic')
    expect(logs.counts(within: projects.last).values_at('woe', 'frolic')).to eq([0, 1])
    expect(logs.counts(within: File.join(projects.first, 'lib')).values_at('woe', 'frolic')).to eq([1, 0])
  end
end
