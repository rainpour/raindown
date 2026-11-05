# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::Table do
  around do |example|
    Dir.mktmpdir do |root|
      @root = root
      example.run
    end
  end

  let(:metadata) { Struct.new(:root).new(@root) }
  let(:csv) { File.join(@root, 'team.csv') }

  def rewrite(content)
    Raindown::NodeInjector.rewrite(content:, path: 'team.rd', metadata:)
  end

  def table(comment, *rows)
    ["table: 'team.csv'", comment, *rows].join("\n") << "\n"
  end

  def synced
    rewrite("table: 'team.csv'\n")
  end

  before { File.write(csv, "name,role\nAda,engineer\nLin,\"design | ux\"\n") }

  it "writes a CSV file as a table, after a comment of its rows and their hash, escaping a cell's |" do
    expect(synced.sub(/ \h{6} /, ' hash ')).to eq(<<~'MARKDOWN')
      table: 'team.csv'
      <!-- table 2 rows · hash -->
      | name | role |
      |---|---|
      | Ada | engineer |
      | Lin | design \| ux |
    MARKDOWN
  end

  it "writes an edited table's rows back to its file" do
    edited = synced.sub('| Ada | engineer |', "| Ada | lead |\n| Kai | ops |")

    expect(rewrite(edited)).to include("| Ada | lead |\n| Kai | ops |\n").and include('3 rows')
    expect(File.read(csv)).to eq("name,role\nAda,lead\nKai,ops\nLin,design | ux\n")
  end

  it 'writes the table again when its file changes' do
    table = synced
    File.write(csv, "name,role\nAda,lead\n")

    expect(rewrite(table)).to match(/<!-- table 1 row · \h{6} -->\n\| name \| role \|\n\|---\|---\|\n\| Ada \| lead \|\n\z/)
  end

  it 'writes neither when both changed, until they match again' do
    edited = synced.sub('engineer', 'lead')
    File.write(csv, "name,role\nAda,ops\n")

    conflict = nil
    expect { conflict = rewrite(edited) }.to output(/team.csv and its table both changed/).to_stderr
    expect([conflict, File.read(csv)]).to eq([edited.sub(/table 2 rows/, 'table conflict'), "name,role\nAda,ops\n"])

    File.write(csv, "name,role\nAda,lead\nLin,design | ux\n")
    expect(rewrite(conflict)).to include('<!-- table 2 rows')
  end

  it 'writes the file again into an emptied table, without emptying the file' do
    expect(rewrite(table(synced.lines[1].chomp))).to eq(synced)
    expect(File.read(csv)).to include('Ada,engineer')
  end

  it "says when its data isn't a CSV or TSV file" do
    expect(rewrite("table: 'team.json'\n")).to include("Can't show \"team.json\" as a table: only CSV and TSV files can be")
    expect(rewrite("table: 'missing.csv'\n")).to include('no such file')
  end

  it 'shows its file in <{ }> without writing to it' do
    html = Raindown.render(markdown: "<{ table: 'team.csv' }>\n| name |\n|---|\n| Bea |\n<{ :table }>\n", metadata:)

    expect(html).to include('<td>Ada</td>')
    expect(html).not_to include('Bea')
    expect(File.read(csv)).to eq("name,role\nAda,engineer\nLin,\"design | ux\"\n")
  end
end
