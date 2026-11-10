# frozen_string_literal: true

require 'raindown'
require 'raindown/toc/markdown_headings'

RSpec.describe Raindown::MarkdownHeadings do
  def scan(markdown, **)
    described_class.scan(markdown, **).map { [it[:level], it[:text], it[:id]] }
  end

  it 'finds # headings and underlined ones, but not a line of dashes below a list, or a rule' do
    headings = [[1, 'One', 'one'], [1, 'Two', 'two'], [2, 'Three', 'three']]

    expect(scan("# One\nTwo\n===\nThree\n---\n\nText\n\n---\n- item\n---\n")).to eq(headings)
  end

  it 'leaves out headings in front matter, fenced code and comments' do
    markdown = "---\ntitle: '# Not'\n---\n```\n# Not\n```\n~~~~\n# Not\n~~~\n# Not\n~~~~\n<!--\n# Not\n-->\n# Yes\n"

    expect(scan(markdown)).to eq([[1, 'Yes', 'yes']])
  end

  it 'reads headings as they read, without links, code or emphasis marks, with ids like Commonmarker makes them' do
    markdown = "# The **bold** *it* `code` [link](x.md)\n## Snake_case_name\n## ![alt](a.png) pic\n## C++ & Ruby: 100%?\n"

    headings = [
      [1, 'The bold it code link', 'the-bold-it-code-link'], [2, 'Snake_case_name', 'snake_case_name'],
      [2, 'pic', 'alt-pic'], [2, 'C++ & Ruby: 100%?', 'c--ruby-100']
    ]

    expect(scan(markdown)).to eq(headings)
  end

  it 'numbers repeated ids, and fills in variables' do
    variables = Raindown::Variables.new(name: 'Mark')

    expect(scan("# A\n## A\n# {name}\n", variables:)).to eq([[1, 'A', 'a'], [2, 'A', 'a-1'], [1, 'Mark', 'mark']])
  end
end
