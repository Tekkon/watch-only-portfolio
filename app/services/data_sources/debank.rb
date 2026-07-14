module DataSources
  # EVM adapter backed by the DeBank Cloud Open API.
  # Docs: https://docs.cloud.debank.com/en/readme/api-pro-reference/user
  #
  # Combines three endpoints into one normalized Result:
  #   - /user/total_balance          -> grand total USD (wallet tokens + DeFi)
  #   - /user/all_token_list         -> wallet-held tokens (the pie chart)
  #   - /user/all_complex_protocol_list -> DeFi positions (the protocol list)
  #
  # Auth is the prepaid `AccessKey` header — each call spends units, so tests
  # replay VCR cassettes and never hit the wire.
  class Debank < Base
    def initialize(client: nil, config: DataSources.config(:debank))
      @config = config
      @client = client || default_client
    end

    def fetch(address)
      id = address.address

      total     = @client.get("/user/total_balance", id: id)
      tokens    = @client.get("/user/all_token_list", id: id)
      protocols = @client.get("/user/all_complex_protocol_list", id: id)

      Result.new(
        total_usd: to_d(total["total_usd_value"]),
        assets: normalize_assets(tokens),
        protocols: normalize_protocols(protocols)
      )
    end

    private

    def default_client
      raise MissingCredentialError, "DEBANK_ACCESS_KEY is not set" if @config.access_key.blank?

      HttpClient.new(
        base_url: @config.base_url,
        headers: { "AccessKey" => @config.access_key, "Accept" => "application/json" },
        open_timeout: @config.open_timeout,
        timeout: @config.timeout,
        max_retries: @config.max_retries
      )
    end

    # all_token_list -> wallet-held tokens. usd_value = amount * price.
    def normalize_assets(tokens)
      Array(tokens).filter_map do |t|
        amount = to_d(t["amount"])
        price  = to_d(t["price"])
        usd    = amount * price
        next if usd.zero? # only assets that carry value reach the pie chart

        AssetBal.new(
          symbol: t["symbol"],
          chain: t["chain"],
          amount: amount,
          usd_value: usd
        )
      end
    end

    # all_complex_protocol_list -> one Position per protocol, summing the USD
    # across its portfolio items (supply/reward/farm/…). Non-zero only.
    def normalize_protocols(protocols)
      Array(protocols).filter_map do |p|
        usd = Array(p["portfolio_item_list"]).sum { |item| to_d(item.dig("stats", "net_usd_value")) }
        next if usd.zero?

        Position.new(
          protocol_id: p["id"],
          protocol_name: p["name"],
          chain: p["chain"],
          logo_url: p["logo_url"],
          usd_value: usd
        )
      end
    end

    # DeBank returns floats; convert to BigDecimal so USD math stays exact.
    def to_d(value)
      return BigDecimal(0) if value.nil?

      BigDecimal(value.to_s)
    end
  end
end
