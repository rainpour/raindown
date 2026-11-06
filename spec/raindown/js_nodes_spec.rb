# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::JSNodes do
  before { skip 'needs Node.js' unless system('node', '-v', out: File::NULL, err: File::NULL) }

  def project(files)
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, '.raindown'))
    files.each { |name, source| File.write(File.join(dir, '.raindown', name), source) }
    Raindown::Nodes.load(File.join(dir, 'notes.rd'))
    dir
  end

  it 'writes the Markdown of a JavaScript Component with its props' do
    project('spec_js_list.mjs' => <<~JS)
      export class SpecJsList {
        constructor({ limit = 5 }) { this.limit = limit }
        rewrite() { return Array.from({ length: this.limit }, (_, index) => `- ${index + 1}`).join('\\n') }
      }
    JS

    markdown = Raindown::NodeInjector.rewrite(content: "<!-- SpecJsList: limit=2 -->\n<!-- :SpecJsList -->\n")

    expect(markdown).to eq("<!-- SpecJsList: limit=2 -->\n- 1\n- 2\n<!-- :SpecJsList -->\n")
  end

  it 'renders the HTML of a JavaScript Component with render, and is given the document' do
    project('spec_js_card.js' => <<~JS)
      export default class SpecJsCard {
        rewrite() { return 'Card' }
        async render({ document }) { return `<aside>${document.length}</aside>` }
      }
    JS

    expect(Raindown.render(markdown: "<{ SpecJsCard }>\n")).to include('<aside>18</aside>')
  end

  it 'leaves a Ruby node of the same name in place' do
    project('spec_releases.js' => "export class SpecReleases { rewrite() { return 'JS' } }\n")
    require 'helpers/nodes'

    expect(Raindown::Nodes.node_class('SpecReleases')).to eq(SpecReleases)
  end

  it 'raises the error a JavaScript Component throws' do
    project('spec_js_broken.js' => "export class SpecJsBroken { rewrite() { throw new Error('Broken') } }\n")

    expect { Raindown::NodeInjector.rewrite(content: "<!-- SpecJsBroken: -->\n<!-- :SpecJsBroken -->\n") }
      .to raise_error(Raindown::JSNodes::Error, 'Broken')
  end
end
