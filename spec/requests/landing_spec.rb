require "rails_helper"

RSpec.describe "Landing and address lookup", type: :request do
  describe "GET / (landing)" do
    it "renders the connect + search entry point" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Connect Wallet")
      expect(response.body).to include("wallet-connect") # Stimulus controller wired
      expect(response.body).to include("/lookup")         # search box target
    end
  end

  describe "GET /lookup" do
    it "normalizes an EVM address and redirects to its viewer (downcased)" do
      get "/lookup", params: { address: "0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045" }

      expect(response).to redirect_to("/0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
    end

    it "redirects a base58 (Bitcoin) address unchanged" do
      get "/lookup", params: { address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa" }

      expect(response).to redirect_to("/1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
    end

    it "trims surrounding whitespace before redirecting" do
      get "/lookup", params: { address: "  0x#{'a' * 40}  " }

      expect(response).to redirect_to("/0x#{'a' * 40}")
    end

    it "bounces unrecognized input back to landing with an alert" do
      get "/lookup", params: { address: "not-an-address" }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("doesn&#39;t look like")
    end
  end
end
