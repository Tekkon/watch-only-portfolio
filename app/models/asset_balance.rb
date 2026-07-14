# One wallet-held asset within a snapshot (BTC, ETH, USDC…). Feeds the per-asset
# pie chart via Dashboard::AssetAllocation (later milestone).
class AssetBalance < ApplicationRecord
  belongs_to :portfolio_snapshot

  validates :symbol, presence: true
end
