# frozen_string_literal: true

require 'json'

# A table: write-back, with a TOC, as the Obsidian plugin asks for one: writing the table, fixing a column, expanding a
# cell and saving an edit, each timed. As a method, so a Ruby that's kept running can run it again and again.
module RaindownSpike
  STEPS = {
    'write the table' => ->(_) { "---\nraindown: true\n---\n\n# Groceries\n\ntoc:\n\n## Shopping\n\ntable: groceries.csv\n" },
    'fix the Item column' => ->(text) { text.sub(/^\| -+ \| ---- \|$/, '| ========== | ---- |') },
    'expand the cell' => ->(text) { text.sub('…', '') },
    'edit a cost' => ->(text) { text.sub('| 68   |', '| 70   |') }
  }.freeze
  Metadata = Struct.new(:root)

  module_function

  # The note and CSV written in the folder, and how long each step took, in milliseconds, as JSON.
  def run(dir)
    File.write(File.join(dir, 'groceries.csv'), "Item,Cost\nMilk made with beautiful cows,54\nEggs,68\n")
    note = File.join(dir, 'notes.md')
    text = ''
    times = STEPS.to_h do |name, step|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      text = Raindown::Rewriter.rewrite(content: step.(text), path: note, metadata: Metadata.new(dir)).content
      [name, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)]
    end
    JSON.generate(text:, csv: File.read(File.join(dir, 'groceries.csv')), times:)
  end
end
