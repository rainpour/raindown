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
  # block below it, after a comment of its status, how long it took and the date it was fetched.
  # Only runs when that block is missing or empty, and --execute is passed, so a file can't run requests by itself.
  # Or with only: and a directive's line index, runs just that endpoint, replacing any response it has.
  #   <!-- endpoint: -->
  #   ```sh
  #   curl https://api.example.com
  #   ```
  #   <!-- response 200 · 142 ms · 2026-10-14 -->
  #   ```json
  #   { "id": 1 }
  #   ```
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
    RESPONSE_STATUS = /<!-- response (\d{3}) /

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
      curl, output = CodeBlocks.endpoint(@lines, index, bare: !@lines[directive].match?(COMMENT))
      return index - 1 unless curl&.dig(:body)&.lstrip&.start_with?('curl')
      return write_output(curl:, output:, args:, directive:) if run?(output, directive)
      return curl[:close] unless output

      @variables.remember(args.name, output[:body])
      check(args, directive:, body: output[:body], status: response_status(output))
      curl[:close]
    end

    # The status in the comment above a response, which a comment written by hand may not have.
    def response_status(output)
      @lines[output[:comment]][RESPONSE_STATUS, 1]&.to_i if output[:comment]
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

    # Replaces everything from just after the curl block to the end of the output block, if there is one, like its
    # comment.
    # Secrets that a response echoes are written as their placeholders.
    def write_output(curl:, output:, args:, directive:)
      response = Curl.run(curl[:body], @variables)
      body = @variables.redact(response.body)
      @variables.remember(args.name, body)
      check(args, directive:, body:, status: response.status)
      replace_output(curl:, output:, block: [response_comment(response), *output_block(body, response.language)])
    rescue Curl::Error => e
      message = @variables.redact(e.message)
      # The one endpoint that was asked for fails for the caller to show, like in the terminal UI.
      raise Curl::Error, message if @only

      warn "Endpoint failed: #{message}"
      curl[:close]
    end

    # Returns the index of the block's last line.
    def replace_output(curl:, output:, block:)
      start = curl[:close] + 1
      @lines[start, output ? output[:close] - start + 1 : 0] = block
      start + block.length - 1
    end

    def response_comment(response)
      "<!-- response #{response.status} · #{response.milliseconds} ms · #{Date.today.iso8601} -->\n"
    end

    # The fence is longer than any run of backticks in the body, so the body can't close it.
    def output_block(body, language)
      fence = '`' * [3, (body.scan(/`+/).map(&:length).max || 0) + 1].max

      ["#{fence}#{language}\n", *"#{body.chomp}\n".lines, "#{fence}\n"]
    end
  end
end
