# frozen_string_literal: true

require 'shellwords'

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'endpoint/endpoint_runner'
require_relative 'rewriter'

module Raindown
  # What a tool can do to a file from its Document, like the terminal UI, without knowing how it's drawn.
  # Each returns true when the file changed, and raises when it can't, for the tool to show.
  module Actions
    class NotAnEndpoint < StandardError; end
    class FailedCheck < StandardError; end

    # Editors that open a file at a line with "path:line" rather than "+line path".
    PATH_LINE_EDITORS = %w[hx helix subl zed].freeze
    # Editors that need -g before "path:line", and --wait so the tool waits for the file to close.
    GOTO_EDITORS = %w[code codium cursor windsurf].freeze

    module_function

    # Writes back the whole file, like saving it while it's watched, with bare directives allowed, and endpoints with no
    # response run, when asked, like with --bare and -x.
    def write_back(path, bare: false, execute: false)
      Rewriter.update(path:, bare:, execute:, metadata: Pages.for(path)).changed?
    end

    # Runs one endpoint's request and writes its response, replacing any response it had, then raises when the response
    # fails its checks, like status: 200.
    def execute(path, directive)
      check_runnable(directive)
      content = Utils.read_markdown(path)
      runner = EndpointRunner.new(content:, path:, bare: BareDirectives.enabled?(path:, content:), only: directive.line - 1)
      rewritten = runner.rewrite
      File.write(path, rewritten) unless rewritten == content
      raise FailedCheck, runner.failures.join("\n") if runner.failures.any?

      rewritten != content
    end

    def check_runnable(directive)
      raise NotAnEndpoint, "#{directive.name} on line #{directive.line} isn't an endpoint" unless directive.endpoint?
      raise NotAnEndpoint, "The endpoint on line #{directive.line} only renders, so put it in comments to run it" unless directive.writes
    end

    # The command that opens the file at a line in the person's editor, like ["vim", "+12", "notes.md"].
    def edit_command(path, line:, editor: ENV['VISUAL'] || ENV['EDITOR'] || 'vi')
      command = Shellwords.split(editor)
      name = File.basename(command.first)

      if GOTO_EDITORS.include?(name)
        [*command, *('--wait' unless command.include?('--wait')), '-g', "#{path}:#{line}"]
      elsif PATH_LINE_EDITORS.include?(name)
        [*command, "#{path}:#{line}"]
      else
        [*command, "+#{line}", path]
      end
    end
  end
end
