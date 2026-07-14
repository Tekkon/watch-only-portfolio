# Manual refresh for Milestone 2 — pull live balances into a snapshot. The
# background job/schedule (Milestone 5) will do this automatically; for now it's
# a hand-run command to exercise the DeBank adapter against a real address.
#
#   bin/rails portfolio:refresh                 # all active EVM addresses
#   bin/rails "portfolio:refresh_address[0xabc…]" # one address by string
#
# Requires DEBANK_ACCESS_KEY (spends prepaid units). No key -> a clear error.
namespace :portfolio do
  desc "Refresh cached snapshots for all active addresses with a supported adapter"
  task refresh: :environment do
    addresses = Address.active.select { |a| DataSources::Registry.supports?(a.chain_family) }
    if addresses.empty?
      puts "No active addresses with a supported adapter."
      next
    end

    addresses.each { |address| refresh_one(address) }
  end

  desc "Refresh a single address by its address string"
  task :refresh_address, [ :address ] => :environment do |_t, args|
    raise "Usage: bin/rails 'portfolio:refresh_address[0x…]'" if args[:address].blank?

    address = Address.find_by!(address: args[:address])
    refresh_one(address)
  end
end

def refresh_one(address)
  snapshot = PortfolioRefresher.call(address)
  puts "✓ #{address.label || address.address} (#{address.chain_family}) — " \
       "$#{snapshot.total_usd.to_f.round(2)}, " \
       "#{snapshot.asset_balances.size} assets, #{snapshot.protocol_positions.size} protocols"
rescue DataSources::MissingCredentialError => e
  abort "✗ #{e.message} — set DEBANK_ACCESS_KEY to fetch live data."
rescue => e
  warn "✗ #{address.address}: #{e.class} #{e.message}"
end
