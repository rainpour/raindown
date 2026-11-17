# frozen_string_literal: true

require 'raindown'
require 'raindown/action'
require 'raindown/editing'
require 'json'
require 'quickjs'
require 'tmpdir'

RSpec.describe Raindown::Action do
  let(:markdown) { "# Map\n\n<!-- Weather: 'Paris' zoom: 8 days=3 -->\n<!-- :Weather -->\n" }

  it "sets props where the directive has them, as they'd be typed, after its argument" do
    edited = described_class.new(line: 2, set: { 'zoom' => 9, days: 'four' }).apply(markdown)

    expect(edited.lines[2]).to eq("<!-- Weather: 'Paris' zoom: 9 days='four' -->\n")
  end

  it "leaves the note as it was for a prop the directive hasn't got, or a line that isn't one" do
    expect(described_class.new(line: 2, set: { title: 'x' }).apply(markdown)).to eq(markdown)
    expect(described_class.new(line: 0, set: { zoom: 1 }).apply(markdown)).to eq(markdown)
    expect(described_class.new(line: 9, set: { zoom: 1 }).apply(markdown)).to eq(markdown)
  end

  it "sets a prop in a grid's cell, by the column the cell starts at, not another cell's" do
    row = "| <{ :Weather zoom: 2 }> | <{ :Weather zoom: 5 }> |\n"
    column = row.index('|', 1) + 1

    expect(described_class.new(line: 0, column:, set: { zoom: 7 }).apply(row))
      .to eq("| <{ :Weather zoom: 2 }> | <{ :Weather zoom: 7 }> |\n")
  end

  it 'writes text with a single quote in double ones' do
    expect(described_class.new(line: 2, set: { days: "it's" }).apply(markdown).lines[2]).to include(%(days="it's"))
  end

  describe 'in JavaScript, as an app makes it at once' do
    let(:vm) { Quickjs::VM.new.tap { it.eval_code(File.read(described_class::SCRIPT)) } }
    let(:cases) do
      cell = "| <{ :Weather zoom: 2 }> | <{ :Weather zoom: 5 }> |\n"
      [[markdown, { line: 2, set: { zoom: 9, days: 'four' } }],
       [markdown, { line: 2, set: { title: 'x' } }],
       [markdown, { line: 0, set: { zoom: 1 } }],
       [markdown, { line: 2, set: { days: "it's" } }],
       [markdown, { line: 2, set: { zoom: nil } }],
       ["<{ Card: title: Hello world size: 2 }>\n<{ :Card }>\n", { line: 0, set: { size: 3, title: 'Bye' } }],
       ["<{ :Card title='A' }>\n", { line: 0, set: { title: 'B' } }],
       ["chart: 'data.csv', total: true\n", { line: 0, set: { total: false } }, true],
       ["chart: 'data.csv', total: true\n", { line: 0, set: { total: false } }, false],
       ["Card: title: 'A' size: 2\n", { line: 0, set: { size: 3 } }, false],
       [":Card title='A'\n", { line: 0, set: { title: 'B' } }, false],
       [cell, { line: 0, column: cell.index('|', 1) + 1, set: { zoom: 7 } }]]
    end

    it 'takes the same action as Raindown does, so it never shows one Raindown writes back otherwise' do
      cases.each do |text, action, bare = false|
        script = "raindownAfterAction(#{text.to_json}, #{action.to_json}, #{{ bare: }.to_json})"
        expect(vm.eval_code(script)).to eq(described_class.new(**action).apply(text, bare:)), "#{text.inspect} with #{action}"
      end
    end

    it "knows Raindown's own nodes' names" do
      names = File.read(described_class::SCRIPT)[/NAME = String\.raw`\(\?:([a-z|]+)\|/, 1].split('|')

      expect(names).to eq(Raindown::Nodes::BUILT_INS.keys)
    end
  end

  it 'is taken before Raindown writes the note back, so its nodes write with it' do
    Dir.mktmpdir do |dir|
      { 'a' => 'ant', 'b' => 'bee' }.each { |name, tag| File.write(File.join(dir, "#{name}.md"), "---\ntags: [#{tag}]\n---\n") }
      path = File.join(dir, 'note.md')
      actions = [{ 'line' => 0, 'set' => { 'tags' => 'bee' } }]
      written = Raindown::Editing.rewrite_markdown("<!-- list: tags: 'ant' -->\n<!-- :list -->\n", path:, actions:)

      expect(written[:output]).to eq("<!-- list: tags: 'bee' -->\n- [b](b.md)\n<!-- :list -->\n")
    end
  end
end
