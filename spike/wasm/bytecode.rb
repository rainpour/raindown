# frozen_string_literal: true

# Loads each Ruby file from its bytecode, which compile.rb compiled ahead of time and pack.sh packed at /bytecode, rather
# than parsing and compiling its source, as Bootsnap does, or from RAINDOWN_BYTECODE, natively. Ruby asks load_iseq for each file it loads, and compiles the
# source itself when it returns nil, like for a file without bytecode, or bytecode another Ruby compiled.
class RubyVM::InstructionSequence # rubocop:disable Style/ClassAndModuleChildren -- reopens Ruby's own class
  def self.load_iseq(path)
    bytecode = "#{ENV.fetch('RAINDOWN_BYTECODE', '/bytecode')}#{path}.yarb"
    return unless File.exist?(bytecode)

    load_from_binary(File.binread(bytecode))
  rescue RuntimeError
    nil
  end
end
