module Dashboard
  # Grand total USD across a set of latest snapshots. For the public viewer this
  # is a single address's snapshot; for the user dashboard it's the latest
  # snapshot of each saved address, summed. Read-only — DB values only.
  #
  #   Dashboard::TotalBalance.new(snapshots).usd  # => BigDecimal
  class TotalBalance
    def initialize(snapshots)
      @snapshots = Array(snapshots).compact
    end

    def usd
      @snapshots.sum(BigDecimal(0)) { |s| s.total_usd || BigDecimal(0) }
    end
  end
end
