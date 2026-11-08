# frozen_string_literal: true

require_relative '../projects'
require_relative 'worker'

module Raindown
  # A Worker for each project in a folder: the folder's own, and every project inside it, each answering with what the
  # block makes from its root, like the terminal UI's Project. A file's requests go to the worker of the project it's in,
  # the nearest one above it, even when it's new, or else the folder's. Workers start when they're first asked something.
  class Workers
    attr_reader :root

    def initialize(root:, fork: Worker.fork?, quiet: true, &answering)
      @root = root
      @fork = fork
      @quiet = quiet
      @answering = answering
      @workers = {}
      @finishing = []
    end

    def for(path) = self[Projects.root(path) || root]

    def [](project)
      @workers[project] ||= Worker.new(root: project, fork: @fork, quiet: @quiet) { @answering.call(project) }
    end

    # The folder's project and those inside it, found when they're first asked for, and again after a restart.
    def roots = @roots ||= Projects.roots(root).sort

    # A worker for each project, as they were found when the workers last started.
    def each(&)
      roots.map { self[it] }.each(&)
    end

    # The workers asked something, by their project's root.
    def started = @workers.dup

    # Finishes the project's worker, which takes the requests it has with the nodes it loaded, so its next request starts
    # a new one, loading its nodes again, and returns whether it had started. Without a project, they all stop, and the
    # projects are found again, like ones added since.
    def restart(project = nil)
      return restart_project(project) if project

      stop
      @roots = nil
    end

    # Stops the workers, and those still finishing, so the next requests start them again.
    def stop
      (@workers.values + @finishing).each(&:stop)
      @workers.clear
      @finishing.clear
    end

    private

    def restart_project(project)
      worker = @workers.delete(project)
      return false unless worker

      @finishing.select!(&:alive?)
      @finishing << worker.tap(&:finish)
      true
    end
  end
end
