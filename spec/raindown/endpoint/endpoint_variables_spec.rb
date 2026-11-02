# frozen_string_literal: true

require 'raindown'
require 'tmpdir'

RSpec.describe Raindown::EndpointVariables do
  def variables(content = '', path: nil)
    described_class.new(path:, content:)
  end

  it 'fills placeholders from front matter, including nested values' do
    filled = variables("---\nbase_url: https://a.io\napi:\n  version: 2\n---\n")

    expect(filled.substitute('{base_url}/v{api.version}/users')).to eq('https://a.io/v2/users')
  end

  it 'leaves unknown placeholders and JSON braces alone' do
    expect(variables.substitute('{"id":1} {missing} {a.b}')).to eq('{"id":1} {missing} {a.b}')
  end

  it 'fills environment variables from env.' do
    ENV['RAINDOWN_SPEC_TOKEN'] = 'secret'

    expect(variables.substitute('Bearer {env.RAINDOWN_SPEC_TOKEN}')).to eq('Bearer secret')
  ensure
    ENV.delete('RAINDOWN_SPEC_TOKEN')
  end

  it 'remembers a response as JSON data, or else text' do
    filled = variables
    filled.remember('login', %({"token":"abc","users":[{"id":7}]}))
    filled.remember('plain', "hello\n")

    expect(filled.substitute('{login.token} {login.users.0.id} {login.users} {plain}'))
      .to eq('abc 7 [{"id":7}] hello')
  end

  describe 'environments' do
    around do |example|
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'environments.yml'), <<~YAML)
          local:
            base_url: http://localhost:3000
          staging:
            base_url: https://staging.a.io
            token: '{env.RAINDOWN_SPEC_TOKEN}'
        YAML
        @path = File.join(dir, 'docs', 'api.md')
        example.run
      ensure
        ENV.delete('RAINDOWN_ENV')
        ENV.delete('RAINDOWN_SPEC_TOKEN')
      end
    end

    it 'uses the first environment, over front matter' do
      expect(variables("---\nbase_url: https://a.io\n---\n", path: @path).substitute('{base_url}')).to eq('http://localhost:3000')
    end

    it 'uses the one RAINDOWN_ENV names, whose values can read environment variables' do
      ENV['RAINDOWN_ENV'] = 'staging'
      ENV['RAINDOWN_SPEC_TOKEN'] = 'secret'

      expect(variables(path: @path).substitute('{base_url} {token}')).to eq('https://staging.a.io secret')
    end

    it 'raises when RAINDOWN_ENV names one that is not there' do
      ENV['RAINDOWN_ENV'] = 'production'

      expect { variables(path: @path).substitute('{base_url}') }.to raise_error(Raindown::Curl::Error, /no production environment/)
    end
  end
end
