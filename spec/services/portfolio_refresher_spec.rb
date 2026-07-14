require "rails_helper"

RSpec.describe PortfolioRefresher do
  let(:address) do
    Address.create!(address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045", chain_family: :evm)
  end

  let(:result) do
    DataSources::Result.new(
      total_usd: BigDecimal("1250.5"),
      assets: [
        DataSources::AssetBal.new(symbol: "ETH", chain: "eth", amount: BigDecimal("0.5"), usd_value: BigDecimal("1000.0")),
        DataSources::AssetBal.new(symbol: "USDC", chain: "arb", amount: BigDecimal("250"), usd_value: BigDecimal("250.0"))
      ],
      protocols: [
        DataSources::Position.new(protocol_id: "aave3", protocol_name: "Aave V3", chain: "arb", logo_url: "x", usd_value: BigDecimal("600.25"))
      ]
    )
  end

  # A stand-in adapter so the refresher spec never touches HTTP.
  let(:adapter) { instance_double(DataSources::Debank, fetch: result) }

  it "persists a snapshot with its assets and protocols" do
    expect {
      described_class.call(address, adapter: adapter)
    }.to change(PortfolioSnapshot, :count).by(1)
      .and change(AssetBalance, :count).by(2)
      .and change(ProtocolPosition, :count).by(1)

    snapshot = address.latest_snapshot
    expect(snapshot.total_usd).to eq(BigDecimal("1250.5"))
    expect(snapshot.asset_balances.pluck(:symbol)).to match_array(%w[ETH USDC])
    expect(snapshot.protocol_positions.first.name).to eq("Aave V3")
  end

  it "stamps last_synced_at so the address is no longer stale" do
    expect(address).to be_stale
    described_class.call(address, adapter: adapter)
    expect(address.reload).not_to be_stale
  end

  it "is atomic: a write failure leaves no snapshot behind" do
    allow(adapter).to receive(:fetch).and_return(
      DataSources::Result.new(
        total_usd: BigDecimal("1"),
        protocols: [ DataSources::Position.new(protocol_id: nil, usd_value: BigDecimal("1")) ] # invalid: protocol_id required
      )
    )

    expect {
      expect { described_class.call(address, adapter: adapter) }.to raise_error(ActiveRecord::RecordInvalid)
    }.not_to change(PortfolioSnapshot, :count)
    expect(address.reload.last_synced_at).to be_nil
  end
end
