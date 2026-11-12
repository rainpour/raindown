# frozen_string_literal: true

require 'json'

module Raindown
  module JSNodes
    # JavaScript Components run in QuickJS, inside Raindown's own process, so they need nothing installed, answering the
    # same requests as NodeJS. Like a page, it has no Node APIs, but a node's file can import others by their paths
    # from it, like '../lib/release.mjs', and has setTimeout, URL and TextEncoder, and Raindown's services. What it
    # logs goes to stderr.
    class QuickJSHost
      RUNTIME = %w[services.js quickjs_runtime.js].map { File.join(__dir__, it) }
      # How long a request can run, in milliseconds, its services' time included.
      TIMEOUT = 60_000

      def initialize
        require 'quickjs'
        @vm = Quickjs::VM.new(features: [Quickjs::FEATURE_TIMEOUT, Quickjs::POLYFILL_URL, Quickjs::POLYFILL_ENCODING],
                              timeout_msec: TIMEOUT)
        @vm.module_loader = ->(specifier, importer) { module_of(specifier, importer) }
        @vm.define_function('__raindownService') { |root, name, args| JSON.generate(Services.at(root).call(name, JSON.parse(args))) }
        @vm.on_log { warn it }
        @vm.eval_code(RUNTIME.map { File.read(it) }.join("\n"))
      end

      def request(**message)
        import(message[:folder]) if message[:op] == 'load'
        reply = JSON.parse(@vm.call('__raindown.request', JSON.generate(sent(message))))
        raise Error, reply['error'] if reply['error']

        reply
      rescue Quickjs::RuntimeError => e
        raise Error, e.message
      end

      private

      def files(folder) = Dir.glob(EXTENSIONS.map { "*#{it}" }, base: folder).sort.map { File.join(folder, it) }

      def sent(message)
        return message unless message[:op] == 'load'

        { op: 'load', files: files(message[:folder]) }
      end

      # Each of the folder's files, but one that can't be, which says why on stderr, so the others still load.
      def import(folder)
        files(folder).each do |file|
          @vm.import('* as exports', filename: file, code_to_expose: "__raindown.register(#{JSON.generate(file)}, exports)")
        rescue Quickjs::RuntimeError => e
          warn "Couldn't load #{file}: #{e.message}"
        end
      end

      # A module's source by its path from the file importing it, which must be a file.
      def module_of(specifier, importer)
        path = File.expand_path(specifier, File.dirname(importer.to_s))
        { code: File.read(path), as: path } if File.file?(path)
      end
    end
  end
end
