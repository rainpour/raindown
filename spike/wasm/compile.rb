# frozen_string_literal: true

require 'fileutils'

# Compiles each Ruby file in the folders to bytecode, in the out folder, at its path with .yarb after it, like
# /bytecode/raindown/lib/raindown.rb.yarb, so bytecode.rb can load it rather than parsing and compiling it. Bytecode
# only loads in the Ruby it was compiled by, so pack.sh runs this in Ruby compiled to WebAssembly.
#   ruby compile.rb /bytecode /raindown/lib /antlers/lib ...
out, *folders = ARGV
compiled = failed = 0
folders.each do |folder|
  Dir.glob("#{folder}/**/*.rb").each do |file|
    bytecode = File.join(out, "#{file}.yarb")
    FileUtils.mkdir_p(File.dirname(bytecode))
    File.binwrite(bytecode, RubyVM::InstructionSequence.compile_file(file).to_binary)
    compiled += 1
  rescue SyntaxError, StandardError => e
    warn "Can't compile #{file}: #{e.message}"
    failed += 1
  end
end
puts "Compiled #{compiled} files to bytecode#{", #{failed} failed" if failed.positive?}"
