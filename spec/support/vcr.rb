require "vcr"
require "webmock/rspec"

# Record & replay external HTTP so adapter specs never spend live DeBank units.
# Cassettes live in spec/fixtures/vcr_cassettes. Any real HTTP that isn't already
# recorded raises — specs can't silently depend on the network.
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: :none } # CI never records; use :once locally to capture new ones
  # Scrub the AccessKey so no real key is ever committed inside a cassette.
  config.filter_sensitive_data("<DEBANK_ACCESS_KEY>") { ENV["DEBANK_ACCESS_KEY"] }
  config.configure_rspec_metadata! # opt-in per example with `vcr: "cassette_name"`
end
