# frozen_string_literal: true

require 'raindown'
require 'helpers/components'
require 'helpers/nodes'

RSpec.describe 'Raindown render tree' do
  let(:page) do
    <<~MARKDOWN
      ---
      title: Team
      people:
        - { name: Ann, role: Lead }
        - { name: Bob, role: Dev }
      draft: false
      ---

      # {title}

      <{ :toc }>

      | Name | Role |
      | ---- | ---- |
      <{ for: p in: people }>
      | {p.name} | {p.role} |
      <{ :for }>

      <{ for: p in: people }>
      <{ SpecCard: name=p.name }>
      ## {p.name}

      Works as **{p.role}**<{ if: draft }> (draft)<{ :if }>.
      <{ :SpecCard }>
      <{ :for }>
    MARKDOWN
  end

  let(:html) { Raindown.render(markdown: page) }

  it 'keeps the rows a loop makes in their table' do
    expect(html).to include("<tbody>\n<tr>\n<td>Ann</td>\n<td>Lead</td>\n</tr>\n<tr>\n<td>Bob</td>\n<td>Dev</td>\n</tr>\n</tbody>")
  end

  it "renders each component in the loop's scope, with its slot as HTML" do
    expect(html).to include('<section data-name="Ann"><h2 id="ann">Ann', 'Works as <strong>Lead</strong>.</p>')
    expect(html).to include('<section data-name="Bob"><h2 id="bob">Bob', 'Works as <strong>Dev</strong>.</p>')
    expect(html).not_to include('(draft)')
  end

  it "lists the components' headings in the table of contents" do
    expect(html).to include("<a href='#ann'>Ann</a>", "<a href='#bob'>Bob</a>")
  end

  it 'makes heading ids unique across components' do
    html = Raindown.render(markdown: "<{ SpecCard: }>\n## Same\n<{ :SpecCard }>\n\n<{ SpecCard: }>\n## Same\n<{ :SpecCard }>\n")

    expect(html).to include('<h2 id="same">', '<h2 id="same-1">', 'href="#same-1"')
  end

  it 'renders a component in another component\'s slot' do
    html = Raindown.render(markdown: "<{ SpecCard: name='outer' }>\n<{ SpecCard name='inner' }>\n<{ :SpecCard }>\n")

    expect(html).to include('<section data-name="outer"><section data-name="inner"></section>')
  end

  it 'gives a node in <{ }> its loop variables as props' do
    markdown = "---\nlimits: [1, 2]\n---\n\n<{ for: limit in: limits }>\n<{ SpecReleases limit=limit }>\n<{ :for }>\n"

    expect(Raindown.render(markdown:).scan('<li>').length).to eq(3)
  end

  it 'renders a component with only render like a node, with the document, keeping its instance between renders' do
    markdown = "<{ SpecDocumentLength }>\n"
    first, second = Array.new(2) { Raindown.render(markdown:).match(/data-count="(\d+)">(\d+)/).captures.map(&:to_i) }

    expect(first.last).to eq(markdown.length)
    expect(second.first).to eq(first.first + 1)
  end

  it 'lists the headings a node renders in <{ }> in the table of contents' do
    html = Raindown.render(markdown: "<{ :toc }>\n\n<{ SpecWrapper: }>\n## Inside\n<{ :SpecWrapper }>\n")

    expect(html).to include("<a href='#inside'>Inside</a>", '<aside><h2 id="inside">')
  end
end
