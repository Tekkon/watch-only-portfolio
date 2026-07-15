require "rails_helper"

RSpec.describe "Public portfolio viewer", type: :request do
  describe "GET /:address" do
    context "for a synced EVM address" do
      let(:address) { create(:address, address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045") }

      before do
        snapshot = create(:portfolio_snapshot, address: address, total_usd: BigDecimal("1234.56"))
        create(:asset_balance, portfolio_snapshot: snapshot, symbol: "ETH", usd_value: BigDecimal("1234.56"))
        create(:protocol_position, portfolio_snapshot: snapshot, name: "Aave V3", usd_value: BigDecimal("500"))
        address.update!(last_synced_at: snapshot.fetched_at)
      end

      it "renders the cached total, protocols, and assets" do
        get "/#{address.address}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Total balance")
        expect(response.body).to include("Aave V3")
        expect(response.body).to include("ETH")
      end

      it "looks up case-insensitively (normalizes EVM to downcase)" do
        get "/#{address.address.upcase.sub('0X', '0x')}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Total balance")
      end
    end

    context "for a valid but never-synced address" do
      it "shows an honest empty state rather than 404" do
        get "/0x#{'a' * 40}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No cached balance yet")
      end
    end

    context "for a string that isn't a recognizable address" do
      it "does not route to the viewer (constraint rejects it → 404)" do
        get "/not-an-address!"
        expect(response).to have_http_status(:not_found)
      end
    end

    it "does not swallow other top-level paths" do
      # /up is the Rails health route — the catch-all must be declared after it.
      get "/up"
      expect(response).to have_http_status(:ok)
    end
  end
end
