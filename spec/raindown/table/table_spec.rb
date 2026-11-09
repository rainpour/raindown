# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'raindown/rewriter'
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
      <!-- 2 rows · hash -->
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

    expect(rewrite(table)).to match(/<!-- 1 row · \h{6} -->\n\| name \| role \|\n\|---\|---\|\n\| Ada \| lead \|\n\z/)
  end

  it 'writes neither when both changed, until they match again' do
    edited = synced.sub('engineer', 'lead')
    File.write(csv, "name,role\nAda,ops\n")

    conflict = nil
    expect { conflict = rewrite(edited) }.to output(/team.csv and its table both changed/).to_stderr
    expect([conflict, File.read(csv)]).to eq([edited.sub(/<!-- 2 rows/, '<!-- conflict'), "name,role\nAda,ops\n"])

    File.write(csv, "name,role\nAda,lead\nLin,design | ux\n")
    expect(rewrite(conflict)).to include('<!-- 2 rows')
  end

  it 'writes the file again into an emptied table, without emptying the file' do
    expect(rewrite(table(synced.lines[1].chomp))).to eq(synced)
    expect(File.read(csv)).to include('Ada,engineer')
  end

  describe 'a cell with a line break' do
    before { File.write(csv, "name,note\nAda,\"one\ntwo\"\nLin,short\n") }

    it "leaves the file alone when the table's only been written again" do
      expect(rewrite(synced)).to include('| Ada | one two |')
      expect(File.read(csv)).to eq("name,note\nAda,\"one\ntwo\"\nLin,short\n")
    end

    it 'keeps its line break when another cell is edited' do
      rewrite(synced.sub('| Lin | short |', '| Lin | long |'))

      expect(File.read(csv)).to eq("name,note\nAda,\"one\ntwo\"\nLin,long\n")
    end

    it 'writes the cell when it is edited' do
      rewrite(synced.sub('| Ada | one two |', '| Ada | three |'))

      expect(File.read(csv)).to eq("name,note\nAda,three\nLin,short\n")
    end
  end

  describe "the file's format, when a cell's edited" do
    def edit(from, to)
      rewrite(synced.sub(from, to))
      File.binread(csv)
    end

    it 'keeps its line endings' do
      File.binwrite(csv, "name,role\r\nAda,engineer\r\n")

      expect(edit('| Ada | engineer |', '| Ada | lead |')).to eq("name,role\r\nAda,lead\r\n".b)
    end

    it 'keeps a byte order mark out of the table, and in the file' do
      File.binwrite(csv, "\xEF\xBB\xBFname,role\nAda,engineer\n")

      expect(synced).to include('| name | role |')
      expect(edit('| Ada | engineer |', '| Ada | lead |')).to eq("\xEF\xBB\xBFname,role\nAda,lead\n".b)
    end

    it 'leaves empty cells empty' do
      File.binwrite(csv, "name,role\nAda,\n,ops\n")

      expect(edit('| Ada |  |', '| Eve |  |')).to eq("name,role\nEve,\n,ops\n".b)
    end

    it "keeps a row with one empty cell, which would otherwise be a blank line that isn't read" do
      File.binwrite(csv, "name\nAda\n\"\"\nLin\n")

      expect(edit('| Ada |', '| Eve |')).to eq("name\nEve\n\"\"\nLin\n".b)
      expect(rewrite("table: 'team.csv'\n")).to include('3 rows')
    end
  end

  describe 'a file outside the project' do
    let(:outside) { File.join(File.dirname(@root), "outside-#{File.basename(@root)}.csv") }
    let(:content) { "table: '../#{File.basename(outside)}'\n<!-- 1 row · 09ae51 -->\n| a |\n|---|\n| 9 |\n" }

    before { File.write(outside, "a\n1\n") }
    after { FileUtils.rm_f(outside) }

    it 'is neither shown nor written to' do
      expect(rewrite(content)).to include("as a table: it's outside the project")
      expect(File.read(outside)).to eq("a\n1\n")
    end

    it "isn't rendered" do
      html = Raindown.render(markdown: "<{ :table '../#{File.basename(outside)}' }>\n", metadata:)

      expect(html).to include("it's outside the project")
    end

    it 'can be named by its full path inside the project' do
      expect(rewrite("table: '#{csv}'\n")).to include('| Ada | engineer |')
    end
  end

  it 'says it needs a file when it has none' do
    message = 'Needs a file path to a CSV/TSV that exists or will be created'

    expect(rewrite("table:\n")).to include(message)
    expect(rewrite("table: ''\n")).to include(message)
  end

  describe 'a file that is not there yet' do
    let(:new_file) { File.join(@root, 'data', 'books.csv') }

    it 'is made from the table written below it, in a folder made for it' do
      written = rewrite("table: 'data/books.csv'\n| title | rating |\n|---|---|\n| Dune | 5 |\n")

      expect(File.read(new_file)).to eq("title,rating\nDune,5\n")
      expect(written).to include('<!-- 1 row').and include('| Dune | 5 |')
    end

    it 'is made with a table to fill in, when there is none' do
      written = rewrite("table: 'data/books.csv'\n")

      expect(File.read(new_file)).to eq("Column 1,Column 2\n,\n")
      expect(written).to include('| Column 1 | Column 2 |')
    end

    it 'is made from a table typed below the alert saying there was no file' do
      rewrite("table: 'data/books.csv'\n> [!WARNING]\n> Needs a file path\n| title |\n|---|\n| Dune |\n")

      expect(File.read(new_file)).to eq("title\nDune\n")
    end

    it "isn't made outside the project" do
      outside = File.join(File.dirname(@root), "made-#{File.basename(@root)}.csv")

      expect(rewrite("table: '../#{File.basename(outside)}'\n")).to include("it's outside the project")
      expect(File.exist?(outside)).to be(false)
    end

    it "isn't made when the table's only rendered" do
      Raindown.render(markdown: "<{ :table 'data/books.csv' }>\n", metadata:)

      expect(File.exist?(new_file)).to be(false)
    end
  end

  describe 'total: true' do
    let(:sales) { File.join(@root, 'sales.csv') }
    let(:totalled) { rewrite("table: 'sales.csv' total: true\n") }

    before { File.write(sales, "item,units,price,note\nTea,3,1.5,hot\nCake,,2.25,\nJam,2,0.1,\n") }

    it 'sums its columns of numbers in a bold row below it, to their most decimal places' do
      expect(totalled).to include("| Jam | 2 | 0.1 |  |\n| **Total** | **5** | **3.85** |  |\n").and include('3 rows')
    end

    it 'writes edits back to its file without the total, and sums them again' do
      edited = totalled.sub('| Tea | 3 |', '| Tea | 30 |').sub(/\| \*\*Total\*\*.*\n/, "\\0| Bun | 1 | 1 | |\n")

      expect(rewrite(edited)).to include("| Bun | 1 | 1 |  |\n| **Total** | **33** | **4.85** |  |\n")
      expect(CSV.read(sales).map { it.take(2) }).to eq([%w[item units], %w[Tea 30], ['Cake', nil], %w[Jam 2], %w[Bun 1]])
    end

    it 'shows its total in <{ }>' do
      expect(Raindown.render(markdown: "<{ :table 'sales.csv' total: true }>\n", metadata:)).to include('<strong>3.85</strong>')
    end
  end

  describe 'fixed-width columns' do
    let(:tasks) { File.join(@root, 'tasks.csv') }
    let(:clipped) { aligned(aligned(aligned("table: 'tasks.csv'\n")).sub(/^\| -+ \| -+ \|$/, '| ---- | ======== |')) }

    def aligned(content)
      Raindown::Rewriter.rewrite(content:, path: 'tasks.rd', metadata:).content
    end

    def body(table)
      table.lines.drop(4).join
    end

    before { File.write(tasks, "task,notes\nRelease,Tag the build and push it\nDocs,Done\n") }

    it 'clips cells longer than the column with an ellipsis, keeping their full text in the file' do
      expect(body(clipped)).to eq("| Release | Tag the… |\n| Docs    | Done     |\n")
      expect(aligned(clipped)).to eq(clipped)
      expect(File.read(tasks)).to include('Tag the build and push it')
    end

    it 'clips cells again as the column narrows or widens, leaving the file alone' do
      narrowed = %w[======= ====== ========== ========].reduce(clipped) do |table, equals|
        aligned(table.sub(/^\| -+ \| =+ \|$/, "| ---- | #{equals} |")).tap { expect(it[/^\| Release.*/]).to end_with('… |') }
      end

      expect(body(narrowed)).to start_with("| Release | Tag the… |\n")
      expect(File.read(tasks)).to include('Release,Tag the build and push it')
    end

    it 'shows the full text wrapped onto + rows when the ellipsis is deleted, until it changes, and is cut to fit' do
      revealed = aligned(clipped.sub('…', ''))

      expect(body(revealed)).to eq(<<~MARKDOWN)
        | Release | Tag the  |
        +         | build    |
        +         | and push |
        +         | it       |
        | Docs    | Done     |
      MARKDOWN
      expect(aligned(revealed)).to eq(revealed)
      edited = aligned(revealed.sub('and push', 'and ship'))
      expect(body(edited)).to start_with("| Release | Tag the… |\n")
      expect(File.read(tasks)).to include('Tag the build and ship it')
    end

    it 'keeps the end that was clipped off when the start is edited before the ellipsis' do
      expect(body(aligned(clipped.sub('Tag the…', 'Tag a…')))).to start_with("| Release | Tag a b… |\n")
      expect(File.read(tasks)).to include('Tag a build and push it')
    end

    it 'keeps the end that was clipped off when a + row carries on a clipped cell' do
      aligned(clipped.sub(/^(\| Release .*\n)/, "\\1+ | right away |\n"))

      expect(File.read(tasks)).to include('Tag the build and push it right away')
    end

    it 'writes + rows typed below a row into its cells, then clips them' do
      typed = aligned(clipped.sub(/^(\| Docs .*\n)/, "\\1+ | and check links |\n"))

      expect(body(typed)).to end_with("| Docs    | Done an… |\n")
      expect(File.read(tasks)).to include('Docs,Done and check links')
    end

    # Each key's typed after what the cell shows, as an editor's cursor is, and a space before the next key, as an
    # editor keeps the cursor after a space it's just typed, which the table trims, like an editor saving as it's typed.
    it 'keeps every key typed into a cell saved after each one, as it clips it, typed after its ellipsis' do
      table = clipped
      ' and check links'.chars.chunk_while { |key, _| key == ' ' }.each do |keys|
        table = aligned(table.sub(/^(?<cell>\| Docs +\| .*?)(?<padding> *\|)$/, "\\k<cell>#{keys.join}\\k<padding>"))
      end

      expect(File.read(tasks)).to include('Docs,Done and check links')
      expect(body(table)).to end_with("| Docs    | Done an… |\n")
    end
  end

  describe 'formula cells' do
    let(:sales) { File.join(@root, 'sales.csv') }
    let(:shown) { rewrite("table: 'sales.csv'\n") }

    def aligned(content)
      Raindown::Rewriter.rewrite(content:, path: 'sales.rd', metadata:).content
    end

    before { File.write(sales, "item,units,price\nTea,3,1.5\nCake,x,2.25\nTotal,=Sum(b),=sum(PRICE)\nNone,=SUM(Q),=AVG(B)\n") }

    it 'shows =SUM by column letter or header, in any case, as its value, skipping text and formulas, and others as written' do
      expect(shown).to include("| Total | 3 | 3.75 |\n| None | =SUM(Q) | =AVG(B) |\n")
    end

    it 'keeps formulas whose values are left alone, and writes edited ones back' do
      edited = aligned("table: 'sales.csv'\n").sub(/^\| Tea +\| 3 +\|/, '| Tea | 30 |').sub(/^\| None .*$/, '| None | 1 | =SUM(C) |')

      expect(aligned(edited)).to match(/^\| Total +\| 31 +\| 3\.75 +\|\n\| None +\| 1 +\| 3\.75 +\|$/)
      expect(File.read(sales)).to end_with("Total,=Sum(b),=sum(PRICE)\nNone,1,=SUM(C)\n")
    end

    it 'keeps formulas below a row that was added or removed' do
      added = aligned(aligned("table: 'sales.csv'\n").sub(/^(\| Total)/, "| Jam | 4 | 1 |\n\\1"))

      expect(added).to match(/^\| Total +\| 7 +\| 4\.75 +\|$/)
      expect(File.read(sales)).to include("Jam,4,1\nTotal,=Sum(b),=sum(PRICE)\nNone,=SUM(Q),=AVG(B)\n")

      expect(aligned(added.sub(/^\| Tea .*\n/, ''))).to match(/^\| Total +\| 4 +\| 3\.25 +\|$/)
      expect(File.read(sales)).to eq("item,units,price\nCake,x,2.25\nJam,4,1\nTotal,=Sum(b),=sum(PRICE)\nNone,=SUM(Q),=AVG(B)\n")
    end

    describe 'with its padding deleted' do
      let(:revealed) { aligned(aligned("table: 'sales.csv'\n").sub(/^(\| Total +)\| 3 +\|/, '\1|3|')) }

      it 'shows its formula, until the formula changes, ignoring whitespace' do
        expect(revealed).to match(/^\| Total +\| =Sum\(b\) +\| 3\.75 +\|$/)
        expect(aligned(revealed)).to eq(revealed)
        expect(aligned(revealed.sub('=Sum(b)', '= Sum( b )'))).to eq(revealed)
        expect(File.read(sales)).to include("Total,=Sum(b),=sum(PRICE)\n")
      end

      it 'writes a changed formula back to its file, and shows its value' do
        expect(aligned(revealed.sub('=Sum(b)', '=SUM(C)'))).to match(/^\| Total +\| 3\.75 +\| 3\.75 +\|$/)
        expect(File.read(sales)).to include("Total,=SUM(C),=sum(PRICE)\n")
      end

      it 'keeps showing its formula when a row is added above it' do
        expect(aligned(revealed.sub(/^(\| Total)/, "| Jam | 4 | 1 |\n\\1"))).to match(/^\| Total +\| =Sum\(b\) +\| 4\.75 +\|$/)
        expect(File.read(sales)).to include("Total,=Sum(b),=sum(PRICE)\n")
      end
    end

    it 'reads a row being typed as the file will, so finishing it is no conflict' do
      table = aligned("#{aligned("table: 'sales.csv'\n")}|\n")

      ['|  | =s', '|  | =sum(c) |'].each { |row| table = aligned(table.sub(/[^\n]*\n\z/, "#{row}\n")) }

      expect(table).not_to include('conflict')
      expect(File.read(sales)).to end_with(",=sum(c),\n")
    end

    it 'shows values in <{ }>' do
      expect(Raindown.render(markdown: "<{ :table 'sales.csv' }>\n", metadata:)).to include('<td>3.75</td>')
    end
  end

  it "says when its data isn't a CSV or TSV file" do
    expect(rewrite("table: 'team.json'\n")).to include('"team.json" must be a file path to a CSV/TSV that exists or will be created')
    expect(Raindown.render(markdown: "<{ :table 'missing.csv' }>\n", metadata:)).to include('no such file')
  end

  it 'shows its file in <{ }> without writing to it' do
    html = Raindown.render(markdown: "<{ table: 'team.csv' }>\n| name |\n|---|\n| Bea |\n<{ :table }>\n", metadata:)

    expect(html).to include('<td>Ada</td>')
    expect(html).not_to include('Bea')
    expect(File.read(csv)).to eq("name,role\nAda,engineer\nLin,\"design | ux\"\n")
  end
end
