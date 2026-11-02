# frozen_string_literal: true

require 'raindown/tui/blueprints/code_comments'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::CodeComments do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      example.run
    end
  end

  it 'finds the drawings in the comments above classes and methods, each described by the prose above it, and where it is' do
    File.write(File.join(@root, 'lib', 'pane.rb'), <<~RUBY)
      # The pane, below its title:
      #    ╭─ Title ─╮
      #    ╰─────────╯
      # Then its footer, drawn the same:
      #    ┌────────┐
      #    │ Footer │
      #    └────────┘
      class Pane
        # Not above a definition.
        #    ╭───╮
        #    ╰───╯
        x = 1

        #    ╭───╮
        #    │ A │
        #    ╰───╯
        def a = nil

        # An example of a file, not a drawing:
        #    ```mockup
        #    ╭───╮
        #    ╰───╯
        #    ```
        def b = nil
      end
    RUBY

    found = described_class.blueprints(@root)
    expect(found.map { [it.path, it.line, it.description, it.lines.first] })
      .to eq([['lib/pane.rb', 2, 'The pane, below its title:', '╭─ Title ─╮'],
              ['lib/pane.rb', 5, 'Then its footer, drawn the same:', '┌────────┐'],
              ['lib/pane.rb', 14, nil, '╭───╮']])
    expect(found.first.where).to eq('lib/pane.rb:2 · mockup')
  end
end
