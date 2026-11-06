# frozen_string_literal: true

require_relative 'front_matter'
require_relative 'page'
require_relative 'utils'

module Raindown
  # The metadata of a project's Markdown files, which list: lists by tag.
  # Ported from Raindeer's Rain::Pages, and takes the same Dirload metadata.
  #
  # Each file is tagged with its front matter, like "tags: [ruby, docs]" or "date: 2099", and by its path,
  # where underscored folders are metadata: docs/_basics/_1-getting-started.md has
  #   folder: basics, order: 1, path: docs/_basics/_1-getting-started.md
  # Folder tags can share a folder name with "&", like docs/_1&_basics/getting-started.md.
  # An app can add its own metadata by subclassing and overriding implicit_metadata, like Raindeer's URL paths.
  # Each file's front matter is only read once something lists the files. The listing and the front matter are kept for
  # as long as the process runs, like "raindown server", until they change.
  class Pages
    EXTENSIONS = %w[md rd markdown raindown].freeze
    SEGMENTS = Regexp.union(['/', '&', '-'])

    class << self
      # Each file's front matter, by its path, with the time it was modified when it was read.
      def front_matters
        @front_matters ||= {}
      end

      # The Markdown files under a project's root, the folder with its .raindown folder or else the file's folder.
      def for(path)
        file_directory = File.dirname(File.expand_path(path))
        load(root: Nodes.find_folder(file_directory)&.then { File.dirname(it) } || file_directory)
      end

      # Lists the files under the root, without loading them, for Dirload.
      def load(root:)
        require 'dirload'
        file_types = file_paths(root).group_by { Dirload.extension(file_path: it) }
        new(metadata: Dirload::Metadata.new(loaded_paths: {}, missed_paths: [], file_types:), root:)
      end

      # The files under the root, outside hidden folders, like Dirload lists them. They're listed again once a folder
      # among them has changed, which adding, removing or renaming a file or folder in it does.
      def file_paths(root)
        listing = listings[root]
        return listing[:file_paths] if listing&.dig(:folders)&.all? { |folder, modified| modified_at(folder) == modified }

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

    attr_reader :root

    # Render options, like highlight_code: false, are for rendering each listed file's content.
    # Eager reads every file's front matter straight away, for an app like Raindeer that needs all of it from the start.
    def initialize(root:, metadata:, render_options: {}, eager: false)
      @root = root
      @render_options = render_options
      @file_paths = filtered_paths(metadata:)
      load_metadata if eager
    end

    # The files with any of the tags, like list(folder: 'basics') or list(tags: 'ruby'), sorted by order.
    # Without tags, every file.
    def list(**tags)
      file_paths = tags.empty? ? @file_paths : tagged(**tags)
      file_paths.sort_by { |file_path| sort_key(file_path) }.map { |file_path| listed_page(file_path) }
    end

    def tagged(**tags)
      tags.flat_map { |type, tag| self.tags.dig(type.to_sym, tag) || [] }.uniq
    end

    private

    # The Markdown files in Dirload's metadata, only those under the root path.
    def filtered_paths(metadata:)
      metadata.file_types.values_at(*EXTENSIONS).flatten.compact.select { it.start_with?("#{@root}/") }
    end

    def metadata
      load_metadata unless @metadata
      @metadata
    end

    def tags
      load_metadata unless @tags
      @tags
    end

    def load_metadata
      @metadata = {}
      @tags = {}
      @file_paths.each { |file_path| process(file_path:) }
    end

    def listed_page(file_path)
      Page.new(file_path:, metadata: metadata[file_path], render_options: @render_options)
    end

    def process(file_path:)
      metadata = @metadata[file_path] = implicit_metadata(file_path:).merge(front_matter(file_path))
      metadata.each { |type, tag| Array(tag).each { |item| tag(type:, tag: item, file_path:) } }
    end

    # The file's front matter, read again only when the file's changed since it was last read.
    def front_matter(file_path)
      modified = File.mtime(file_path)
      modified_then, front_matter = self.class.front_matters[file_path]
      return front_matter if modified_then == modified

      FrontMatter.parse(Utils.read_markdown(file_path)).first.tap { self.class.front_matters[file_path] = [modified, it] }
    end

    # The path is relative to the root, like docs/_basics/_1-getting-started.md.
    # A subclass can add or replace metadata here, like Raindeer's Rain::Pages replacing the path with a URL path.
    def implicit_metadata(file_path:)
      { folder: folders(file_path:).last, order: order(file_path:), path: relative(file_path).delete_prefix('/') }.compact
    end

    def tag(type:, tag:, file_path:)
      @tags[type] ||= {}
      @tags[type][tag] ||= []
      @tags[type][tag] << file_path
    end

    # The underscored folders, like basics in docs/_basics/.
    def folders(file_path:)
      underscored(File.dirname(relative(file_path))).reject { number?(it) }
    end

    # The last underscored number in the path, like 1 in docs/_basics/_1-getting-started.md.
    def order(file_path:)
      underscored(relative(file_path)).select { number?(it) }.last&.then { Integer(it, exception: false) || Float(it) }
    end

    def underscored(path)
      path.split(SEGMENTS).select { it.start_with?('_') }.map { it.delete_prefix('_') }
    end

    def relative(file_path)
      File.expand_path(file_path).delete_prefix(File.expand_path(@root))
    end

    def number?(string)
      !Float(string, exception: false).nil?
    end

    # Files with an order come first, by order, then the rest by path.
    def sort_key(file_path)
      order = metadata[file_path][:order]
      [order.is_a?(Numeric) ? 0 : 1, order.is_a?(Numeric) ? order : 0, metadata[file_path][:path].to_s]
    end
  end
end
