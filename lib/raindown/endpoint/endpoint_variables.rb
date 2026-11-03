# frozen_string_literal: true

require 'json'
require 'yaml'
require 'antlers/api'
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
  # Secrets go in environments.local.yml beside it, which git ignores, and which adds to and overrides its environments.
  # Its values and env's are secret, so a response or error that echoes one is written with its placeholder instead.
  class EndpointVariables
    class Error < Curl::Error; end

    FILE = 'environments.yml'
    LOCAL_FILE = 'environments.local.yml'
    # Shorter values, like a port or a flag, would be replaced wherever they happen to appear in a response.
    SECRET_LENGTH = 4
    PLACEHOLDER = /\{([A-Za-z_][\w.-]*)\}/

    def initialize(path:, content:)
      @path = path
      @content = content
      @local_names = []
      @secrets = {}
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
        name = Regexp.last_match(1)
        value = value(name)
        next placeholder if value.nil?
        next value.to_json if value.is_a?(Hash) || value.is_a?(Array)

        value = depth.positive? && value.is_a?(String) ? substitute(value, depth: 0) : value.to_s
        @secrets[value] = placeholder if secret?(name) && value.length >= SECRET_LENGTH
        value
      end
    end

    # The text with each secret that was filled in put back as its placeholder, like {env.TOKEN}, longest first.
    def redact(text)
      @secrets.keys.sort_by { -it.length }.reduce(text) { |redacted, secret| redacted.gsub(secret, @secrets[secret]) }
    end

    private

    # Read when they're first needed, so a file without endpoints doesn't need its environment.
    def values
      @values ||= FrontMatter.parse(@content).first.transform_keys(&:to_s).merge(environment, 'env' => ENV.to_h)
    end

    def environment
      folder = @path && Nodes.find_folder(File.dirname(File.expand_path(@path)))
      return {} unless folder

      shared, local = [FILE, LOCAL_FILE].map { environments(File.join(folder, it)) }
      return {} if shared.empty? && local.empty?

      name = environment_name(shared, local)
      @local_names = local.fetch(name, {}).keys
      shared.fetch(name, {}).merge(local.fetch(name, {}))
    end

    # The one --env or RAINDOWN_ENV names, or else the first.
    def environment_name(shared, local)
      name = ENV.fetch('RAINDOWN_ENV') { (shared.keys + local.keys).first }
      return name if shared.key?(name) || local.key?(name)

      raise Error, "There's no #{name} environment in #{Nodes::FOLDER}/#{FILE}"
    end

    def environments(file)
      return {} unless File.exist?(file)

      YAML.safe_load_file(file) || {}
    end

    def secret?(name)
      first = name.split('.').first
      first == 'env' || @local_names.include?(first)
    end

    # A value by its path, like login.token or users.0.id.
    def value(name)
      Antlers::Queries.read_path(value: values, path: name.split('.'))
    end
  end
end
