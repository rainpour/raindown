# frozen_string_literal: true

module Raindown
  # Ruby leaves YJIT off unless asked, which makes nodes that compute in loops several times faster.
  module Yjit
    module_function

    def enable
      RubyVM::YJIT.enable if available?
    end

    # A Ruby built without YJIT, like ruby.wasm's, has no RubyVM::YJIT. macOS kills a tebako binary, which is signed ad
    # hoc, as soon as it runs code YJIT compiled, so the binary's files, under /__tfs__/, leave it off there.
    def available?
      return false unless defined?(RubyVM::YJIT)

      !(RUBY_PLATFORM.include?('darwin') && __dir__.start_with?('/__tfs__/'))
    end
  end
end
