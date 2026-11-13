# frozen_string_literal: true

require 'net/http'
require 'openssl'

module Raindown
  class Services
    # Connections to the web, kept open after a request for the next to the same host, so a component asking a host for
    # many things, like a map's tiles, doesn't open a connection, with its TLS handshake, for each. Each is used by one
    # request at a time, and Net::HTTP opens it again when it's been idle too long, or retries a request once when the
    # host had closed it.
    module Connections
      # How long a connection's kept idle, in seconds, and how many are kept for each host.
      KEEP_FOR = 30
      MOST_KEPT = 8

      @idle = Hash.new { |hash, key| hash[key] = [] }
      @lock = Mutex.new

      module_function

      # The response to a request, sent on a kept connection to its URI's host, or a new one.
      def request(uri, http_request, timeout:)
        key = [uri.scheme, uri.host, uri.port]
        connection = take(key) || opened(uri, timeout)
        response = connection.request(http_request)
        keep(key, connection)
        response
      rescue StandardError
        close(connection)
        raise
      end

      def opened(uri, timeout)
        connection = Net::HTTP.new(uri.host, uri.port)
        connection.use_ssl = uri.scheme == 'https'
        connection.open_timeout = timeout
        connection.read_timeout = timeout
        connection.keep_alive_timeout = KEEP_FOR
        connection.start
      end

      def take(key)
        @lock.synchronize { @idle[key].pop }
      end

      def keep(key, connection)
        kept = @lock.synchronize { @idle[key].size < MOST_KEPT && @idle[key].push(connection) }
        close(connection) unless kept
      end

      def close(connection)
        connection.finish if connection&.started?
      rescue IOError
        nil
      end

      # Forgets the kept connections, closing them.
      def clear
        idle = @lock.synchronize { @idle.values.flatten.tap { @idle.clear } }
        idle.each { close(it) }
      end
    end
  end
end
