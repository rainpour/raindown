# frozen_string_literal: true

require 'raindown/endpoint/schema_block'

RSpec.describe Raindown::SchemaBlock do
  def schema_at(markdown, bare: false)
    described_class.at(markdown.lines, 0, bare:)
  end

  it 'reads the fields in a comment as a Schema[], nesting the more indented fields under a key without a type' do
    schema = schema_at("<!-- schema: 'User'\n  name: String | nil\n  address:\n    city: String\n  age: Integer\n-->\n")

    expect([schema.name, schema.last]).to eq(['User', 5])
    expect(schema.type).to eq('Schema[name: String | nil, address: Schema[city: String], age: Integer]')
  end

  it 'reads bare fields up to the first line that is not indented, only when bare directives are allowed' do
    markdown = "schema: \"User\"\n  name: String\n\nAfter.\n"

    expect(schema_at(markdown, bare: true)).to have_attributes(name: 'User', last: 1)
    expect(schema_at(markdown)).to be_nil
  end

  it "isn't a schema without a capitalized, quoted name or the comment's end" do
    expect(schema_at("<!-- schema: user\n  name: String\n-->\n")).to be_nil
    expect(schema_at("<!-- schema: 'User'\n  name: String\n")).to be_nil
  end

  it 'writes out the schemas a schema: argument names, quoted or inside a type' do
    schemas = { 'User' => 'Schema[name: String]' }

    expect(described_class.resolve("'User'", schemas)).to eq('Schema[name: String]')
    expect(described_class.resolve('Array[User] | nil', schemas)).to eq('Array[Schema[name: String]] | nil')
  end
end
