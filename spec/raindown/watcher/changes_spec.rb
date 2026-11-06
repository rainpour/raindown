# frozen_string_literal: true

require 'raindown/watcher/changes'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Watcher do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    end
  end

  def folder(path, marker)
    File.join(@dir, path).tap { FileUtils.mkdir_p(File.join(it, marker)) }
  end

  def changed(*paths, **)
    described_class.changes(paths, **).map(&:path)
  end

  it 'leaves out a vault below the directory, even with a .raindown folder of its own' do
    vault = folder('notes', '.obsidian')
    FileUtils.mkdir_p(File.join(vault, '.raindown'))
    note = File.join(vault, 'journal', 'today.md')

    expect(changed(note, directory: @dir, root: @dir)).to be_empty
  end

  it 'takes changes in a vault when the vault, or a folder in it, is the directory' do
    vault = folder('notes', '.obsidian')
    note = File.join(vault, 'journal', 'today.md')
    FileUtils.mkdir_p(File.dirname(note))

    expect(changed(note, directory: vault, root: vault)).to eq([note])
    expect(changed(note, directory: File.dirname(note), root: File.dirname(note))).to eq([note])
  end

  it 'still takes changes in a project beside a vault' do
    folder('notes', '.obsidian')
    note = File.join(folder('docs', '.raindown'), 'guide.md')

    expect(changed(note, directory: @dir)).to eq([note])
  end
end
