# frozen_string_literal: true

module Raindown
  # A project's nodes in Ruby, in its .raindown folder, loaded with Dirload, which define LowNodes as constants.
  module RubyNodes
    module_function

    # Dirload's steps, for the folder's Ruby files, as dirload(folder) takes them, a file that fails one being left out
    # of the next, and why each failed.
    def load(folder)
      require 'lownode'
      require 'dirload'
      files = Dirload.file_paths(absolute_path: folder).map { [it, Dirload.find_adapter(file_path: it)] }
      errors = {}
      %i[mapload preload evaluate].each do |step|
        files.each do |file, adapter|
          next if adapter.nil? || errors.key?(file)

          adapter.public_send(step, file_path: file)
        rescue StandardError, ScriptError => e
          errors[file] = e.message
        end
      end
      errors.map { |file, message| load_error(folder, file, message) }
    end

    # Why a file couldn't be loaded, by its path from the project, with its line, when the error has it.
    def load_error(folder, file, message)
      listed = file.delete_prefix("#{File.dirname(folder)}/")
      return "#{listed}#{message.delete_prefix(file)}" if message.start_with?("#{file}:")

      "#{listed}: #{message}"
    end

    def node_class(name)
      klass = Object.const_get(name) if name.match?(/\A[A-Z]/) && Object.const_defined?(name)
      klass if Nodes.node?(klass)
    end
  end
end
