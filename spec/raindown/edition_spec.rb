# frozen_string_literal: true

require 'raindown'
require 'open3'
require 'raindown/editing'
require 'tmpdir'

RSpec.describe Raindown::Edition do
  around do |example|
    Raindown.edition = described_class::COMPONENTS
    example.run
  ensure
    Raindown.edition = nil
  end

  def components(files)
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, 'Components'))
    files.each { |name, source| File.write(File.join(dir, 'Components', name), source) }
    dir
  end

  def rewritten(dir, markdown)
    Raindown::Editing.rewrite_markdown(markdown, path: File.join(dir, 'note.md'))[:output]
  end

  it 'writes a Markdown Component in the Components folder, which Obsidian shows' do
    dir = components('SpecEditionCard.md' => "---\nrating: 0\n---\n\n**{title}** · {rating}/5\n")

    expect(rewritten(dir, "<!-- SpecEditionCard: title: 'Dune' rating: 5 -->\n<!-- :SpecEditionCard -->\n"))
      .to eq("<!-- SpecEditionCard: title: 'Dune' rating: 5 -->\n**Dune** · 5/5\n<!-- :SpecEditionCard -->\n")
  end

  it "writes a component's bare directive in any note, up to the next blank line, leaving other names alone" do
    dir = components('SpecEditionBare.md' => "**{title}**\n")

    expect(rewritten(dir, "SpecEditionBare: title: 'Dune'\n\nNote: call Sam\n"))
      .to eq("SpecEditionBare: title: 'Dune'\n**Dune**\n\nNote: call Sam\n")
  end

  it "has only Markdown Components, and none of Raindown's own nodes, or its lining up of tables" do
    dir = components('SpecEditionRuby.rb' => "class SpecEditionRuby < Raindown::Node\n  def rewrite = 'ruby'\nend\n")
    markdown = "<!-- SpecEditionRuby: -->\n<!-- :SpecEditionRuby -->\n\n<!-- toc: -->\n<!-- :toc -->\n\n# A\n\n| a | bb |\n|-|-|\n"

    expect(rewritten(dir, markdown)).to eq(markdown)
    expect(Object.const_defined?(:SpecEditionRuby)).to be(false)
  end

  it "loads none of the other features' files, like endpoints', JavaScript nodes' or lining up tables'" do
    dir = components('SpecEditionCard.md' => "**{title}**\n")
    script = <<~RUBY
      require 'raindown/editing'
      Raindown.edition = Raindown::Edition::COMPONENTS
      Raindown::Editing.rewrite_markdown("SpecEditionCard: title: 'Dune'\n\n| a | b |\n|-|-|\n", path: '#{dir}/note.md')
      Raindown::Editing.render_markdown("SpecEditionCard: title: 'Dune'\n", path: '#{dir}/note.md', commonmark: false)
      puts $LOADED_FEATURES.grep(%r{endpoint_(runner|lexeme|node)|schema_block|/dirload\.rb|/projects\.rb|/curl|/js/|/table/|ruby_nodes})
    RUBY
    loaded, status = Open3.capture2('ruby', '-I', File.expand_path('../../lib', __dir__), '-e', script)

    expect(status).to be_success
    expect(loaded).to eq('')
  end
end
