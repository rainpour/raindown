# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative '../front_matter'
require_relative 'curl'

module Raindown
  # The values that {placeholders} in an endpoint's curl snippet are replaced with, like {base_url} or {login.token}.
  # From least to most specific: the file's front matter, the project's environment, and the responses of endpoints
  # named with as:, read from the file as it goes. {env.NAME} is the environment variable NAME, for secrets, and an
  # environment's values can use it too, like token: '{env.STAGING_TOKEN}'.
  # The environment is one in .raindown/environments.yml, chosen with --env or RAINDOWN_ENV, or else the first:
  #   local:
  #     base_url: http://localhost:3000
  #   staging:
  #     base_url: https://staging.example.com
  class EndpointVariables
    class Error < Curl::Error; end

    FILE = 'environments.yml'
    PLACEHOLDER = /\{([A-Za-z_][\w.-]*)\}/

    def initialize(path:, content:)
      @path = path
      @content = content
    end

    # Keeps a named endpoint's response, as its JSON's data when it's JSON, or else its text.
    def remember(name, body)
      return unless name

      values[name] = begin
        JSON.parse(body)
      rescue JSON::ParserError
        body.strip
      end
    end

    # The text with each placeholder that has a value replaced by it, and the rest left as they are. A value's own
    # placeholders are replaced once, so an environment can read secrets like {env.TOKEN}.
    def substitute(text, depth: 1)
      text.gsub(PLACEHOLDER) do |placeholder|
        value = value(Regexp.last_match(1))
        next placeholder if value.nil?
        next value.to_json if value.is_a?(Hash) || value.is_a?(Array)
        next substitute(value, depth: 0) if depth.positive? && value.is_a?(String)

        value.to_s
      end
    end

    private

    # Read when they're first needed, so a file without endpoints doesn't need its environment.
    def values
      @values ||= FrontMatter.parse(@content).first.transform_keys(&:to_s).merge(environment, 'env' => ENV.to_h)
    end

    def environment
      folder = @path && Nodes.find_folder(File.dirname(File.expand_path(@path)))
      file = folder && File.join(folder, FILE)
      return {} unless file && File.exist?(file)

      environments = YAML.safe_load_file(file) || {}
      name = ENV.fetch('RAINDOWN_ENV') { environments.keys.first }
      environments.fetch(name) { raise Error, "There's no #{name} environment in #{file}" }
    end

    # A value by its path, like login.token or users.0.id.
    def value(name)
      name.split('.').reduce(values) do |value, key|
        case value
        when Hash then value.fetch(key) { value[key.to_sym] }
        when Array then value[Integer(key, exception: false) || value.length]
        end
      end
    end
  end
end
