# frozen_string_literal: true

require 'open3'
require_relative 'install_progress'

module Raindown
  module TUI
    # The terminal app needs the curses gem, which compiles against ncurses. Raindown doesn't depend on it, so a
    # framework like Raindeer that only renders Markdown never installs it. The first time the app starts without it,
    # it installs it and carries on, and only asks for help when that fails.
    module CursesInstaller
      REQUIREMENT = '~> 1.7'
      # RubyGems' own "gem" command, run by this Ruby, so curses installs where it'll load from.
      GEM_COMMAND = 'require "rubygems/gem_runner"; Gem::GemRunner.new.run(ARGV)'
      INSTALL = ['install', 'curses', '--version', REQUIREMENT, '--no-document'].freeze
      PERMISSION = "You can't write to Ruby's gems. Install curses for yourself with: gem install curses --user-install"
      HEADERS_NEEDED = 'curses compiles against ncurses, so install its headers, then: gem install curses'

      # What to install for curses to compile, by system.
      HEADERS = <<~TEXT
        On macOS:           xcode-select --install
        On Debian, Ubuntu:  sudo apt install libncurses-dev
        On Fedora:          sudo dnf install ncurses-devel
        On Alpine:          apk add ncurses-dev
      TEXT

      module_function

      # Loads curses, installing it first when it's missing. It's false when curses can't be loaded, having said why and
      # what to do. Without a terminal the app can't run, so it isn't installed then.
      def ensure_loaded(input: $stdin, output: $stderr)
        return true if loadable?
        return explain(output, "Add gem 'curses' to your Gemfile for Raindown's terminal app.") if bundled?
        return explain(output, "Raindown's terminal app needs the curses gem: gem install curses") unless input.tty?

        install(output) && loadable?
      end

      def loadable?
        gem 'curses', REQUIREMENT
        require 'curses'
        true
      rescue LoadError
        false
      end

      # Bundler only loads its bundle's gems, so one installed while running wouldn't load.
      def bundled?
        defined?(Bundler) && ENV.key?('BUNDLE_GEMFILE')
      end

      def install(output)
        progress = InstallProgress.new(output)
        succeeded, log = run_gem_install(progress)
        return explain_failure(output, log) unless succeeded

        progress.done
        Gem::Specification.reset
        true
      end

      # Runs "gem install curses" in its own process, drawing the bar meanwhile, and switching it to building once the
      # gem has downloaded. It's whether it worked, and what it said.
      def run_gem_install(progress)
        log = +''
        status = Open3.popen2e(Gem.ruby, '-e', GEM_COMMAND, *INSTALL) do |stdin, out, waiting|
          stdin.close
          reading = Thread.new { out.each_line { |line| progress.step = 'Building' if (log << line).include?('native extensions') } }
          progress.show_until { !waiting.alive? }
          reading.join
          waiting.value
        end
        [status.success?, log]
      end

      # What went wrong and what to do: install for yourself without permission, or install ncurses' headers when
      # curses wouldn't build.
      def explain_failure(output, log)
        return explain(output, PERMISSION) if log.include?('write permissions')

        reason = log.lines.find { |line| line.start_with?('ERROR') }&.strip || 'gem install curses failed'
        return explain(output, "#{reason}\n#{HEADERS_NEEDED}\n#{HEADERS}") if log.include?('native extension')

        explain(output, "#{reason}\nTry again, or install it with: gem install curses")
      end

      def explain(output, message)
        output.puts message
        false
      end
    end
  end
end
