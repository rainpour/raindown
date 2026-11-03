# frozen_string_literal: true

require_relative '../nodes'

module Raindown
  # A schema named for endpoints to check their responses against: a schema directive with its fields below it,
  # indented, which become a LowType Schema[], where a key with no type holds the more indented fields below it:
  #   <!-- schema: 'User'          schema: 'User'
  #     name: String                 name: String
  #     address:                     address:
  #       city: String                 city: String
  #   -->
  # is Schema[name: String, address: Schema[city: String]]. Bare, in a Raindown file, its fields end at the first line
  # that isn't indented. An endpoint below it names it, like schema: 'User' or schema: Array[User], as can a schema.
  # Schemas in the project's .raindown/schemas.rd, written the same way, are named for every file's endpoints.
  class SchemaBlock < Data.define(:name, :fields, :last)
    COMMENT = /\A {0,3}<!--\s*schema:\s*(['"])([A-Z]\w*)\1\s*$/
    BARE = /\A {0,3}schema:\s*(['"])([A-Z]\w*)\1\s*$/
    FIELD = /\A([ \t]*)(\S+:)[ \t]*(.*?)\s*\z/
    FILE = 'schemas.rd'

    # The schema starting at index, or nil when the line doesn't start one.
    def self.at(lines, index, bare: false)
      if (name = lines[index][COMMENT, 2])
        close = (index + 1...lines.length).find { lines[it].strip == '-->' }
        new(name:, fields: lines[index + 1...close], last: close) if close
      elsif bare && (name = lines[index][BARE, 2])
        last = index
        last += 1 while lines[last + 1]&.match?(/\A[ \t]+\S/)
        new(name:, fields: lines[index + 1..last], last:)
      end
    end

    # The schemas in the project's .raindown/schemas.rd, by name.
    def self.shared(path)
      folder = path && Nodes.find_folder(File.dirname(File.expand_path(path)))
      file = folder && File.join(folder, FILE)
      return {} unless file && File.exist?(file)

      lines = File.readlines(file)
      schemas = {}
      index = 0

      while index < lines.length
        if (block = at(lines, index, bare: true))
          schemas[block.name] = resolve(block.type, schemas)
          index = block.last
        end
        index += 1
      end

      schemas
    end

    # A schema: argument with the schemas it names written out, like Array[User] as Array[Schema[name: String]].
    def self.resolve(text, schemas)
      text = text.strip
      text = text[1...-1] if text.match?(/\A(['"]).*\1\z/)
      text.gsub(/\b[A-Z]\w*\b/) { schemas.fetch(it, it) }
    end

    # Each field's indent, key and type, as Schema[key: Type].
    def self.type(fields)
      pairs = []

      until fields.empty?
        indent, key, value = fields.shift
        nested = []
        nested << fields.shift while fields.first && fields.first[0].length > indent.length
        value = type(nested) if nested.any?
        pairs << "#{key} #{value}"
      end

      "Schema[#{pairs.join(', ')}]"
    end

    def type
      self.class.type(fields.filter_map { it.match(FIELD)&.captures })
    end
  end
end
