# frozen_string_literal: true

require 'raindown/endpoint/endpoint_runner'
require 'tmpdir'

RSpec.describe Raindown::EndpointRunner do
  def rewrite(content, execute: true, **options)
    described_class.rewrite(content:, execute:, **options)
  end

  def failures(**)
    described_class.new(**).tap(&:rewrite).failures
  end

  let(:curl) { "```sh\ncurl https://api.example.com/users\n```\n" }
  let(:fetched) { "<!-- response 200 · 142 ms · 2026-10-14 -->\n" }
  let(:response) { "#{fetched}```json\n{\n  \"id\": 1\n}\n```\n" }

  before do
    allow(Raindown::Curl).to receive(:run).and_return(curl_response("{\n  \"id\": 1\n}", 'json'))
    allow(Date).to receive(:today).and_return(Date.new(2026, 10, 14))
  end

  it 'writes the response below the curl block when executing, after the date it was fetched' do
    expect(rewrite("<!-- endpoint: -->\n\n#{curl}\nAfter.\n")).to eq("<!-- endpoint: -->\n\n#{curl}#{response}\nAfter.\n")
  end

  it 'writes the response inside the closing tag' do
    expect(rewrite("<!-- endpoint: -->\n#{curl}<!-- :endpoint -->\n"))
      .to eq("<!-- endpoint: -->\n#{curl}#{response}<!-- :endpoint -->\n")
  end

  it 'runs when the next block is another curl example' do
    other = "```sh\ncurl https://api.example.com/other\n```\n"

    expect(rewrite("<!-- endpoint: -->\n\n#{curl}\n#{other}")).to eq("<!-- endpoint: -->\n\n#{curl}#{response}\n#{other}")
  end

  it 'does not run without --execute' do
    content = "<!-- endpoint: -->\n\n#{curl}"

    expect(rewrite(content, execute: false)).to eq(content)
    expect(Raindown::Curl).not_to have_received(:run)
  end

  it 'fills an empty output block' do
    expect(rewrite("<!-- endpoint: -->\n\n#{curl}\n```\n```\n")).to eq("<!-- endpoint: -->\n\n#{curl}#{response}")
  end

  it 'replaces the fetched date when an emptied block is fetched again' do
    content = "<!-- endpoint: -->\n\n#{curl}<!-- response 2025-01-01 -->\n```json\n```\n\nAfter.\n"

    expect(rewrite(content)).to eq("<!-- endpoint: -->\n\n#{curl}#{response}\nAfter.\n")
  end

  it 'leaves existing output alone' do
    content = "<!-- endpoint: -->\n\n#{curl}\n```json\n{}\n```\n"

    expect(rewrite(content)).to eq(content)
    expect(Raindown::Curl).not_to have_received(:run)
  end

  it 'ignores directives in code' do
    content = "````md\n<!-- endpoint: -->\n\n#{curl}````\n"

    expect(rewrite(content)).to eq(content)
  end

  it 'ignores a directive without a curl block below it' do
    content = "<!-- endpoint: -->\n\n```sh\nls\n```\n"

    expect(rewrite(content)).to eq(content)
  end

  it 'runs every endpoint in the file' do
    content = rewrite("<!-- endpoint: -->\n\n#{curl}\n<!-- endpoint: -->\n\n#{curl}")

    expect(content.scan('```json').length).to eq(2)
  end

  it 'reads bare directives' do
    expect(rewrite("endpoint:\n#{curl}\nAfter.\n", path: 'api.rd')).to eq("endpoint:\n#{curl}#{response}\nAfter.\n")
    expect(rewrite("endpoint:\n#{curl}", path: 'api.md')).to eq("endpoint:\n#{curl}")
  end

  it 'leaves a snippet after a blank line below a bare endpoint, and a response after one, out of it' do
    expect(rewrite("endpoint:\n\n#{curl}", path: 'api.rd')).to eq("endpoint:\n\n#{curl}")
    expect(rewrite("endpoint:\n#{curl}\n```json\n{}\n```\n", path: 'api.rd')).to eq("endpoint:\n#{curl}#{response}\n```json\n{}\n```\n")
  end

  it 'fences the response with more backticks than it contains' do
    allow(Raindown::Curl).to receive(:run).and_return(curl_response("```\ncode\n```", 'text'))

    expect(rewrite("<!-- endpoint: -->\n\n#{curl}")).to end_with("#{fetched}````text\n```\ncode\n```\n````\n")
  end

  it 'warns and leaves the file alone when curl fails' do
    allow(Raindown::Curl).to receive(:run).and_raise(Raindown::Curl::Error, 'curl: (6) Could not resolve host')
    content = "<!-- endpoint: -->\n\n#{curl}"

    expect { expect(rewrite(content)).to eq(content) }.to output(/Endpoint failed: curl: \(6\)/).to_stderr
  end

  it 'fills placeholders in the snippet from front matter' do
    rewrite("---\nbase_url: https://a.io\n---\n<!-- endpoint: -->\n\n```sh\ncurl {base_url}/users\n```\n")

    expect(Raindown::Curl).to have_received(:run) do |snippet, variables|
      expect(Raindown::Curl.arguments(snippet, variables)).to eq(['https://a.io/users'])
    end
  end

  it 'gives later snippets the response of an endpoint named with as:, whether it was run or already written' do
    login = "<!-- endpoint: as: login -->\n\n```sh\ncurl https://a.io/login\n```\n"
    users = "<!-- endpoint: -->\n\n```sh\ncurl -H 'Authorization: Bearer {login.id}' https://a.io/users\n```\n"
    headers = []
    allow(Raindown::Curl).to receive(:run) do |snippet, variables|
      headers << Raindown::Curl.arguments(snippet, variables)[1]
      curl_response("{\n  \"id\": 1\n}")
    end

    rewrite("#{login}\n#{users}") # Runs both, the first without a header.
    rewrite("#{login}\n```json\n{\"id\": 2}\n```\n\n#{users}")

    expect(headers).to eq([nil, 'Authorization: Bearer 1', 'Authorization: Bearer 2'])
  end

  describe 'checks' do
    let(:checked) { "<!-- endpoint: status: 200 schema: Schema[id: Integer] -->\n\n#{curl}" }

    it 'checks the responses in the file by the status in their fetched comment, without running them' do
      content = "#{checked}<!-- response 404 · 9 ms · 2026-10-14 -->\n```json\n{\"id\": \"1\"}\n```\n"

      expect(failures(content:, path: 'api.md'))
        .to eq(['api.md:1: expected status 200, received 404', 'api.md:1: id: expected Integer, received "1"'])
      expect(Raindown::Curl).not_to have_received(:run)
    end

    it 'checks the status of a response with an empty body' do
      content = "<!-- endpoint: status: 201 -->\n\n#{curl}<!-- response 404 · 9 ms · 2026-10-14 -->\n```html\n\n```\n"

      expect(failures(content:)).to eq(['1: expected status 201, received 404'])
    end

    it "checks responses against the project's shared schemas in .raindown/schemas.rd" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'schemas.rd'), "schema: 'User'\n  id: Integer\n\nschema: 'Users'\n  users: Array[User]\n")
        content = "<!-- endpoint: schema: 'Users' -->\n\n#{curl}\n```json\n{\"users\": [{\"id\": \"1\"}]}\n```\n"

        expect(failures(content:, path: File.join(dir, 'api.md')))
          .to eq(["#{dir}/api.md:1: users[0].id: expected Integer, received \"1\""])
      end
    end

    it 'checks a response as it runs, and skips one without a response or a status' do
      allow(Raindown::Curl).to receive(:run).and_return(curl_response('{"id": 1}', status: 500))
      runner = described_class.new(content: "#{checked}\n#{checked}\n```json\n{\"id\": 1}\n```\n", execute: false)
      runner.rewrite

      expect(runner.failures).to eq([])
      runner = described_class.new(content: checked, execute: true)
      runner.rewrite

      expect(runner.failures).to eq(['1: expected status 200, received 500'])
    end
  end

  describe 'secrets' do
    around do |example|
      ENV['RAINDOWN_SPEC_TOKEN'] = 'sk-123456'
      example.run
    ensure
      ENV.delete('RAINDOWN_SPEC_TOKEN')
    end

    let(:content) { "<!-- endpoint: -->\n\n```sh\ncurl -H 'Authorization: Bearer {env.RAINDOWN_SPEC_TOKEN}' https://a.io\n```\n" }

    it 'writes a secret that the response echoes as its placeholder' do
      allow(Raindown::Curl).to receive(:run) do |snippet, variables|
        curl_response(%({"auth": "#{Raindown::Curl.arguments(snippet, variables)[1]}"}))
      end

      expect(rewrite(content)).to include('{"auth": "Authorization: Bearer {env.RAINDOWN_SPEC_TOKEN}"}')
    end

    it 'leaves secrets out of errors' do
      allow(Raindown::Curl).to receive(:run) do |snippet, variables|
        raise Raindown::Curl::Error, "Can't send #{Raindown::Curl.arguments(snippet, variables)[1]}"
      end

      expect { rewrite(content) }.to output(/Can't send Authorization: Bearer \{env.RAINDOWN_SPEC_TOKEN\}/).to_stderr
    end
  end

  describe 'only:' do
    let(:content) { "<!-- endpoint: -->\n\n#{curl}#{fetched}```json\n{}\n```\n\n<!-- endpoint: -->\n\n#{curl}" }

    it 'runs just the endpoint on that line, replacing its response, even without executing' do
      allow(Date).to receive(:today).and_return(Date.new(2026, 10, 20))

      rewritten = described_class.new(content:, only: 0).rewrite

      expect(rewritten).to start_with("<!-- endpoint: -->\n\n#{curl}<!-- response 200 · 142 ms · 2026-10-20 -->\n" \
                                      "```json\n{\n  \"id\": 1\n}\n```\n")
      expect(rewritten.scan('```json').length).to eq(1)
    end

    it 'raises when curl fails, for the caller to show' do
      allow(Raindown::Curl).to receive(:run).and_raise(Raindown::Curl::Error, 'curl: (6) Could not resolve host')

      expect { described_class.new(content:, only: 0).rewrite }.to raise_error(Raindown::Curl::Error)
    end
  end
end
