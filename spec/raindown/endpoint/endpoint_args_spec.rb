# frozen_string_literal: true

require 'raindown/endpoint/endpoint_args'

RSpec.describe Raindown::EndpointArgs do
  describe '.parse' do
    it 'reads as:, status: and a schema up to the next keyword outside brackets' do
      args = described_class.parse(' schema: Schema[status: String, tags: Array[String]] as: user status: 201 ')

      expect(args).to eq(described_class.new(name: 'user', status: 201, schema: 'Schema[status: String, tags: Array[String]]'))
    end

    it 'reads a named schema' do
      expect(described_class.parse(" schema: 'User'", schemas: { 'User' => 'Schema[id: Integer]' }).schema)
        .to eq('Schema[id: Integer]')
    end

    it 'has nothing for an endpoint without arguments' do
      expect(described_class.parse(' ')).to eq(described_class.new(name: nil, status: nil, schema: nil))
    end
  end

  describe '#failures' do
    def failures(text, body: '{"id": 1}', status: 200)
      described_class.parse(text).failures(body:, status:)
    end

    it 'checks the status, unless the response has none' do
      expect(failures('status: 200', status: 404)).to eq(['expected status 200, received 404'])
      expect(failures('status: 200', status: nil)).to eq([])
    end

    it "lists where the response doesn't match its schema" do
      body = '{"id": "1", "address": {"city": 2}}'

      expect(failures('schema: Schema[id: Integer, email: String | nil, address: Schema[city: String]]', body:))
        .to eq(['id: expected Integer, received "1"', 'address.city: expected String, received 2'])
    end

    it 'checks lists of records and responses that are not JSON' do
      expect(failures('schema: Array[Schema[id: Integer]]', body: '[{"id": 1}, {"id": "x"}]'))
        .to eq(['[1].id: expected Integer, received "x"'])
      expect(failures('schema: Integer', body: "OK\n")).to eq(['response: expected Integer, received "OK"'])
    end

    it "reports a schema that isn't a type, without running it" do
      expect(failures("schema: Dir['*']").first).to start_with("schema: 'Dir['*']' isn't allowed in a type")
    end
  end
end
