# frozen_string_literal: true

# Stands in for Commonmarker, a native Rust gem that isn't in the WebAssembly build, so anything that reaches it, like
# rendering HTML, fails saying so, rather than the write-back being thought not to need it.
module Commonmarker
  def self.parse(*)
    raise NotImplementedError, "Commonmarker isn't in this WebAssembly build"
  end
end
