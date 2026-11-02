# frozen_string_literal: true

require 'date'
require_relative '../bare_directives'
require_relative '../code_blocks'
require_relative 'curl'
require_relative 'endpoint_variables'

module Raindown
  # Runs the curl block under an endpoint directive in a comment, or a bare one, and writes the response in the code
  # block below it,
  # followed by the date it was fetched.
  # Only runs when that block is missing or empty, and the directive has :x/:execute or --execute is passed.
  # Or with only: and a directive's line index, runs just that endpoint, replacing any response it has.
  #   <!-- endpoint: :x -->
  #   ```sh
  #   curl https://api.example.com
  #   ```
  #   ```json
  #   { "id": 1 }
  #   ```
  #   <!-- raindown:fetched 2026-10-14 -->
  #   <!-- :endpoint -->
  # Its snippet's {placeholders} are filled from EndpointVariables, and with as: login, later snippets can use its
  # response, like {login.token}.
  # One in Antlers' delimiters, <{ endpoint: }>, only renders, so it's never run.
  class EndpointRunner
    # An endpoint's directive in Antlers' delimiters, which only renders, or in a comment, which writes its response back,
    # and the end tag of either.
    DIRECTIVE = /\A {0,3}<\{\s*endpoint:(.*?)\}>[ \t]*$/
    COMMENT = /\A {0,3}<!--\s*endpoint:(.*?)-->[ \t]*$/
    END_TAG = /\A {0,3}(?:<\{\s*:endpoint\s*\}>|<!--\s*:endpoint\s*-->)[ \t]*$/
    EXECUTE_ARGS = %w[:x :execute].freeze
    # The date a response was fetched, on the line after it.
    FETCHED = /\A {0,3}<!-- raindown:fetched [^\n]*? -->[ \t]*$/

    def self.rewrite(content:, path: nil, bare: false, execute: false, **)
      new(content:, path:, bare: BareDirectives.enabled?(path:, content:, bare:), execute:).rewrite
    end

    def initialize(content:, path: nil, bare: false, execute: false, only: nil)
      @lines = content.lines
      @variables = EndpointVariables.new(path:, content:)
      @bare = bare
      @execute = execute
      @only = only
    end

    def rewrite
      index = 0

      while index < @lines.length
        if (block = CodeBlocks.at(@lines, index))
          index = block[:close]
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
      args&.split
    end

    # Returns the index of the last line it handled.
    def fill(index, args, directive:)
      curl, output = CodeBlocks.endpoint(@lines, index)
      return index - 1 unless curl&.dig(:body)&.lstrip&.start_with?('curl')
      return write_output(curl:, output:, name: response_name(args)) if run?(args, output, directive)

      @variables.remember(response_name(args), output[:body]) if output
      curl[:close]
    end

    # The name that as: gives the endpoint, for later snippets to use its response.
    def response_name(args)
      index = args.index('as:')
      args[index + 1] if index
    end

    def run?(args, output, directive)
      return directive == @only if @only

      (output.nil? || output[:body].strip.empty?) && execute?(args)
    end

    def execute?(args)
      @execute || args.intersect?(EXECUTE_ARGS)
    end

    # Replaces the output block and the date it was fetched, or with no block, replaces nothing just after the curl block.
    def write_output(curl:, output:, name:)
      body, language = Curl.run(curl[:body], @variables)
      @variables.remember(name, body)
      block = [*output_block(body, language), fetched]
      block.unshift("\n") unless output
      start = output ? output[:open] : curl[:close] + 1

      @lines[start, output ? replaced_length(output) : 0] = block
      start + block.length - 1
    rescue Curl::Error => e
      # The one endpoint that was asked for fails for the caller to show, like in the terminal UI.
      raise if @only

      warn "Endpoint failed: #{e.message}"
      curl[:close]
    end

    # The output block, and the line after it when that's the date it was last fetched.
    def replaced_length(output)
      length = output[:close] - output[:open] + 1
      @lines[output[:close] + 1]&.match?(FETCHED) ? length + 1 : length
    end

    def fetched
      "<!-- raindown:fetched #{Date.today.iso8601} -->\n"
    end

    # The fence is longer than any run of backticks in the body, so the body can't close it.
    def output_block(body, language)
      fence = '`' * [3, (body.scan(/`+/).map(&:length).max || 0) + 1].max

      ["#{fence}#{language}\n", *"#{body.chomp}\n".lines, "#{fence}\n"]
    end
  end
end
