# frozen_string_literal: true

require 'date'
require_relative '../bare_directives'
require_relative '../code_blocks'
require_relative 'curl'
require_relative 'endpoint_args'
require_relative 'schema_block'
require_relative 'endpoint_variables'

module Raindown
  # Runs the curl block under an endpoint directive in a comment, or a bare one, and writes the response in the code
  # block below it, followed by the date it was fetched, its status and how long it took.
  # Only runs when that block is missing or empty, and --execute is passed, so a file can't run requests by itself.
  # Or with only: and a directive's line index, runs just that endpoint, replacing any response it has.
  #   <!-- endpoint: -->
  #   ```sh
  #   curl https://api.example.com
  #   ```
  #   ```json
  #   { "id": 1 }
  #   ```
  #   <!-- raindown:fetched 2026-10-14 · 200 · 142 ms -->
  #   <!-- :endpoint -->
  # Its snippet's {placeholders} are filled from EndpointVariables, and with as: login, later snippets can use its
  # response, like {login.token}. With status: and schema:, each response in the file is checked, and failures are kept.
  # A schema: can name a SchemaBlock above it, like schema: 'User', or one in .raindown/schemas.rd.
  # One in Antlers' delimiters, <{ endpoint: }>, only renders, so it's never run.
  class EndpointRunner
    # An endpoint's directive in Antlers' delimiters, which only renders, or in a comment, which writes its response back,
    # and the end tag of either.
    DIRECTIVE = /\A {0,3}<\{\s*endpoint:(.*?)\}>[ \t]*$/
    COMMENT = /\A {0,3}<!--\s*endpoint:(.*?)-->[ \t]*$/
    END_TAG = /\A {0,3}(?:<\{\s*:endpoint\s*\}>|<!--\s*:endpoint\s*-->)[ \t]*$/
    # The date a response was fetched, on the line after it.
    FETCHED = /\A {0,3}<!-- raindown:fetched [^\n]*? -->[ \t]*$/
    FETCHED_STATUS = /raindown:fetched \S+ · (\d{3}) /

    attr_reader :failures

    def self.rewrite(content:, path: nil, bare: false, execute: false, **)
      new(content:, path:, bare: BareDirectives.enabled?(path:, content:, bare:), execute:).rewrite
    end

    def initialize(content:, path: nil, bare: false, execute: false, only: nil)
      @lines = content.lines
      @path = path
      @variables = EndpointVariables.new(path:, content:)
      @bare = bare
      @execute = execute
      @only = only
      @failures = []
      @schemas = SchemaBlock.shared(path)
    end

    def rewrite
      index = 0

      while index < @lines.length
        if (block = CodeBlocks.at(@lines, index))
          index = block[:close]
        elsif (schema = SchemaBlock.at(@lines, index, bare: @bare))
          @schemas[schema.name] = SchemaBlock.resolve(schema.type, @schemas)
          index = schema.last
        elsif (args = directive_args(@lines[index]))
          index = fill(index + 1, args, directive: index)
        end

        index += 1
      end

      @lines.join
    end

    private

    # The arguments of an endpoint that writes back: in a comment, or bare.
    def directive_args(line)
      args = line[COMMENT, 1]
      args ||= BareDirectives.wrap(line)&.[](DIRECTIVE, 1) if @bare
      EndpointArgs.parse(args, schemas: @schemas) if args
    end

    # Returns the index of the last line it handled.
    def fill(index, args, directive:)
      curl, output = CodeBlocks.endpoint(@lines, index)
      return index - 1 unless curl&.dig(:body)&.lstrip&.start_with?('curl')
      return write_output(curl:, output:, args:, directive:) if run?(output, directive)
      return curl[:close] unless output

      @variables.remember(args.name, output[:body])
      check(args, directive:, body: output[:body], status: fetched_status(output))
      curl[:close]
    end

    # The status in the fetched comment after a response, which responses fetched before statuses were kept don't have.
    def fetched_status(output)
      @lines[output[:close] + 1]&.[](FETCHED_STATUS, 1)&.to_i
    end

    # Run alone, only the endpoint that ran is checked. One without a response or a status hasn't run, so it has nothing
    # to check, while one that ran has a status even when its body is empty.
    def check(args, directive:, body:, status:)
      return if (@only && directive != @only) || (body.strip.empty? && status.nil?)

      location = [@path, directive + 1].compact.join(':')
      @failures.concat(args.failures(body:, status:).map { "#{location}: #{it}" })
    end

    def run?(output, directive)
      return directive == @only if @only

      @execute && (output.nil? || output[:body].strip.empty?)
    end

    # Replaces the output block and the date it was fetched, or with no block, replaces nothing just after the curl block.
    # Secrets that a response echoes are written as their placeholders.
    def write_output(curl:, output:, args:, directive:)
      response = Curl.run(curl[:body], @variables)
      body = @variables.redact(response.body)
      @variables.remember(args.name, body)
      check(args, directive:, body:, status: response.status)
      replace_output(curl:, output:, block: [*output_block(body, response.language), fetched(response)])
    rescue Curl::Error => e
      message = @variables.redact(e.message)
      # The one endpoint that was asked for fails for the caller to show, like in the terminal UI.
      raise Curl::Error, message if @only

      warn "Endpoint failed: #{message}"
      curl[:close]
    end

    # Returns the index of the block's last line.
    def replace_output(curl:, output:, block:)
      block.unshift("\n") unless output
      start = output ? output[:open] : curl[:close] + 1

      @lines[start, output ? replaced_length(output) : 0] = block
      start + block.length - 1
    end

    # The output block, and the line after it when that's the date it was last fetched.
    def replaced_length(output)
      length = output[:close] - output[:open] + 1
      @lines[output[:close] + 1]&.match?(FETCHED) ? length + 1 : length
    end

    def fetched(response)
      "<!-- raindown:fetched #{Date.today.iso8601} · #{response.status} · #{response.milliseconds} ms -->\n"
    end

    # The fence is longer than any run of backticks in the body, so the body can't close it.
    def output_block(body, language)
      fence = '`' * [3, (body.scan(/`+/).map(&:length).max || 0) + 1].max

      ["#{fence}#{language}\n", *"#{body.chomp}\n".lines, "#{fence}\n"]
    end
  end
end
