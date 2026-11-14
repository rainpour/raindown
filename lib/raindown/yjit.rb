# frozen_string_literal: true

module Raindown
  # Ruby leaves YJIT off unless asked, which makes nodes that compute in loops several times faster. A Ruby built
  # without it, like ruby.wasm's, has no RubyVM::YJIT.
  module Yjit
    # The runtime a macOS binary carries, signed to allow YJIT, as its folder in tebako's cache and its SHA-256, which
    # rakelib's tebako task writes into the package.
    RUNTIME = File.expand_path('../../yjit_runtime', __dir__)

    module_function

    def enable
      RubyVM::YJIT.enable if defined?(RubyVM::YJIT) && allowed?
    end

    # macOS kills a binary as soon as it runs code YJIT compiled, unless its runtime's signed to allow it. The binary
    # carries one that is, but tebako runs the one it cached first, which an earlier binary may have left, tebako's own.
    def allowed?
      return true unless RUBY_PLATFORM.include?('darwin') && __dir__.start_with?('/__tfs__/')
      return false unless File.exist?(RUNTIME)

      folder, digest = File.read(RUNTIME).split
      cached = File.join(Dir.home, '.tebako', 'runtimes', folder, 'sha256')
      File.exist?(cached) && File.read(cached).start_with?(digest)
    end
  end
end
