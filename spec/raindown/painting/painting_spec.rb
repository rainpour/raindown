# frozen_string_literal: true

require 'raindown'
require 'tmpdir'

RSpec.describe Raindown::Painting do
  let(:day) { Date.new(2026, 11, 12) }
  let(:painting) do
    Raindown::Rijksmuseum::Painting.new(title: 'Misty Sea', creator: 'Jan Toorop', date: '1899',
                                        image: 'https://iiif.micr.io/mPymb/full/!1200,1200/0/default.jpg',
                                        url: 'https://id.rijksmuseum.nl/200100988')
  end
  let(:museum) { instance_double(Raindown::Rijksmuseum, painting_of: painting) }

  around do |example|
    Dir.mktmpdir do |dir|
      original = ENV.fetch('XDG_CACHE_HOME', nil)
      ENV['XDG_CACHE_HOME'] = dir
      example.run
    ensure
      ENV['XDG_CACHE_HOME'] = original
    end
  end

  it "writes the day's painting's title, painter and date" do
    described_class.today(day: Date.today, museum:)
    expect(described_class.new.rewrite).to eq("*Misty Sea*\nJan Toorop\n1899")
  end

  it "keeps what it wrote when the museum can't be reached" do
    allow(Raindown::Rijksmuseum).to receive(:new).and_return(museum)
    allow(museum).to receive(:painting_of).and_raise(Raindown::Rijksmuseum::Error, 'offline')
    expect(described_class.new.rewrite(written: ["*Misty Sea*\n", "Jan Toorop\n"])).to eq("*Misty Sea*\nJan Toorop")
  end

  it "asks the museum for the day's painting once, keeping it for the day" do
    2.times { expect(described_class.today(day:, museum:)).to eq(painting) }
    expect(museum).to have_received(:painting_of).with(day).once
  end

  it 'asks again the next day' do
    described_class.today(day:, museum:)
    described_class.today(day: day + 1, museum:)
    expect(museum).to have_received(:painting_of).twice
  end

  it "renders the day's painting with its caption, linking to it" do
    described_class.today(day: Date.today, museum:)
    expect(described_class.new.render).to eq(
      '<figure class="painting"><img src="https://iiif.micr.io/mPymb/full/!1200,1200/0/default.jpg" ' \
      'alt="Misty Sea, Jan Toorop, 1899"><figcaption><a href="https://id.rijksmuseum.nl/200100988">' \
      'Misty Sea, Jan Toorop, 1899</a></figcaption></figure>'
    )
  end

  it "renders nothing when the museum can't be reached" do
    allow(Raindown::Rijksmuseum).to receive(:new).and_return(museum)
    allow(museum).to receive(:painting_of).and_raise(Raindown::Rijksmuseum::Error, 'offline')
    expect(described_class.new.render).to eq('')
  end
end
