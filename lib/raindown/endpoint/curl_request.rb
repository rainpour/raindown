# frozen_string_literal: true

module Raindown
  module Curl
    # The request a snippet makes, with its headers and body, as curl would send it, for Curl.fetcher to send in its place.
    # Data, joined by &, is the body, as a form unless it's --json, or with --get, the URL's query.
    class Request < Data.define(:method, :url, :headers, :body)
      FORM = { 'Content-Type' => 'application/x-www-form-urlencoded' }.freeze
      JSON_HEADERS = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.freeze
      HEADER_OPTIONS = { '--user-agent' => 'User-Agent', '--referer' => 'Referer' }.freeze

      def initialize(method:, url:, headers: {}, body: nil) = super

      # From curl's checked arguments, with their options spelled long.
      def self.from(args)
        options = options(args)
        url = options.assoc('--url').last
        data = options.filter_map { |option, value| data_value(option, value) }.join('&')
        headers = headers(options)
        return new(method: request_method(args), url:, headers:) if data.empty?
        return new(method: request_method(args), url: with_query(url, data), headers:) if args.include?('--get')

        new(method: request_method(args), url:, headers: FORM.merge(headers), body: data)
      end

      # A snippet that sends data is a POST, unless it says otherwise, as with curl.
      def self.request_method(args)
        index = args.index('--request')
        return args[index + 1].upcase if index
        return 'HEAD' if args.include?('--head')
        return 'GET' if args.include?('--get')
        return 'POST' if args.intersect?(VALUE_CHECKS.keys.grep(/data|json/))

        'GET'
      end

      # The options, each with its value or nil, and each URL as a --url, like ['--url', 'https://a.io'].
      def self.options(args)
        words = args.dup
        pairs = []
        until words.empty?
          word = words.shift
          pairs << if VALUE_CHECKS.key?(word) then [word, words.shift]
                   elsif word.start_with?('--') then [word, nil]
                   else ['--url', word]
                   end
        end
        pairs
      end

      def self.headers(options)
        options.each_with_object({}) do |(option, value), headers|
          case option
          when '--header'
            name, header = value.split(':', 2)
            headers[name.strip] = header.to_s.strip
          when '--user' then headers['Authorization'] = "Basic #{[value].pack('m0')}"
          when '--json' then headers.merge!(JSON_HEADERS)
          else headers[HEADER_OPTIONS[option]] = value if HEADER_OPTIONS.key?(option)
          end
        end
      end

      # As curl sends it: --data without line breaks, and --data-urlencode encoded.
      def self.data_value(option, value)
        case option
        when '--data', '--data-ascii' then value.delete("\r\n")
        when '--data-raw', '--data-binary', '--json' then value
        when '--data-urlencode' then urlencoded(value)
        end
      end

      # Like curl's --data-urlencode, with name=content or =content, only the content's encoded.
      def self.urlencoded(value)
        name, equals, content = value.partition('=')
        return URI.encode_uri_component(value) if equals.empty?

        [name, URI.encode_uri_component(content)].reject(&:empty?).join('=')
      end

      def self.with_query(url, query)
        return "#{url}&#{query}" if url.include?('?')

        "#{url}?#{query}"
      end

      private_class_method :options, :headers, :data_value, :urlencoded, :with_query
    end
  end
end
