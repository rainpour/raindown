# frozen_string_literal: true

require 'raindown/yjit'

RSpec.describe Raindown::Yjit do
  it "allows YJIT outside a macOS binary, where Ruby's own build decides" do
    expect(described_class.allowed?).to be(true)
  end
end
