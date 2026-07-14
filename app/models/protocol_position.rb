# Money locked in one DeFi protocol within a snapshot. Feeds the protocol list
# (non-zero only, sorted by USD desc) via Dashboard::ProtocolBreakdown (later).
class ProtocolPosition < ApplicationRecord
  belongs_to :portfolio_snapshot

  validates :protocol_id, presence: true
end
