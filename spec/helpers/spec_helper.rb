# frozen_string_literal: true

# A response for stubbing Raindown::Curl.run, a 200 that took 142 milliseconds unless it says otherwise.
module CurlResponses
  def curl_response(body, language = 'json', status: 200)
    Raindown::Curl::Response.new(body:, language:, status:, milliseconds: 142)
  end
end

RSpec.configure do |config|
  config.include CurlResponses

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    # Large diff when expected objects don't match.
    expectations.max_formatted_output_length = 10_000
  end

  # The terminal UI's workers answer in the spec's process, so its stubs apply, unless an example is tagged fork: true.
  config.before do |example|
    Raindown::Workers::Worker.fork = example.metadata[:fork] == true if defined?(Raindown::Workers::Worker)
  end
end
