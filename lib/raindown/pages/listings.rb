# frozen_string_literal: true

module Raindown
  # What Pages keeps for as long as the process runs, like "raindown server", until it changes: each root's files, and
  # each file's front matter. An editor that's told of every change to the files, like the Obsidian plugin, which knows
  # its vault's, watches them, so their modified times aren't checked each time they're listed, which in WebAssembly takes
  # as long as listing thousands of them.
  module Listings
    # Each file's front matter, by its path, with the time it was modified when it was read.
    def front_matters
      @front_matters ||= {}
    end

    # Each file's metadata from its path, by its root and path, like order: 1 for docs/_1-setup.md, which only changes
    # with its path.
    def implicit_metadatas
      @implicit_metadatas ||= {}
    end

    # The front matter the editor's already read, by path, is kept rather than read again.
    def watch(front_matters = {})
      @watched = true
      front_matters.each { |path, front_matter| self.front_matters[path] = [:given, front_matter] }
    end

    def watched?
      @watched == true
    end

    # Files or folders added, changed or removed, by path, so their front matter's read again, and each root's listing
    # has the files added and not those removed, rather than listing every file again.
    def changed(paths)
      return if paths.empty?

      pages.clear
      paths.each do |path|
        front_matters.delete(path)
        listings.each do |root, listing|
          next unless path.start_with?("#{root}/")

          listing[:file_paths].reject! { it == path || it.start_with?("#{path}/") }
          listing[:file_paths] << path if File.file?(path) && !path.delete_prefix(root).include?('/.')
        end
      end
    end

    # Each root's Pages, while an editor watching the files says none have changed, so their metadata's worked out once.
    def pages
      @pages ||= {}
    end

    # The files under the root, outside hidden folders, like Dirload lists them. They're listed again once a folder among
    # them has changed, which adding, removing or renaming a file or folder in it does, or the editor watching says so.
    def file_paths(root)
      listing = listings[root]
      return listing[:file_paths] if listing && (watched? || listing[:folders].all? { |folder, at| modified_at(folder) == at })

      folders, file_paths = Dir["#{root}/**/*"].partition { File.directory?(it) }
      listings[root] = { file_paths:, folders: [root, *folders].to_h { [it, modified_at(it)] } }
      file_paths
    end

    def listings
      @listings ||= {}
    end

    def modified_at(path)
      File.mtime(path) if File.exist?(path)
    end
  end
end
