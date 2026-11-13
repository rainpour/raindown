# frozen_string_literal: true

require 'raindown'
require 'raindown/services/connections'

RSpec.describe Raindown::Services::Connections do
  let(:opened) { [] }

  before do
    described_class.clear
    allow(Net::HTTP).to receive(:new) do |host, _port|
      connection = instance_double(Net::HTTP, address: host, started?: true, finish: nil)
      %i[use_ssl= open_timeout= read_timeout= keep_alive_timeout=].each { allow(connection).to receive(it) }
      allow(connection).to receive_messages(start: connection, request: :answered)
      opened << connection
      connection
    end
  end

  after { described_class.clear }

  def request(url) = described_class.request(URI(url), Net::HTTP::Get.new(URI(url)), timeout: 1)

  it "keeps a host's connection open for its next request, and opens another for another host" do
    request('https://tiles.example/1.png')
    request('https://tiles.example/2.png')
    request('https://other.example/a')

    expect(opened.map(&:address)).to eq(%w[tiles.example other.example])
  end

  it "doesn't keep a connection a request failed on" do
    request('https://tiles.example/1.png')
    allow(opened.first).to receive(:request).and_raise(EOFError)

    expect { request('https://tiles.example/2.png') }.to raise_error(EOFError)
    request('https://tiles.example/3.png')
    expect(opened.size).to eq(2)
  end
end
