require "rails_helper"

RSpec.describe Dashboard::ProtocolBreakdown do
  subject(:rows) { described_class.new(snapshots).rows }

  let(:snapshot) { create(:portfolio_snapshot) }
  let(:snapshots) { [ snapshot ] }

  it "excludes zero-value positions" do
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "aave3", usd_value: BigDecimal("500"))
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "empty", usd_value: BigDecimal("0"))

    expect(rows.map(&:protocol_id)).to eq(%w[aave3])
  end

  it "sorts by usd_value descending" do
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "small", usd_value: BigDecimal("100"))
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "big",   usd_value: BigDecimal("900"))

    expect(rows.map(&:protocol_id)).to eq(%w[big small])
  end

  context "with the same protocol+chain across two snapshots" do
    let(:other) { create(:portfolio_snapshot) }
    let(:snapshots) { [ snapshot, other ] }

    before do
      create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "aave3", chain: "arb", name: "Aave V3", usd_value: BigDecimal("300"))
      create(:protocol_position, portfolio_snapshot: other,    protocol_id: "aave3", chain: "arb", name: "Aave V3", usd_value: BigDecimal("200"))
    end

    it "collapses into one summed row" do
      expect(rows.size).to eq(1)
      expect(rows.first.usd_value).to eq(BigDecimal("500"))
    end
  end

  it "keeps the same protocol on different chains as separate rows" do
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "aave3", chain: "arb", usd_value: BigDecimal("300"))
    create(:protocol_position, portfolio_snapshot: snapshot, protocol_id: "aave3", chain: "base", usd_value: BigDecimal("200"))

    expect(rows.size).to eq(2)
  end
end
