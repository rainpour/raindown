# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'

module Raindown
  # JSON from the web, for nodes that ask an API, like painting:'s museum and weather:'s forecast, following a redirect
  # or two, and raising an Error when it can't be reached or doesn't answer with JSON.
  module HTTPJSON
    TIMEOUT = 10

    class Error < StandardError; end

    module_function

    def get(url, headers: {}, redirects: 3)
      response = request(URI(url), headers)
      redirect = response.is_a?(Net::HTTPRedirection) && redirects.positive?
      return get(URI.join(url, response['location']).to_s, headers:, redirects: redirects - 1) if redirect
      raise Error, "#{url} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue SocketError, SystemCallError, Timeout::Error, JSON::ParserError, OpenSSL::SSL::SSLError => e
      raise Error, "Couldn't reach #{url}: #{e.message}"
    end

    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end
  end
end
