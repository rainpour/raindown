# frozen_string_literal: true

require_relative 'nodes'

module Raindown
  # A project's own nodes, from its .raindown folder, as plain data for an app to list: each one's name, whether it's
  # Ruby, JavaScript or Markdown, its file, from the project's root, and whether it rasterizes. They're the nodes loaded
  # in the process, so a project's Worker lists its own.
  module ProjectNodes
    module_function

    def of(root)
      folder = File.join(root, Nodes::FOLDER)
      return [] unless File.directory?(folder)

      Nodes.load(folder)
      (ruby(folder) + javascript(folder) + markdown(folder)).map { listed(root, **it) }.sort_by { it[:name] }
    end

    # By where they're defined, so nothing else is loaded to find them.
    def ruby(folder)
      Object.constants.filter_map do |name|
        file, = Object.const_source_location(name)
        next unless file&.start_with?("#{folder}/")

        klass = Object.const_get(name)
        { name: name.to_s, kind: 'ruby', file:, node: klass } if Nodes.node?(klass)
      end
    end

    def javascript(folder)
      JSNodes.node_classes.filter_map do |name, node|
        { name:, kind: 'javascript', file: node.file, node: } if node.file && File.dirname(node.file) == folder
      end
    end

    def markdown(folder)
      MarkdownNodes.node_classes.filter_map do |name, node|
        { name:, kind: 'markdown', file: node.path, node: } if File.dirname(node.path) == folder
      end
    end

    def listed(root, name:, kind:, file:, node:)
      { name:, kind:, file: file.delete_prefix("#{root}/"), rasterizes: node.method_defined?(:rasterize) }
    end
  end
end
