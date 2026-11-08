# frozen_string_literal: true

require 'json'
require_relative '../version'
require_relative 'editing'
require_relative 'projects'
require_relative 'workers/workers'

module Raindown
  # "raindown server" keeps Raindown loaded for editors, like the Obsidian plugin and the VS Code extension, so a render
  # doesn't start Ruby again. Once it's ready, it says so, then answers a JSON request a line, in order:
  #   {"ready": true, "version": "0.10.0"}
  #   {"id": 1, "path": "/notes/a.md", "markdown": "<!-- toc: -->", "rewrite": true}
  #   {"id": 1, "output": "<!-- toc: -->\n- ...", "warnings": []}
  # Rewriting answers like --stdin --rewrite, with "execute" like -x, and otherwise it's HTML, like --stdin. An error's
  # answered as {"id": 1, "error": "/notes/a.md: ..."}, like the CLI writes it.
  # Each project renders in a worker of its own, which starts again when its .raindown folder changes, so its nodes,
  # config and schemas are never stale. Without fork, as on Windows, node changes need the server started again.
  class Server
    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
      @workers = Workers.new(root: Dir.pwd) { Editing }
      @stamps = {}
    end

    def start
      write(ready: true, version: VERSION)
      @input.each_line { |line| write(answer(line)) }
    ensure
      @workers.stop
    end

    private

    # Any error is the answer, as an editor's only got its server, and one note can't be allowed to stop it.
    def answer(line)
      request = JSON.parse(line)
      { id: request['id'], **edit(request) }
    rescue Workers::Worker::Error => e
      { id: request['id'], error: "#{request['path']}: #{e.message}" }
    rescue StandardError => e
      { id: (request['id'] if request.is_a?(Hash)), error: e.message.to_s }
    end

    def edit(request)
      path = File.expand_path(request.fetch('path'))
      options = { path:, bare: request['bare'] == true }
      worker = worker_for(path)
      return worker.call(:rewrite_markdown, request.fetch('markdown'), **options, execute: request['execute'] == true) if request['rewrite']

      { output: worker.call(:render_markdown, request.fetch('markdown'), **options) }
    end

    # The project's worker, started again first when a file in its .raindown folder was added, changed or removed.
    def worker_for(path)
      project = Projects.root(path) || @workers.root
      @workers.restart(project) if nodes_changed?(project)
      @workers[project]
    end

    def nodes_changed?(project)
      stamp = Dir.glob(File.join(project, Nodes::FOLDER, '**', '*')).to_h { [it, File.lstat(it).mtime] }
      changed = @stamps.key?(project) && @stamps[project] != stamp
      @stamps[project] = stamp
      changed
    end

    def write(message)
      @output.puts(JSON.generate(message))
      @output.flush
    end
  end
end
