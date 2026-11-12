# frozen_string_literal: true

require 'antlers'
require 'antlers/api'

# Libraries that take a while to load, loaded the first time they're used: FileUtils and URI, and unicode-display_width,
# which reads its tables of characters' widths as it loads.
autoload :FileUtils, 'fileutils'
autoload :URI, 'uri'
module Unicode
  autoload :DisplayWidth, 'unicode/display_width'
end

require_relative 'elements'
require_relative 'raindown/bare_directives'
require_relative 'raindown/code'
require_relative 'raindown/config'
require_relative 'raindown/context'
require_relative 'raindown/directives'
require_relative 'raindown/fragments'
require_relative 'raindown/front_matter'
require_relative 'raindown/heading_ids'
require_relative 'raindown/node_blocks'
require_relative 'raindown/outdent'
require_relative 'raindown/pages/pages'
require_relative 'raindown/pre_renderer'
require_relative 'raindown/table/table_formatter'
require_relative 'raindown/utils'
require_relative 'raindown/variables'
require_relative 'raindown/wiki_links'

module Raindown
  # Antlers evaluates any braces in the HTML, so braces in code are swapped for placeholders
  # then HTML entities, which browsers still display as braces.
  CODE_BRACES = { '{' => "\u{E000}", '}' => "\u{E001}" }.freeze
  CODE_BRACE_ENTITIES = { "\u{E000}" => '&#123;', "\u{E001}" => '&#125;' }.freeze

  # Front matter is metadata, so it's left out of the HTML and the headings.
  MARKDOWN_OPTIONS = { extension: { alerts: true, front_matter_delimiter: '---' } }.freeze
  # Directives are HTML comments until Antlers renders them, and escaped characters like "\#" stay plain text.
  HTML_OPTIONS = { render: { unsafe: true, escaped_char_spans: false } }.freeze
  # Without highlighting, code blocks are left for the browser to highlight, like <pre><code class="language-ruby">.
  UNHIGHLIGHTED_OPTIONS = { render: { **HTML_OPTIONS[:render], github_pre_lang: false } }.freeze

  # Stands in for an app's metadata when there isn't any, so list: lists nothing.
  module NoMetadata
    def self.list(**) = []
  end

  module_function

  # Code is highlighted, unless the file's project changes it in .raindown/config.yml.
  def render_file(path:, metadata: NoMetadata, bare: false, **options)
    options = Config.render_options(path).merge(options)
    render(markdown: Utils.read_markdown(path), metadata:, bare: bare || BareDirectives.file?(path), **options)
  end

  # Front matter keys are variables, like {title} or <{ title }>.
  # Bare directives like "toc:" show in bold in the HTML, and the rest stay hidden, as comments.
  # Code blocks are highlighted, unless highlight_code is false for a site that highlights code in the browser.
  # Without commonmark, it's Markdown, not HTML, with nodes as they'd be written back, for an app to render itself, like
  # Obsidian's reading view in the plugin, where Commonmarker, which is native, can't run.
  def render(markdown:, metadata: NoMetadata, bare: false, highlight_code: true, commonmark: true)
    context = Context.new(document: Outdent.unwrapped(markdown), metadata:, bare: bare || BareDirectives.front_matter?(markdown))

    rendering(highlight_code:, commonmark:) do
      Fragments.collect do
        # Components' HTML goes back in, then their headings get unique ids, before nodes like the TOC see it.
        html = Nodes.render_placeholders(assembled(context), context)
        output = Directives.render("#{html.chomp}\n")
        next output if commonmark

        output.gsub(/[\u{E000}\u{E001}]/, CODE_BRACES.invert)
      end
    end
  end

  # Whether code is highlighted, and Markdown made HTML, while the block runs, like one document's render,
  # so components and endpoints rendering their own Markdown follow it too.
  def rendering(highlight_code:, commonmark: true)
    outer = Thread.current[:raindown_rendering]
    Thread.current[:raindown_rendering] = { highlight_code:, commonmark: }
    yield
  ensure
    Thread.current[:raindown_rendering] = outer
  end

  def highlight_code?
    Thread.current[:raindown_rendering]&.fetch(:highlight_code) != false
  end

  def commonmark?
    Thread.current[:raindown_rendering]&.fetch(:commonmark) != false
  end

  # The document's HTML with its components' HTML put back, and unique heading ids.
  def assembled(context)
    HeadingIds.unique(Fragments.fill(html(context)))
  end

  # The document's HTML from Commonmarker, after nodes and the template pass, with components as fragments.
  def html(context)
    markdown = WikiLinks.to_markdown(NodeBlocks.to_rendered(context), metadata: context.metadata)
    commonmark(PreRenderer.render(markdown, variables: context.variables, context:))
  end

  # Commonmarker's tree of the Markdown. It's only loaded here, as only rendering HTML needs it, so a build without it,
  # like the WebAssembly one, can still write back.
  def parse_markdown(markdown)
    require 'commonmarker'
    Commonmarker.parse(markdown, options: MARKDOWN_OPTIONS)
  end

  # Markdown to HTML, like a document's or a component's slot, unless it's rendering Markdown.
  def commonmark(markdown)
    return markdown unless commonmark?

    doc = parse_markdown(hide_directives(markdown: TableFormatter.gfm(markdown)))
    preserve_code(doc:)

    html = highlight_code? ? doc.to_html(options: HTML_OPTIONS) : unhighlighted_html(doc:)
    html.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>')
        .gsub(/[\u{E000}\u{E001}]/, CODE_BRACE_ENTITIES)
  end

  # Code blocks without highlighting, with a language class for highlighting in the browser.
  def unhighlighted_html(doc:)
    doc.to_html(options: UNHIGHLIGHTED_OPTIONS, plugins: { syntax_highlighter: nil })
  end

  # Commonmarker escapes directives, so they're hidden in HTML comments until it's done.
  def hide_directives(markdown:)
    markdown.gsub('<{', '<!-- ANTLERS').gsub('}>', 'ANTLERS -->').force_encoding('UTF-8')
  end

  # Restore directives in code and hide its braces from Antlers.
  def preserve_code(doc:)
    doc.walk do |node|
      next unless %i[code code_block].include?(node.type)

      node.string_content = node.string_content.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>')
                                .gsub(/[{}]/, CODE_BRACES)
    end
  end
end
