# frozen_string_literal: true

# Lists the standard library files a write-back loads, in stdlib.txt, by their paths in its folder, with this Ruby's
# platform's folder as WebAssembly's, so pack.sh packs only those, rather than all 18 MB of it. Run natively, with
# Raindown's load path, as run.sh's native run:
#   ruby --disable-gems -rrbconfig -I... spike/wasm/stdlib.rb
require 'tmpdir'
require 'raindown'
require 'raindown/rewriter'
require_relative 'scenario'

Dir.mktmpdir { RaindownSpike.run(it) }
lib = RbConfig::CONFIG['rubylibdir']
files = $LOADED_FEATURES.select { it.start_with?("#{lib}/") && it.end_with?('.rb') }
                        .map { it.delete_prefix("#{lib}/").sub("#{RbConfig::CONFIG['arch']}/", 'wasm32-wasi/') }
File.write(File.join(__dir__, 'stdlib.txt'), "#{files.sort.join("\n")}\n")
puts "#{files.size} standard library files in stdlib.txt"
