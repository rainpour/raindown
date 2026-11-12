# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::JSNodes do
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

    markdown = "<{ SpecJsCard }>\n"

    expect(Raindown.render(markdown:)).to include("<aside>#{markdown.length}</aside>")
  end

  it 'leaves a Ruby node of the same name in place' do
    project('spec_releases.js' => "export class SpecReleases { rewrite() { return 'JS' } }\n")
    require 'helpers/nodes'

    expect(Raindown::Nodes.node_class('SpecReleases')).to eq(SpecReleases)
  end

  it 'writes the error a JavaScript Component throws in its place' do
    project('spec_js_broken.js' => "export class SpecJsBroken { rewrite() { throw new Error('Broken') } }\n")

    expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecJsBroken: -->\n<!-- :SpecJsBroken -->\n"))
      .to include("> Couldn't write: Broken\n")
  end

  it "imports other files by their paths from the node's" do
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, 'lib'))
    File.write(File.join(dir, 'lib', 'shout.mjs'), "export const shout = (text) => `${text.toUpperCase()}!`\n")
    project_in(dir, 'spec_js_shout.mjs' => <<~JS)
      import { shout } from '../lib/shout.mjs'
      export class SpecJsShout { rewrite() { return shout('hi') } }
    JS

    expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecJsShout: -->\n<!-- :SpecJsShout -->\n")).to include("HI!\n")
  end

  context "with Raindown's services" do
    it "reads its project's files, and keeps values in the cache, as raindown" do
      Dir.mktmpdir do |cache|
        stub_const('ENV', ENV.to_h.merge('XDG_CACHE_HOME' => cache))
        dir = project('spec_js_services.mjs' => <<~JS)
          export class SpecJsServices {
            async rewrite({ raindown }) {
              await raindown.cache.set('seen', { times: 2 }, { seconds: 60 })
              const kept = await raindown.cache.get('seen')
              const files = await raindown.files.list('*.txt')
              const text = await raindown.files.read(files[0])
              let outside
              try { await raindown.files.read('../secret') } catch (error) { outside = error.message }
              return [text.trim(), kept.times, outside].join(' · ')
            }
          }
        JS
        File.write(File.join(dir, 'hello.txt'), "hello\n")
        metadata = Raindown::Pages.for(File.join(dir, 'notes.rd'))

        expect(Raindown::NodeInjector.rewrite(content: "<!-- SpecJsServices: -->\n<!-- :SpecJsServices -->\n", metadata:))
          .to include("hello · 2 · ../secret is outside the project\n")
      end
    end
  end

  def project_in(dir, files)
    FileUtils.mkdir_p(File.join(dir, '.raindown'))
    files.each { |name, source| File.write(File.join(dir, '.raindown', name), source) }
    Raindown::Nodes.load(File.join(dir, 'notes.rd'))
    dir
  end
end
