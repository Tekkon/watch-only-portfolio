# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# A few well-known PUBLIC addresses to exercise the dashboard once adapters land.
# All are public/watch-only — no keys, ever.
seed_addresses = [
  { label: "vitalik.eth",     address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045", chain_family: :evm },
  { label: "Ethereum Foundation", address: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe", chain_family: :evm },
  { label: "Bitcoin genesis", address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",            chain_family: :bitcoin },
]

seed_addresses.each do |attrs|
  Address.find_or_create_by!(address: attrs[:address], chain_family: attrs[:chain_family]) do |a|
    a.label = attrs[:label]
  end
end

puts "Seeded #{Address.count} watch-only addresses."
