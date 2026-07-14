require "rails_helper"

RSpec.describe DataSources::Debank do
  let(:address) do
    Address.new(address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045", chain_family: :evm)
  end

  around do |example|
    previous = ENV["DEBANK_ACCESS_KEY"]
    ENV["DEBANK_ACCESS_KEY"] = "test-key" # so the adapter builds its client; VCR replays
    DataSources.reset_config!
    example.run
    ENV["DEBANK_ACCESS_KEY"] = previous
    DataSources.reset_config!
  end

  describe "#fetch", vcr: "debank_vitalik" do
    subject(:result) { described_class.new.fetch(address) }

    it "returns a normalized Result with the grand total" do
      expect(result).to be_a(DataSources::Result)
      expect(result.total_usd).to eq(BigDecimal("1250.5"))
    end

    it "computes asset usd as amount * price and drops zero-value tokens" do
      expect(result.assets.map(&:symbol)).to eq(%w[ETH USDC]) # SCAM (price 0) filtered

      eth = result.assets.find { |a| a.symbol == "ETH" }
      expect(eth.usd_value).to eq(BigDecimal("1000.0")) # 0.5 * 2000
      expect(eth.chain).to eq("eth")
    end

    it "sums a protocol's portfolio items and drops zero-value protocols" do
      expect(result.protocols.size).to eq(1) # Empty Protocol (0.0) filtered

      aave = result.protocols.first
      expect(aave).to have_attributes(
        protocol_id: "aave3",
        protocol_name: "Aave V3",
        chain: "arb",
        logo_url: "https://static.debank.com/aave.png",
        usd_value: BigDecimal("600.25") # 500.0 + 100.25
      )
    end
  end

  describe "error handling" do
    it "raises MissingCredentialError when no access key is configured" do
      ENV["DEBANK_ACCESS_KEY"] = nil
      DataSources.reset_config!

      expect { described_class.new }.to raise_error(DataSources::MissingCredentialError)
    end

    it "wraps provider HTTP errors in ProviderError" do
      stub_request(:get, /pro-openapi\.debank\.com/).to_return(status: 500, body: "boom")

      expect { described_class.new.fetch(address) }
        .to raise_error(DataSources::ProviderError, /HTTP 500/)
    end
  end
end
