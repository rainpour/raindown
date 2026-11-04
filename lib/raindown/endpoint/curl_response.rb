# frozen_string_literal: true

require 'json'

module Raindown
  module Curl
    # A response's body, its code block language, and its status code and time, like 200 in 142 milliseconds,
    # read from what curl prints with --write-out WRITE_OUT.
    class Response < Data.define(:body, :language, :status, :milliseconds)
      # Separates the response body from the status, time and content type that --write-out appends.
      INFO_MARKER = "\n--raindown-response-info--"
      WRITE_OUT = "#{INFO_MARKER}%{http_code} %{time_total} %{content_type}".freeze # rubocop:disable Style/FormatStringToken -- curl's syntax, not Ruby's
      LANGUAGES = {
        /json/ => 'json', /xml/ => 'xml', /html/ => 'html', /javascript/ => 'javascript',
        /css/ => 'css', /yaml/ => 'yaml', %r{\Atext/plain} => 'text'
      }.freeze

      # JSON is pretty-printed, and other bodies are kept as they are.
      def self.parse(stdout)
        body, _, info = stdout.rpartition(INFO_MARKER)
        status, seconds, content_type = info.split(' ', 3)
        language = LANGUAGES.find { |pattern, _| content_type.to_s.match?(pattern) }&.last || ''

        new(body: language == 'json' ? pretty_json(body) : body, language:, status: status.to_i,
            milliseconds: (seconds.to_f * 1000).round)
      end

      def self.pretty_json(body)
        JSON.pretty_generate(JSON.parse(body))
      rescue JSON::ParserError
        body
      end
    end
  end
end
