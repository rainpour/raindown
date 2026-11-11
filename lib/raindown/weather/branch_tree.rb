# frozen_string_literal: true

require 'open3'

module Raindown
  # The branches of a git repository that aren't merged into its main branch, as events, each on the day it was made,
  # in lines from left to right, each starting with a branch off main, then the branches off it, the ones made earlier
  # further left:
  #   Nov 10 login  ->  Nov 11 login-tests
  #                     Nov 12 search  ->  Nov 12 search-filters
  #                                    ->  Nov 14 search-sort
  # A branch is off the branch it shares the most commits with, or main, and it was made when its first commit that
  # its parent doesn't have was, or its last commit when it has none. Git doesn't keep when a branch was made. Two
  # spaces either side of an arrow keep the events apart, so an app can draw each as a block.
  class BranchTree
    MAINS = %w[main master].freeze
    ARROW = '  ->  '
    DATE = '%b %-d'
    # The furthest right a branch off main starts, so a long list doesn't run off the page.
    WIDEST_START = 40

    Commit = Data.define(:time, :parents)

    def initialize(root)
      @root = root
    end

    def lines
      return [] unless main

      @tips = unmerged_tips
      return [] if @tips.empty?

      @commits = commits_off_main
      @reach = @tips.to_h { |name, tip| [name, reachable(tip)] }
      @parents = @tips.keys.to_h { [it, parent_of(it)] }
      draw
    end

    private

    def main
      @main ||= MAINS.find { git('rev-parse', '--verify', '--quiet', "refs/heads/#{it}") }
    end

    # Each unmerged branch's name and the commit it's at.
    def unmerged_tips
      output = git('branch', '--no-merged', main, '--format=%(refname:short) %(objectname)').to_s
      output.lines.to_h(&:split)
    end

    # The commits on the branches that main doesn't have, by their hashes.
    def commits_off_main
      output = git('log', '--format=%H %ct %P', *@tips.values, "^#{main}").to_s
      output.lines.to_h do |line|
        hash, time, *parents = line.split
        [hash, Commit.new(time: time.to_i, parents:)]
      end
    end

    # The commits from a tip that main doesn't have.
    def reachable(tip)
      found = Set.new
      queue = [tip]
      while (hash = queue.shift)
        next if found.include?(hash) || !@commits.key?(hash)

        found << hash
        queue.concat(@commits[hash].parents)
      end
      found
    end

    # The branch it shares the most commits with that isn't off it, or main. Of two at the same commit, the one made
    # first is the parent.
    def parent_of(name)
      candidates = @tips.keys.reject { it == name || off?(it, name) }
      shared = candidates.to_h { [it, (@reach[name] & @reach[it]).size] }.select { |_, count| count.positive? }
      shared.max_by { |other, count| [count, -created_at(other, by: nil)] }&.first
    end

    # Whether one branch is off another: its tip has the other's, but not the other way round, or they're at the same
    # commit and it's later by name.
    def off?(name, other)
      has = @reach[name].include?(@tips[other])
      return has unless has && @reach[other].include?(@tips[name])

      name > other
    end

    # When its first commit that its parent doesn't have was made, or its last commit.
    def created_at(name, by: @parents[name])
      own = @reach[name] - (by ? @reach[by] : Set.new)
      times = own.map { @commits[it].time }
      times.min || @commits[@tips[name]]&.time || 0
    end

    def children_of(parent)
      @tips.keys.select { @parents[it] == parent }.sort_by { [created_at(it), it] }
    end

    # Each branch off main starts a line further right than the one made before it, and its first branch carries on
    # its line, while its other branches start lines below, their arrows under its first's.
    def draw
      start = 0
      children_of(nil).flat_map do |root|
        lines = chain(root, start)
        start = [start + event(root).length + ARROW.length, WIDEST_START].min
        lines
      end
    end

    # The branch's event and its branches', its first carrying on its line, the others below, their arrows under its
    # first's.
    def chain(name, column, arrow = '')
      text = "#{' ' * column}#{arrow}#{event(name)}"
      first, *rest = children_of(name)
      return [text] unless first

      first_lines = chain(first, text.length, ARROW)
      [text + first_lines.first[text.length..], *first_lines.drop(1),
       *rest.flat_map { chain(it, text.length + 2, ARROW.lstrip) }]
    end

    # The branch as an event, on the day it was made, like "Nov 10 login".
    def event(name)
      "#{Time.at(created_at(name)).strftime(DATE)} #{name}"
    end

    def git(*args)
      output, status = Open3.capture2('git', '-C', @root, *args, err: File::NULL)
      output if status.success?
    end
  end
end
