# Fetches an address's balance via its chain adapter and persists it as a new
# PortfolioSnapshot (with asset balances + protocol positions). One refresh =
# one atomic snapshot: we build it fully inside a transaction, then it becomes
# the "latest" the dashboard reads. On success we stamp Address#last_synced_at.
#
#   PortfolioRefresher.call(address)  # => PortfolioSnapshot
#
# The adapter is injected for tests; production resolves it from the Registry.
class PortfolioRefresher
  def self.call(address, adapter: nil)
    new(address, adapter: adapter).call
  end

  def initialize(address, adapter: nil)
    @address = address
    @adapter = adapter || DataSources::Registry.for(address)
  end

  def call
    result = @adapter.fetch(@address)
    persist(result)
  end

  private

  def persist(result)
    ActiveRecord::Base.transaction do
      snapshot = @address.portfolio_snapshots.create!(
        total_usd: result.total_usd,
        fetched_at: Time.current
      )

      write_assets(snapshot, result.assets)
      write_protocols(snapshot, result.protocols)

      @address.update!(last_synced_at: snapshot.fetched_at)
      snapshot
    end
  end

  def write_assets(snapshot, assets)
    Array(assets).each do |a|
      snapshot.asset_balances.create!(
        symbol: a.symbol,
        chain: a.chain,
        amount: a.amount,
        usd_value: a.usd_value
      )
    end
  end

  def write_protocols(snapshot, protocols)
    Array(protocols).each do |p|
      snapshot.protocol_positions.create!(
        protocol_id: p.protocol_id,
        name: p.protocol_name,
        chain: p.chain,
        logo_url: p.logo_url,
        usd_value: p.usd_value
      )
    end
  end
end
