require "rails_helper"

RSpec.describe Dashboard::TotalBalance do
  subject(:usd) { described_class.new(snapshots).usd }

  context "with several snapshots" do
    let(:snapshots) do
      [
        create(:portfolio_snapshot, total_usd: BigDecimal("1200.50")),
        create(:portfolio_snapshot, total_usd: BigDecimal("300.25"))
      ]
    end

    it "sums their total_usd" do
      expect(usd).to eq(BigDecimal("1500.75"))
    end
  end

  context "with a single snapshot (not an array)" do
    let(:snapshots) { create(:portfolio_snapshot, total_usd: BigDecimal("42")) }

    it "sums it" do
      expect(usd).to eq(BigDecimal("42"))
    end
  end

  context "with no snapshots" do
    let(:snapshots) { [] }

    it "is zero" do
      expect(usd).to eq(0)
    end
  end
end
