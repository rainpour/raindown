# frozen_string_literal: true

require 'raindown/projects'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Gitignore do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    end
  end

  def path(*parts) = File.join(@dir, *parts)

  it 'ignores the folders a .gitignore names, from its folder when they have a slash, or anywhere below it' do
    File.write(path('.gitignore'), "# Composer.\n/web/core\n/web/modules/contrib/*\nvendor/\n!vendor/\ncache\n*.log\n")

    gitignore = described_class.new(@dir)

    expect(%w[web/core web/modules/contrib a/b/cache].map { gitignore.ignores?(path(it)) }).to all(be(true))
    expect(%w[core a/web/core vendor web/modules].map { gitignore.ignores?(path(it)) }).to all(be(false))
  end

  it 'keeps the rules of the folders above, but not into a repository of its own' do
    File.write(path('.gitignore'), "cache\n")
    FileUtils.mkdir_p(path('docs'))
    FileUtils.mkdir_p(path('repo', '.git'))

    expect(described_class.new(path('docs'), described_class.new(@dir)).ignores?(path('docs', 'cache'))).to be(true)
    expect(described_class.new(path('repo'), described_class.new(@dir)).ignores?(path('repo', 'cache'))).to be(false)
  end

  it 'leaves the projects in gitignored folders out of the projects found' do
    File.write(path('.gitignore'), "/build-output\n")
    %w[build-output/site docs].each { FileUtils.mkdir_p(path(it, '.raindown')) }

    expect(Raindown::Projects.roots(@dir)).to eq([path('docs')])
  end
end
