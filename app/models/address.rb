class Address < ApplicationRecord
  # Routes an address to the right data-source adapter. See the plan's adapter
  # registry (DataSources::Registry) — added in a later milestone.
  enum :chain_family, { evm: 0, bitcoin: 1, solana: 2 }

  has_many :portfolio_snapshots, dependent: :destroy

  # How long a cached balance is considered fresh before a refresh is enqueued.
  STALENESS_WINDOW = 10.minutes

  validates :address, presence: true
  validates :chain_family, presence: true
  validates :address, uniqueness: { scope: :chain_family, case_sensitive: false }

  # Watch-only guardrail: never accept anything that looks like a private key or
  # seed phrase. Only public addresses belong here.
  validate :must_not_look_like_secret

  scope :active, -> { where(active: true) }

  def stale?
    last_synced_at.nil? || last_synced_at < STALENESS_WINDOW.ago
  end

  # Most recent cached balance, or nil if this address has never been synced.
  def latest_snapshot
    portfolio_snapshots.latest.first
  end

  private

  def must_not_look_like_secret
    return if address.blank?

    # 64-hex-char private key, or a >=12-word mnemonic.
    if address.match?(/\A(0x)?[0-9a-f]{64}\z/i)
      errors.add(:address, "looks like a private key — only public addresses are allowed")
    elsif address.strip.split(/\s+/).size >= 12
      errors.add(:address, "looks like a seed phrase — only public addresses are allowed")
    end
  end
end
