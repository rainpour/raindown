# frozen_string_literal: true

module Raindown
  # What a node can ask Raindown for, the same from Ruby and JavaScript, wherever it runs: the web, its project's files,
  # a cache and git. A Ruby node gets them as raindown:, like metadata:, and a JavaScript one as raindown in its context,
  # each asking through its host, which ends here, like an app's page asking its server. Each call is a name and
  # arguments that JSON can hold, answered by Services.host: Local on the desktop and in the terminal, or an app's own,
  # like the Obsidian plugin's worker, which can't run processes or open sockets. A platform without a service, like
  # git on a phone, raises an Error, which a node can catch. Paths are its project's, from its root, and can't leave it.
  class Services
    # What can be asked for, by the names the hosts send.
    NAMES = %w[fetch read list write cache_get cache_set git].freeze

    class Error < StandardError; end

    class << self
      # What answers each call, with call(root, name, args), which an app can give its own.
      attr_writer :host

      def host
        @host ||= begin
          require_relative 'services/local'
          Local
        end
      end

      # The services for a project, by its root, made once.
      def at(root)
        @at ||= {}
        @at[File.expand_path(root)] ||= new(root:)
      end

      # The services for the page being written, from its metadata's root, or else the current folder.
      def for(metadata)
        root = metadata.root if metadata.respond_to?(:root)
        at(root || Dir.pwd)
      end
    end

    attr_reader :root

    def initialize(root:)
      @root = File.expand_path(root)
    end

    # A call by its name and arguments, as a host sends it.
    def call(name, args = [])
      raise Error, "There's no #{name} service" unless NAMES.include?(name.to_s)

      self.class.host.call(root, name.to_s, args)
    end

    # The response to a request, as { status, headers, body }, following redirects, its body as text.
    def fetch(url, options = {}) = call('fetch', [url, options])

    def read(path, options = {}) = call('read', [path, options])

    # The project's files matching a pattern, like 'notes/*.md', from its root.
    def list(pattern = '**/*') = call('list', [pattern])

    def write(path, text) = call('write', [path, text])

    # What was kept under a key for the project, or nil when nothing was, or it's older than the seconds it was kept for.
    def cache_get(key) = call('cache_get', [key])

    # Keeps a value JSON can hold under a key, for so many seconds, or until it's kept again.
    def cache_set(key, value, seconds = nil) = call('cache_set', [key, value, seconds])

    # What git writes, run in the project with the arguments, like ('branch', '--list').
    def git(*args) = call('git', args)
  end
end
