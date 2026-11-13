# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'open3'
require 'openssl'

module Raindown
  class Services
    # The services on the desktop and in the terminal, in Raindown's own process: the web with Net::HTTP, the
    # project's files, a cache in ~/.cache/raindown and git, which it runs.
    class Local
      TIMEOUT = 10
      METHODS = %w[Get Head Post Put Patch Delete].freeze
      REDIRECTS = 3

      # A call's answer, from the project's services, by its root.
      def self.call(root, name, args)
        @at ||= {}
        (@at[root] ||= new(root:)).public_send(name, *args)
      end

      attr_reader :root

      def initialize(root:)
        @root = File.expand_path(root)
      end

      # The response to a request, as { status, headers, body }, following redirects, its body as text.
      def fetch(url, options = {})
        options = options.transform_keys(&:to_s)
        response = request(URI(url), options)
        return redirected(url, response, options) if redirect?(response, options)

        headers = response.to_hash.transform_values { it.join(', ') }
        { 'status' => response.code.to_i, 'headers' => headers, 'body' => body_of(response, options) }
      rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
        raise Error, "Couldn't reach #{url}: #{e.message}"
      end

      def read(path)
        File.read(inside(path))
      rescue Errno::ENOENT
        raise Error, "There's no #{path}"
      end

      # The project's files matching a pattern, like 'notes/*.md', from its root.
      def list(pattern = '**/*')
        Dir.glob(pattern, base: root).select { File.file?(File.join(root, it)) }.sort
      end

      def write(path, text)
        path = inside(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text)
        nil
      end

      # What was kept under a key for the project, or nil when nothing was, or it's older than the seconds it was kept for.
      def cache_get(key)
        kept = JSON.parse(File.read(cache_file(key)))
        return if kept['until'] && Time.now.to_f > kept['until']

        kept['value']
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      # Keeps a value JSON can hold under a key, for so many seconds, or until it's kept again.
      def cache_set(key, value, seconds = nil)
        FileUtils.mkdir_p(File.dirname(cache_file(key)))
        File.write(cache_file(key), JSON.generate('until' => seconds && (Time.now.to_f + seconds), 'value' => value))
        nil
      end

      # What git writes, run in the project with the arguments, like ('branch', '--list').
      def git(*args)
        output, errors, status = Open3.capture3('git', *args.map(&:to_s), chdir: root)
        raise Error, git_error(args, errors) unless status.success?

        output
      rescue Errno::ENOENT
        raise Error, 'git is not installed'
      end

      private

      # Its body as UTF-8 text, or as Base64 with encoding: 'base64', for a file that isn't text, like an image.
      def body_of(response, options)
        return [response.body.to_s].pack('m0') if options['encoding'] == 'base64'

        response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub
      end

      def git_error(args, errors)
        return "git #{args.first} failed" if errors.strip.empty?

        errors.strip
      end

      def request(uri, options)
        method = (options['method'] || 'GET').to_s.capitalize
        raise Error, "Can't #{method.upcase} with fetch" unless METHODS.include?(method)

        http_request = Net::HTTP.const_get(method).new(uri, options['headers'] || {})
        http_request.body = options['body'] if options['body']
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
          http.request(http_request)
        end
      end

      def redirected(url, response, options)
        fetch(URI.join(url, response['location']).to_s, options.merge('redirects' => redirects_left(options) - 1))
      end

      def redirect?(response, options) = response.is_a?(Net::HTTPRedirection) && redirects_left(options).positive?

      def redirects_left(options) = options.fetch('redirects', REDIRECTS)

      # The path in the project, which it must be.
      def inside(path)
        full = File.expand_path(path.to_s, root)
        raise Error, "#{path} is outside the project" unless full.start_with?("#{root}/")

        full
      end

      def cache_file(key)
        name = Digest::SHA256.hexdigest("#{root}\n#{key}")[0, 24]
        File.join(ENV.fetch('XDG_CACHE_HOME', File.join(Dir.home, '.cache')), 'raindown', 'nodes', "#{name}.json")
      end
    end
  end
end
