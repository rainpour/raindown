# frozen_string_literal: true

require 'yaml'

module Raindown
  # A project's settings, from config.yml in its .raindown folder:
  #   highlight_code: false    # Code blocks aren't highlighted, so the browser can highlight them instead.
  #   kind: notes              # What the project's for, code or notes, so an app shows what fits it.
  module Config
    FILE = 'config.yml'
    DEFAULTS = { highlight_code: true }.freeze
    KINDS = %w[code notes].freeze

    module_function

    # The settings for the project a file is in, or the defaults outside one.
    def for(path)
      folder = Nodes.find_folder(File.dirname(File.expand_path(path)))
      file = folder && File.join(folder, FILE)
      return DEFAULTS unless file && File.exist?(file)

      DEFAULTS.merge(YAML.safe_load_file(file, symbolize_names: true) || {})
    end

    # The project's kind, code or notes, from kind: in its config, or else code when it's a git repository.
    def kind(root)
      kind = self.for(File.join(root, FILE))[:kind].to_s
      return kind if KINDS.include?(kind)
      return 'code' if File.exist?(File.join(root, '.git'))

      'notes'
    end

    # The settings for rendering a file, like Raindown.render(**Config.render_options(path)).
    def render_options(path)
      self.for(path).slice(:highlight_code)
    end
  end
end
