# frozen_string_literal: true

require 'json'
require_relative 'schema_block'

module Raindown
  # An endpoint directive's arguments: as: names its response for later snippets, and status: and schema: are what its
  # response is checked against, like "as: user status: 200 schema: Schema[id: Integer, email: String | nil]".
  # A schema is a LowType type, read without running it, and is written with Schema[] rather than {}, which Antlers reads,
  # or names a SchemaBlock, like schema: 'User' or schema: Array[User].
  class EndpointArgs < Data.define(:name, :status, :schema)
    KEYWORDS = %w[as: status: schema:].freeze

    def self.parse(text, schemas: {})
      values = keyword_values(text.to_s)
      new(name: values['as'], status: values['status']&.then { Integer(it, exception: false) },
          schema: values['schema']&.then { SchemaBlock.resolve(it, schemas) })
    end

    # Each keyword's words, up to the next keyword outside brackets, so a schema's own keys, like Schema[status: Integer],
    # stay in it.
    def self.keyword_values(text)
      values = {}
      key = nil
      depth = 0

      text.split.each do |word|
        next values[key = word.delete_suffix(':')] = [] if depth.zero? && KEYWORDS.include?(word)
        next unless key

        values[key] << word
        depth += word.count('[(') - word.count('])')
      end

      values.transform_values { it.join(' ') }
    end

    # What's wrong with a response, like "expected status 200, received 404" or "id: expected Integer, received "1"".
    # A response fetched before statuses were kept has no status to check.
    def failures(body:, status:)
      failures = []
      failures << "expected status #{self.status}, received #{status}" if self.status && status && status != self.status
      failures.concat(schema_failures(body)) if schema
      failures
    end

    private

    # LowType is only loaded for an endpoint with a schema.
    def schema_failures(body)
      require 'lowtype'

      Low::TypeParser.parse(schema).errors(data(body)).map do |node|
        "#{node.path.to_s.empty? ? 'response' : node.path}: expected #{node.expected}, received #{node.received}"
      end
    rescue Low::ParseError => e
      ["schema: #{e.message}"]
    end

    def data(body)
      JSON.parse(body)
    rescue JSON::ParserError
      body.strip
    end
  end
end
