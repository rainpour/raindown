# frozen_string_literal: true

module Raindown
  # The folders .gitignore files leave out, like a Drupal site's web/core, so finding the projects in a folder of
  # them, like ~/dev, skips them. Only lines naming a folder are read, like /vendor/, node_modules or
  # /web/modules/contrib/*, as a wildcard could leave out a project, and a ! takes a folder back out.
  class Gitignore
    WILDCARD = /[*?\[]/

    # The rules for the folders inside a folder: its .gitignore's and those of the folders above it, up to its
    # repository, as a repository's rules don't reach the repositories inside it.
    def initialize(folder, above = nil)
      above = nil if File.exist?(File.join(folder, '.git'))
      @paths = Set.new(above&.paths)
      @names = Set.new(above&.names)
      file = File.join(folder, '.gitignore')
      File.foreach(file, chomp: true) { read(it.strip, folder) } if File.file?(file)
    end

    def ignores?(path)
      @paths.include?(path) || @names.include?(File.basename(path))
    end

    protected

    attr_reader :paths, :names

    private

    # A folder with a slash, like /vendor or web/files, is from the .gitignore's folder, and one without, like
    # node_modules, is any folder of that name below it.
    def read(line, folder)
      pattern = line.delete_suffix('/*').delete_suffix('/')
      negated = pattern.delete_prefix!('!')
      return if pattern.empty? || pattern.start_with?('#') || pattern.match?(WILDCARD)

      if pattern.include?('/')
        update(@paths, File.join(folder, pattern.delete_prefix('/')), negated:)
      else
        update(@names, pattern, negated:)
      end
    end

    def update(rules, rule, negated:)
      return rules.delete(rule) if negated

      rules.add(rule)
    end
  end
end
