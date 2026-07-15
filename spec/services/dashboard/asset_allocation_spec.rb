require "rails_helper"

RSpec.describe Dashboard::AssetAllocation do
  subject(:allocation) { described_class.new(snapshots) }

  let(:snapshot) { create(:portfolio_snapshot) }
  let(:snapshots) { [ snapshot ] }

  describe "#slices" do
    it "groups by symbol, sums usd, and computes each share" do
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "ETH",  usd_value: BigDecimal("750"))
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "USDC", usd_value: BigDecimal("250"))

      slices = allocation.slices
      expect(slices.map(&:symbol)).to eq(%w[ETH USDC]) # sorted by usd desc
      expect(slices.first.usd_value).to eq(BigDecimal("750"))
      expect(slices.first.pct).to eq(75.0)
      expect(slices.last.pct).to eq(25.0)
    end

    it "sums the same symbol appearing on multiple chains" do
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "USDC", chain: "arb",  usd_value: BigDecimal("100"))
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "USDC", chain: "base", usd_value: BigDecimal("300"))

      expect(allocation.slices.map(&:usd_value)).to eq([ BigDecimal("400") ])
    end

    it "excludes zero-value assets" do
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "ETH", usd_value: BigDecimal("500"))
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "DUST", usd_value: BigDecimal("0"))

      expect(allocation.slices.map(&:symbol)).to eq(%w[ETH])
    end
  end

  describe "#to_chart_data" do
    it "shapes labels/values/percentages for the Stimulus chart" do
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "ETH",  usd_value: BigDecimal("750"))
      create(:asset_balance, portfolio_snapshot: snapshot, symbol: "USDC", usd_value: BigDecimal("250"))

      expect(allocation.to_chart_data).to eq(
        labels: %w[ETH USDC],
        values: [ 750.0, 250.0 ],
        percentages: [ 75.0, 25.0 ]
      )
    end
  end
end
