module DataSources
  # The interface every provider adapter implements. Given an Address, return a
  # normalized Result the snapshot writer can persist without knowing the source.
  class Base
    # @param address [Address]
    # @return [DataSources::Result]
    def fetch(address)
      raise NotImplementedError, "#{self.class} must implement #fetch(address)"
    end
  end

  # Normalized value objects returned by EVERY adapter. Keeping these provider-
  # agnostic is what makes the sources swappable.
  #
  #   total_usd : BigDecimal — grand total across wallet tokens + protocols
  #   assets    : [AssetBal] — wallet-held tokens, for the per-asset pie chart
  #   protocols : [Position] — DeFi positions, for the protocol list
  Result = Struct.new(:total_usd, :assets, :protocols, keyword_init: true) do
    def initialize(total_usd: 0, assets: [], protocols: [])
      super(total_usd: total_usd, assets: assets, protocols: protocols)
    end
  end

  AssetBal = Struct.new(:symbol, :chain, :amount, :usd_value, keyword_init: true)
  Position = Struct.new(:protocol_id, :protocol_name, :chain, :logo_url, :usd_value, keyword_init: true)
end
