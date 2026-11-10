# frozen_string_literal: true

# The write-back in scenario.rb, timed, run natively or in WebAssembly by run.sh.
require 'json'

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require 'raindown/rewriter'
loaded = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require_relative 'scenario'

result = JSON.parse(RaindownSpike.run(ARGV.fetch(0)))
puts result['text'], '', result['csv']
puts "#{RUBY_PLATFORM}: loading #{((loaded - started) * 1000).round} ms, " +
     result['times'].map { |name, ms| "#{name} #{ms} ms" }.join(', ')
