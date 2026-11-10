# frozen_string_literal: true

require 'open3'

require_relative 'bare_directives'
require_relative 'document'
require_relative 'front_matter'
require_relative 'nodes'
require_relative 'pages/pages'
require_relative 'utils'

module Raindown
  # A file with "skeleton: true" in its front matter keeps its directives in git, but not what they write, so dashboards
  # don't fill its history and sensitive reports stay out of it. It's a git clean filter: the file on disk keeps its
  # output, and what's committed doesn't, which a clone writes again when it's rendered. The filter's required, so when
  # a file can't be stripped, git stops rather than commit its output.
  module Skeleton
    FILTER = 'raindown'
    SKELETON = /^skeleton:[ \t]*true[ \t]*$/

    module_function

    # Returns true when the arguments were "raindown skeleton", with --check or a file or neither.
    def run_command(argv)
      return false unless argv.first == 'skeleton' && argv.size <= 2

      run(argv[1])
      true
    end

    # "raindown skeleton" sets the repo up, --check is for CI, and with a file it's git's filter.
    def run(argument)
      root, = Open3.capture2('git', 'rev-parse', '--show-toplevel')
      abort('raindown skeleton needs a git repo') if root.strip.empty?
      return install(root.strip) unless argument
      return check(root.strip) if argument == '--check'

      filter(argument)
    end

    # From stdin to stdout, which it has to itself, so what nodes print goes to stderr, like the server's answers.
    def filter(path)
      output = $stdout.dup
      $stdout.reopen($stderr)
      output.write(strip($stdin.read, path:))
    end

    def check(root)
      files = staged_output(root)
      return if files.empty?

      warn('Output is staged in these skeleton files. Run "raindown skeleton", then "git add --renormalize .":', *files)
      exit 1
    end

    # The Markdown without what its directives wrote, or as it is, to the byte, without "skeleton: true".
    def strip(markdown, path:)
      return markdown unless skeleton?(markdown)

      FrontMatter.parse(markdown) # Raises when it can't be read, as bare directives would be missed.
      Nodes.load(path)
      markdown = markdown.gsub("\r\n", "\n")
      lines = markdown.lines
      outputs(markdown, path).reverse_each { |output| lines.slice!((output.begin - 1)..(output.end - 1)) }
      lines.join
    end

    # Sets the filter up for a repo. Git keeps a filter's command in its own config, so each clone needs this.
    def install(root)
      { clean: "#{FILTER} skeleton %f", smudge: 'cat', required: 'true' }.each do |name, value|
        system('git', 'config', "filter.#{FILTER}.#{name}", value, chdir: root, exception: true)
      end
      add_attributes(File.join(root, '.gitattributes'))
    end

    # The staged files that still have output, like ones added before the filter was set up, or in a clone without it.
    def staged_output(root)
      tracked(root).reject do |path|
        staged = staged_markdown(root, path)
        strip(staged, path: File.join(root, path)) == staged
      end
    end

    # Read from the front matter's text, so a file with front matter that isn't valid YAML, or isn't UTF-8, can still be
    # committed when it isn't a skeleton.
    def skeleton?(markdown)
      markdown.scrub.match(FrontMatter::PATTERN)&.[](1)&.match?(SKELETON) || false
    end

    def outputs(markdown, path)
      bare = BareDirectives.enabled?(path:, content: markdown)
      Document.new(markdown:, bare:).directives.select(&:writes).filter_map(&:output)
    end

    def add_attributes(path)
      existing = File.exist?(path) ? File.read(path) : ''
      missing = Pages::EXTENSIONS.map { "*.#{it} filter=#{FILTER}" }.reject { existing.include?(it) }
      return if missing.empty?

      existing += "\n" unless existing.empty? || existing.end_with?("\n")
      File.write(path, "#{existing}#{missing.join("\n")}\n")
    end

    def tracked(root)
      output, = Open3.capture2('git', 'ls-files', '-z', chdir: root)
      output.split("\0").select { Pages::EXTENSIONS.include?(File.extname(it).delete_prefix('.').downcase) }
    end

    def staged_markdown(root, path)
      output, = Open3.capture2('git', 'show', ":#{path}", chdir: root)
      output.force_encoding(Encoding::UTF_8)
    end
  end
end
