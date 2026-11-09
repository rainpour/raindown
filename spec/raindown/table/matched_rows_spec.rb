# frozen_string_literal: true

require 'raindown/table/matched_rows'

RSpec.describe Raindown::MatchedRows do
  def file_rows(table, file)
    described_class.new(table.length, file.length) { |row, file_row| table[row] == file[file_row] }.file_rows
  end

  it 'matches rows after one added or removed to the rows they were' do
    expect(file_rows(%w[h a new b total], %w[h a b total])).to eq([0, 1, nil, 2, 3])
    expect(file_rows(%w[h b total], %w[h a b total])).to eq([0, 2, 3])
  end

  it 'pairs an edited row with the row it was, with rows added and edited far apart' do
    expect(file_rows(%w[h new a b c edited total], %w[h a b c d total])).to eq([0, nil, 1, 2, 3, 4, 5])
  end
end
