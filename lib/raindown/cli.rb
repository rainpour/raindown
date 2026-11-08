# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'
require 'trees'
require_relative '../raindown'
require_relative '../version'
require_relative 'blueprints'
require_relative 'editing'
require_relative 'rewriter'
require_relative 'server'
require_relative 'skeleton'
require_relative 'watcher/file_watcher'
require_relative 'watcher/supervisor'

module Raindown
  module CLI
    extend Trees

    USAGE = <<~TEXT
      Usage: raindown [PATH] [options]
             raindown watch [PATH] [options]
             raindown FILE --html [OUTPUT] [options]
             raindown init [DIRECTORY]

      Opens PATH (default: current directory) in the terminal UI: browse a project's files and outlines, fold
      directives, run endpoints, open the editor at a line and see a dashboard of the project's charts. While it's open,
      it watches the folder and writes back to its Markdown files as they're saved, like their tables of contents.

      Commands:
        watch [PATH]        Watch PATH without the terminal UI, writing back to its Markdown files as they're saved.
                            PATH is a file, or a directory (default: current directory) whose projects with a
                            .raindown folder are watched
        init [DIRECTORY]    Create a .raindown folder for the project's config and nodes (default: current directory)
        skeleton            Set this repo up to commit directives without what they write, in files with "skeleton: true"
        skeleton --check    Exit with 1, naming any such file with output staged, for CI
        server              Keep Raindown loaded for an editor, answering a JSON request a line on stdin with its HTML,
                            or its Markdown as it would be written back, like --stdin and --stdin --rewrite
        blueprints            Save the blueprints in Claude Code's last reply to .raindown/data/blueprints.md, for the terminal
                            UI's Blueprints page, as a Stop hook that's given the hook's JSON

      Options:
        --html [OUTPUT]     Render FILE to HTML once, writing to OUTPUT, or to stdout without one or with -, then exit with 1
                            if its endpoint responses fail their status: or schema: checks
        --stdin             Render Markdown from stdin to HTML once, without formatting FILE, which only needs
                            its extension (to allow bare directives) and can be unsaved. Add --html OUTPUT to write a file
        --rewrite           With --stdin, print its Markdown as it would be written back to FILE, without writing
                            FILE, for editors like Obsidian. Add -x to run its endpoints
        --bare              Allow bare directives like :toc in Markdown files
        -x, --execute       Run endpoint curl snippets that have no output yet, as files are written back
        --env NAME          Fill endpoint snippets from the NAME environment in .raindown/environments.yml and
                            environments.local.yml
        -h, --help          Show this message
        -v, --version       Show the version

      Set RAINDOWN_DEBUG=1 to show where an error happened.
    TEXT

    # The files "raindown init" puts in a project's .raindown folder, like "rain new" clones raindeer-template.
    TEMPLATE_URL = 'https://github.com/rainpour/raindown-init'

    # A path opens the terminal UI, or after "watch" it's watched, and with --html or --stdin it's rendered. The flags
    # are keyword arguments, in any order, like -x for x:, and --html is the OUTPUT when it's given one.
    line(':path') do |path, html: nil, stdin: false, rewrite: false, bare: false, execute: false, x: false, env: nil| # rubocop:disable Metrics/ParameterLists -- each keyword is a flag
      execute do
        ENV['RAINDOWN_ENV'] = env if env
        next rewrite_stdin(path, bare:, execute: execute || x) if stdin && rewrite

        open_path(path, html:, stdin:, bare:, execute: execute || x)
      end
    end

    line('watch :path') do |path, bare: false, execute: false, x: false, env: nil|
      execute do
        ENV['RAINDOWN_ENV'] = env if env
        watch(path, bare:, execute: execute || x)
      end
    end

    def self.run(argv)
      # Markdown is UTF-8 whatever the locale, as an app opened from the Dock, like Obsidian, starts Raindown without one.
      Encoding.default_external = Encoding::UTF_8
      return if command(argv) || Skeleton.run_command(argv)

      argv = with_path(argv)
      super || abort("Unknown arguments: #{argv.join(' ')}\n\n#{USAGE}")
    rescue StandardError => e
      report(e, path: argv.first)
    end

    # Without a path, like "raindown", "raindown -x" or "raindown watch", it's the current directory.
    def self.with_path(argv)
      return ['watch', '.', *argv.drop(1)] if argv.first == 'watch' && (argv.size == 1 || argv[1].start_with?('-'))
      return ['.', *argv] if argv.empty? || argv.first.start_with?('-')

      argv
    end

    # The :path line would match help, version and init as the file, so they're checked first.
    # Returns true when argv was one of them.
    def self.command(argv)
      abort(USAGE) if argv.intersect?(%w[-h --help])

      if argv.intersect?(%w[-v --version]) then puts(VERSION)
      elsif argv.first == 'init' && argv.size <= 2 then init(argv[1])
      elsif argv == ['blueprints'] then Blueprints.save(JSON.parse($stdin.read))
      elsif argv == ['server'] then serve
      else return false
      end

      true
    end

    # Shows an error in a file as one line, rather than a backtrace, unless RAINDOWN_DEBUG is set.
    def self.report(error, path:)
      raise error if ENV['RAINDOWN_DEBUG']

      abort("raindown: #{path}: #{error.message}")
    end

    # Clones raindown-init into the .raindown folder that marks a project's root and holds its config.yml and nodes,
    # keeping any files already there.
    def self.init(directory = nil)
      folder = File.join(directory || Dir.pwd, Nodes::FOLDER)
      config = File.join(folder, Config::FILE)
      return puts("#{config} already exists") if File.exist?(config)

      Dir.mktmpdir do |clone|
        clone_template(clone)
        FileUtils.mkdir_p(folder)
        (Dir.children(clone) - ['.git']).each do |name|
          FileUtils.cp_r(File.join(clone, name), folder) unless File.exist?(File.join(folder, name))
        end
      end
      puts "Created #{config}"
      puts 'Put your own nodes in the same folder. See https://raindown.dev/docs/components'
    end

    # The terminal UI loads curses, so it's only required when it starts. Without a terminal, the path's watched instead.
    def self.tui(path, bare: false, execute: false)
      abort("File not found: #{path}") unless File.exist?(path)

      require_relative 'tui'
      TUI.start(path, bare:, execute:) || watch(path, bare:, execute:)
    end

    class << self
      private

      def clone_template(directory)
        output, status = Open3.capture2e('git', 'clone', '--quiet', '--depth', '1', TEMPLATE_URL, directory)
        abort("Couldn't clone #{TEMPLATE_URL}:\n#{output}") unless status.success?
      end

      # Endpoints run while formatting, which --stdin skips, so -x can't go with it. --html - prints, like --html.
      def open_path(path, html:, stdin:, bare:, execute:)
        output = html unless [true, '-'].include?(html)
        abort("-x runs endpoints as the file's formatted, which --stdin doesn't do\n\n#{USAGE}") if stdin && execute
        return render_stdin(path, output, bare:) if stdin
        return render(path, output, bare:, execute:) if html

        tui(path, bare:, execute:)
      end

      def render(path, output = nil, bare: false, execute: false)
        ensure_exists(path)
        abort('--html renders a file, not a directory') if File.directory?(path)
        Nodes.load(path)

        metadata = Pages.for(path)
        rewrite = Rewriter.update(path:, bare:, execute:, metadata:)
        warn(*rewrite.problems.map { "raindown: #{path}: #{it}" })
        write(output, Raindown.render_file(path:, bare:, metadata:))
        check_endpoints(rewrite.failures)
      end

      # Endpoint responses that fail their checks, like status: 200, are listed, and fail the command, for CI.
      def check_endpoints(failures)
        return if failures.empty?

        warn(*failures.map { "Endpoint check failed: #{it}" })
        exit 1
      end

      # The Markdown from stdin written back as it would be to the file, and its failed endpoint checks, for an editor
      # to apply to what it's editing.
      def rewrite_stdin(path, bare:, execute:)
        rewritten = Editing.rewrite_markdown($stdin.read, path:, bare:, execute:)
        $stdout.write(rewritten[:output])
        warn(*rewritten[:warnings])
      end

      def render_stdin(path, output = nil, bare: false, **)
        write(output, Editing.render_markdown($stdin.read, path:, bare:))
      end

      # Watching only writes back to the files, while --html and --stdin render HTML.
      def watch(path, bare: false, execute: false)
        ensure_exists(path)
        return Watcher::Supervisor.new(directory: path, bare:, execute:).start if File.directory?(path)

        Nodes.load(path)
        Watcher::FileWatcher.new(path:, bare:, execute:).start
      end

      # The answers have stdout to themselves, so what nodes print goes to stderr.
      def serve
        output = $stdout.dup
        $stdout.reopen($stderr)
        Server.new(output:).start
      end

      def write(output, html)
        output ? File.write(output, html) : puts(html)
      end

      def ensure_exists(path)
        abort("File not found: #{path}") unless File.exist?(path)
      end
    end
  end
end
