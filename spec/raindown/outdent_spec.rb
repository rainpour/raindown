# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'

RSpec.describe Raindown::Outdent do
  let(:file) { "---\nraindown: true\n---\n\n^^^^^^^^^^\n< toc:\n< - stale\n\n## Notes\n" }

  it "writes back a bare directive in a block, keeping each line's <" do
    expect(Raindown::NodeInjector.rewrite(content: file))
      .to eq("---\nraindown: true\n---\n\n^^^^^^^^^^\n< toc:\n< - [Notes](#notes)\n\n## Notes\n")
  end

  it 'gives a warning in a block the line in the file' do
    injector = Raindown::NodeInjector.new(content: "<!-- x -->\n\n^^^^\n< <!-- toc: 5 -->\n< <!-- :toc -->\n")
    injector.call

    expect(injector.problems.join).to include('line 4')
  end

  it 'leaves a block in code alone, and lines starting with < without a rule above them' do
    content = "```\n^^^^\n< toc:\n```\n\n< toc:\n"

    expect(Raindown::NodeInjector.rewrite(content:, bare: true)).to eq(content)
  end

  it 'renders a block as a div of its Markdown' do
    html = Raindown.render(markdown: "Before\n\n^^^^^^\n< **Sunny**\n<\n< - [x] dry\n")

    expect(html).to include("<div class=\"outdent\">\n<p><strong>Sunny</strong></p>")
    expect(html).not_to include('^^^')
  end
end
