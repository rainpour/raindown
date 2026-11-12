# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'open3'
require 'openssl'

module Raindown
  # What a node can ask Raindown for, the same from Ruby and JavaScript, wherever it runs: the web, its project's files,
  # a cache and git. A Ruby node gets them as raindown:, like metadata:, and a JavaScript one as raindown in its context,
  # each asking through its host, which ends here on the desktop and in the terminal, like an app's page asking its
  # server. Each call is a name and arguments that JSON can hold, so another platform, like a phone, can answer them
  # its own way, or not at all, like git, raising an Error, which a node can catch. Paths are its project's, from its
  # root, and can't leave it.
  class Services
    # What can be asked for, by the names the hosts send.
    NAMES = %w[fetch read list write cache_get cache_set git].freeze
    TIMEOUT = 10
    METHODS = %w[Get Head Post Put Patch Delete].freeze
    REDIRECTS = 3

    class Error < StandardError; end

    # The services for a project, by its root, made once.
    def self.at(root)
      @at ||= {}
      @at[File.expand_path(root)] ||= new(root:)
    end

    # The services for the page being written, from its metadata's root, or else the current folder.
    def self.for(metadata)
      root = metadata.root if metadata.respond_to?(:root)
      at(root || Dir.pwd)
    end

    attr_reader :root

    def initialize(root:)
      @root = File.expand_path(root)
    end

    # A call by its name and arguments, as a host sends it.
    def call(name, args = [])
      raise Error, "There's no #{name} service" unless NAMES.include?(name.to_s)

      public_send(name, *args)
    end

    # The response to a request, as { status, headers, body }, following redirects, its body as text.
    def fetch(url, options = {})
      options = options.transform_keys(&:to_s)
      response = request(URI(url), options)
      return redirected(url, response, options) if redirect?(response, options)

      { 'status' => response.code.to_i, 'headers' => response.to_hash.transform_values { it.join(', ') }, 'body' => response.body.to_s }
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
