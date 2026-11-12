# frozen_string_literal: true

require_relative '../actions'
require_relative '../bare_directives'
require_relative '../chart/chart'
require_relative '../document'
require_relative '../front_matter'
require_relative '../node_blocks'
require_relative '../nodes'
require_relative '../pages/pages'
require_relative '../projects'
require_relative '../rasters'
require_relative '../workers/workers'
require_relative '../stat'
require_relative 'card'
require_relative 'endpoint'
require_relative '../code_blocks'
require_relative '../endpoint/curl'
require_relative '../endpoint/endpoint_variables'

module Raindown
  # What a UI, like the terminal UI or the app, asks of a project, answered in the project's Worker with its own nodes loaded,
  # so two projects' nodes of the same name stay apart. Answers are plain data, which a Worker sends back through a pipe.
  class Project
    Outline = Data.define(:lines, :headings, :directives)

    attr_reader :root

    # Workers for the projects in the folder, each answering as a Project, which allows bare directives in any file,
    # and runs endpoints with no response as it writes back, when asked, like with --bare and -x.
    def self.workers(root:, bare: false, execute: false, **)
      Workers.new(root:, **) { new(root: it, bare:, execute:) }
    end

    # The projects inside this one have workers of their own, so their files are left out.
    def initialize(root:, bare: false, execute: false)
      @root = root
      @bare = bare
      @execute = execute
      @load_errors = []
      @file_errors = []
      Nodes.load(File.join(root, Nodes::FOLDER))
    rescue StandardError, ScriptError => e
      @load_errors << "#{File.basename(root)}/#{Nodes::FOLDER}: #{e.message}"
    end

    # A file's lines, headings and directives.
    def outline(path)
      document = document(path)
      Outline.new(lines: File.readlines(path, chomp: true), headings: document.headings, directives: document.directives)
    end

    # Every chart and stat in the project's files, or any node that draws a card, drawn from its data, and the files
    # that couldn't be read.
    # The charts are found again when asked, and otherwise drawn again, so they follow changes to their data.
    def charts(find: false)
      if find || @charts.nil?
        @file_errors = []
        @charts = Projects.files(root).flat_map { |path| charts_in(path) }
      end

      { cards: drawn, errors: @load_errors + @file_errors }
    end

    # Every endpoint in the project's files that writes its response back, so it can run, by its request, leaving out
    # the ones whose snippet can't be read.
    def endpoints
      Projects.files(root).flat_map do |path|
        document = document(path)
        # Most files have no endpoint, so they aren't parsed for one.
        next [] unless document.markdown.include?('endpoint')

        runnable = document.directives.select { it.endpoint? && it.writes }
        runnable.filter_map { |directive| endpoint(path, document.markdown.lines, directive) }
      rescue StandardError
        []
      end
    end

    # The pixels of the node on a line of a file that rasterizes, like weather:, and the characters of its lines to dim,
    # as { raster:, quiet: }, with its options, like width: and height:.
    def rasterize(path, line, **options)
      Rasters.rasterize(path:, line:, **options)
    end

    def write_back(path)
      Actions.write_back(path, bare: @bare, execute: @execute)
    end

    # Runs the endpoint on the line, replacing its response.
    def execute(path, line)
      directive = Document.read(path, bare: @bare).directives.find { it.line == line && it.endpoint? }
      raise Actions::NotAnEndpoint, "There's no endpoint on line #{line}" unless directive

      Actions.execute(path, directive)
    end

    private

    def endpoint(path, lines, directive)
      snippet = CodeBlocks.endpoint(lines, directive.line).first&.dig(:body)
      variables = EndpointVariables.new(path:, content: lines.join)
      request = Curl.request(snippet.to_s, variables)
      Endpoint.new(project: root, path:, line: directive.line, method: request.method, url: variables.redact(request.url)) if request
    end

    def charts_in(path)
      document = document(path)
      lines = document.markdown.lines
      # Its headings are only parsed when it has a chart, as most files don't.
      NodeBlocks.find(lines, front_matter: FrontMatter.parse(document.markdown).first, bare: document.bare)
                .select { it[:node].respond_to?(:card_lines) }
                .map { |block| chart(block, path:, lines:, headings: document.headings) }
    rescue StandardError => e
      @file_errors << "#{path.delete_prefix(File.join(root, ''))}: #{e.message}"
      []
    end

    # The file's Document, read and parsed again only once the file's changed, so its endpoints, charts and outline
    # share it, and finding them again only parses the files that changed.
    def document(path)
      stat = File.stat(path)
      changed = [stat.mtime, stat.size]
      cached_at, document = (@documents ||= {})[path]
      return document if cached_at == changed

      Document.read(path, bare: @bare).tap { @documents[path] = [changed, it] }
    end

    def drawn
      pages = {}
      @charts.map do |chart|
        lines = lines(chart, pages[File.dirname(chart[:path])] ||= Pages.for(chart[:path]))
        Card.new(project: root, chart: lines, **chart.except(:node))
      end
    end

    def chart(block, path:, lines:, headings:)
      line = block[:open] + 1
      directive = Directives.text(lines[block[:open]])

      { path:, line:, heading: headings.select { it.line < line }.last&.text, directive:, node: block[:node] }
    end

    # Draws the chart or stat as its Markdown would be written back, with the files its project lists.
    def lines(chart, metadata)
      chart[:node].card_lines(metadata:)
    rescue StandardError => e
      ["Can't chart: #{e.message}"]
    end
  end
end
