# frozen_string_literal: true

# A table: write-back, as the Obsidian plugin asks for one, timed, run natively or in WebAssembly by run.sh.
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require 'raindown/rewriter'
loaded = Process.clock_gettime(Process::CLOCK_MONOTONIC)

dir = ARGV.fetch(0)
File.write(File.join(dir, 'groceries.csv'), "Item,Cost\nMilk made with beautiful cows,54\nEggs,68\n")
note = File.join(dir, 'notes.md')
metadata = Struct.new(:root).new(dir)
rewrite = ->(content) { Raindown::Rewriter.rewrite(content:, path: note, metadata:).content }

steps = {
  'write the table' => ->(_) { "---\nraindown: true\n---\n\n# Groceries\n\ntoc:\n\n## Shopping\n\ntable: groceries.csv\n" },
  'fix the Item column' => ->(text) { text.sub(/^\| -+ \| ---- \|$/, '| ========== | ---- |') },
  'expand the cell' => ->(text) { text.sub('…', '') },
  'edit a cost' => ->(text) { text.sub('| 68   |', '| 70   |') }
}
text = ''
timings = steps.map do |name, step|
  before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  text = rewrite.(step.(text))
  [name, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - before) * 1000).round(1)]
end

puts text, '', File.read(File.join(dir, 'groceries.csv'))
puts "#{RUBY_PLATFORM}: loading #{((loaded - started) * 1000).round} ms, " + timings.map { "#{it[0]} #{it[1]} ms" }.join(', ')
