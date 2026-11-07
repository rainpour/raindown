# frozen_string_literal: true

require 'find'
require_relative 'gitignore'
require_relative 'nodes'
require_relative 'pages'

module Raindown
  # Raindown projects are folders with a .raindown folder, and their Markdown files are watched for changes.
  # A file belongs to the project of the nearest .raindown folder above it, so projects can sit inside each other.
  module Projects
    # Folders of dependencies, builds and tooling, which aren't searched for projects or watched, nor are hidden folders.
    IGNORED = %w[node_modules vendor tmp pkg build dist coverage].freeze
    # Ruby nodes and JavaScript Components.
    NODE_EXTENSIONS = ['.rb', '.rbx', *JSNodes::EXTENSIONS].freeze
    VAULT_FOLDER = '.obsidian'

    module_function

    # The roots of the projects in a directory: the project the directory is in, if any, and every project below it.
    def roots(directory)
      directory = File.expand_path(directory)
      [root(directory), *project_folders(directory)].compact.uniq
    end

    # The folders below a directory with a .raindown folder. Only folders are walked, leaving out ignored, linked and
    # gitignored ones, so it stays quick in a big folder like ~/dev, and vaults, which their editor writes back to.
    def project_folders(directory, gitignore = Gitignore.new(directory))
      Dir.glob('*/', base: directory).flat_map do |folder|
        path = File.join(directory, folder.chomp('/'))
        next [] if ignored?(folder.chomp('/')) || File.symlink?(path) || gitignore.ignores?(path) || vault?(path)

        inside = project_folders(path, Gitignore.new(path, gitignore))
        next inside unless project?(path)

        [path, *inside]
      end
    end

    # The root of the project a file or directory is in, or nil when it isn't in one.
    def root(path)
      path = File.expand_path(path)
      folder = Nodes.find_folder(File.directory?(path) ? path : File.dirname(path))
      folder && File.dirname(folder)
    end

    # The folder a file's paths are relative to: the nearest with a .raindown folder or that's a vault, or nil without one.
    # A vault doesn't need a .raindown folder, as Obsidian's links and a table's path are from its top.
    def content_root(path)
      folder = File.dirname(File.expand_path(path))
      until project?(folder) || vault?(folder)
        return if folder == File.dirname(folder)

        folder = File.dirname(folder)
      end
      folder
    end

    # The project's Markdown files, sorted, leaving out ignored folders. The projects inside it are left out too,
    # since they have nodes of their own, and vaults, which their editor writes back to.
    def files(root)
      files = []

      Find.find(root) do |path|
        if File.directory?(path)
          Find.prune if path != root && (ignored?(File.basename(path)) || project?(path) || vault?(path))
        elsif markdown?(path, root:)
          files << path
        end
      end

      files.sort
    end

    # Whether a file is Markdown in its project, rather than in an ignored or hidden folder like node_modules.
    def markdown?(path, root:)
      return false unless Pages::EXTENSIONS.include?(File.extname(path).delete_prefix('.').downcase)

      folders = File.dirname(File.expand_path(path)).delete_prefix(root).split('/').reject(&:empty?)
      folders.none? { |folder| ignored?(folder) }
    end

    # Whether a file is one of a project's own nodes, which load when its watcher starts.
    def node?(path, root:)
      File.expand_path(path).start_with?(File.join(root, Nodes::FOLDER, '')) &&
        (NODE_EXTENSIONS.include?(File.extname(path)) || MarkdownNodes.file?(path))
    end

    # The roots that aren't inside another of them, as a project's code includes the projects inside it.
    def outer_roots(roots)
      roots.reject { |root| roots.any? { root != it && root.start_with?(File.join(it, '')) } }
    end

    def project?(folder)
      File.directory?(File.join(folder, Nodes::FOLDER))
    end

    # Whether a folder's an Obsidian vault, whose plugin runs a Raindown of its own, so one watching a folder above it
    # leaves it alone, while one pointed at the vault itself doesn't.
    def vault?(folder)
      File.directory?(File.join(folder, VAULT_FOLDER))
    end

    # Whether a path's in a vault below the directory, which isn't the directory itself.
    def vault_below?(path, directory)
      tops = [File.expand_path(directory), File.realpath(directory)]
      folders = []
      folder = File.dirname(File.expand_path(path))
      until tops.include?(folder) || folder == File.dirname(folder)
        folders << folder
        folder = File.dirname(folder)
      end

      tops.include?(folder) && folders.any? { vault?(it) }
    end

    def ignored?(folder)
      folder.start_with?('.') || IGNORED.include?(folder)
    end
  end
end
