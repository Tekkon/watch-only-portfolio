module DataSources
  # Maps a chain family -> adapter, so adding a chain is adding one class + one
  # entry here. Bitcoin/Solana adapters land in later milestones.
  module Registry
    ADAPTERS = {
      "evm" => -> { Debank.new }
      # "bitcoin" => -> { Bitcoin.new },   # Milestone 9
      # "solana"  => -> { Solana.new },    # Milestone 10
    }.freeze

    module_function

    # Returns a fresh adapter instance for the given Address, or raises if that
    # chain family has no adapter yet.
    def for(address)
      builder = ADAPTERS.fetch(address.chain_family) do
        raise NotImplementedError, "No data source adapter for chain_family=#{address.chain_family.inspect}"
      end
      builder.call
    end

    def supports?(chain_family)
      ADAPTERS.key?(chain_family.to_s)
    end
  end
end
