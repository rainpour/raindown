# frozen_string_literal: true

require 'json'
require 'quickjs'
require 'raindown'
require 'raindown/editing'

RSpec.describe 'Raindown::Editing::SCRIPT' do
  let(:vm) { Quickjs::VM.new.tap { it.eval_code(File.read(Raindown::Editing::SCRIPT)) } }

  def aligned(markdown)
    vm.eval_code("raindownEditing.alignTables(#{markdown.to_json})")
  end

  it 'lines up tables as they are typed the same as Raindown writes them back' do
    [
      "| a | bb |\n|-|-|\n| ccc | d |\n",
      "| left | right | centre |\n|:-|-:|:-:|\n| a | b | c |\n",
      "| fixed | free |\n| ===== | - |\n| a longer cell | b |\n",
      "| item | units |\n| --- | --- |\n| Tea | 3 |\n|+ more | |\n",
      "Text\n\n| x |\n| - |\n| wide 漢字 |\n\nAfter\n",
      "```\n| not | a table |\n|-|-|\n```\n"
    ].each do |markdown|
      expect(aligned(markdown)).to eq(Raindown::TableFormatter.rewrite(content: markdown)), markdown
    end
  end
end
