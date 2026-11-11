# frozen_string_literal: true

require 'open3'

module Raindown
  # The branches of a git repository that aren't merged into its main branch, a line each, with how many commits it has
  # that its parent doesn't, those made earlier first, each branch off main followed by the branches off it, indented
  # under it after an arrow:
  #   login · 4 commits
  #       -> login-tests · 2 commits
  #   search · 6 commits
  #       -> search-filters · 3 commits
  #       -> search-sort · 1 commit
  # A branch is off the branch it shares the most commits with, or main, and it was made when its first commit that
  # its parent doesn't have was, or its last commit when it has none. Git doesn't keep when a branch was made.
  class BranchTree
    MAINS = %w[main master].freeze
    ARROW = '-> '
    # How much further right a branch off another starts than it.
    INDENT = 4

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
      children_of(nil).flat_map { branch_lines(it, 0) }
    end

    # The branch's line and its branches', indented under it.
    def branch_lines(name, column, arrow = '')
      ["#{' ' * column}#{arrow}#{label(name)}", *children_of(name).flat_map { branch_lines(it, column + INDENT, ARROW) }]
    end

    # The branch with its own commits, those its parent doesn't have, like "login · 4 commits".
    def label(name)
      parent = @parents[name]
      count = (@reach[name] - (parent ? @reach[parent] : Set.new)).size
      "#{name} · #{count} #{count == 1 ? 'commit' : 'commits'}"
    end

    def git(*args)
      output, status = Open3.capture2('git', '-C', @root, *args, err: File::NULL)
      output if status.success?
    end
  end
end
