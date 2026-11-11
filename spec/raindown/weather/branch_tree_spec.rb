# frozen_string_literal: true

require 'raindown/weather/branch_tree'
require 'tmpdir'

RSpec.describe Raindown::BranchTree do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @time = 1_700_000_000
      git('init', '-q', '-b', 'main')
      commit('first')
      example.run
    end
  end

  def git(*args)
    system('git', '-C', @dir, *args, exception: true, out: File::NULL, err: File::NULL)
  end

  # A commit a minute after the last, so the branches are made in order.
  def commit(message)
    @time += 60
    env = { 'GIT_AUTHOR_DATE' => "@#{@time}", 'GIT_COMMITTER_DATE' => "@#{@time}", 'GIT_AUTHOR_NAME' => 'R',
            'GIT_AUTHOR_EMAIL' => 'r@example.com', 'GIT_COMMITTER_NAME' => 'R', 'GIT_COMMITTER_EMAIL' => 'r@example.com' }
    system(env, 'git', '-C', @dir, 'commit', '-q', '--allow-empty', '-m', message, exception: true)
  end

  def branch(name, from:)
    git('checkout', '-q', '-b', name, from)
    commit(name)
  end

  it 'draws a branch a line with its own commits, those made first at the top, the ones off them indented' do
    branch('login', from: 'main')
    commit('login again')
    branch('login-tests', from: 'login')
    branch('search', from: 'main')
    branch('search-filters', from: 'search')
    branch('search-sort', from: 'search')

    expect(described_class.new(@dir).lines).to eq([
                                                    'login · 2 commits',
                                                    '    -> login-tests · 1 commit',
                                                    'search · 1 commit',
                                                    '    -> search-filters · 1 commit',
                                                    '    -> search-sort · 1 commit'
                                                  ])
  end

  it 'leaves out branches merged into main' do
    branch('done', from: 'main')
    git('checkout', '-q', 'main')
    git('merge', '-q', '--ff-only', 'done')
    branch('open', from: 'main')

    expect(described_class.new(@dir).lines).to eq(['open · 1 commit'])
  end

  it 'is empty outside a git repository' do
    expect(described_class.new(Dir.tmpdir).lines).to eq([])
  end
end
