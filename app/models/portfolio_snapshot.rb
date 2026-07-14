# A cached, point-in-time balance for one address. Each refresh writes a NEW
# snapshot; the dashboard reads the latest one. Snapshots make refresh atomic
# (build fully, then it becomes "latest") and give free history for later.
class PortfolioSnapshot < ApplicationRecord
  belongs_to :address
  has_many :asset_balances, dependent: :destroy
  has_many :protocol_positions, dependent: :destroy

  validates :total_usd, presence: true
  validates :fetched_at, presence: true

  # Newest first — `address.portfolio_snapshots.latest.first` is the cache read.
  scope :latest, -> { order(fetched_at: :desc) }
end
