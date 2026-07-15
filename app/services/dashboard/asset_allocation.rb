module Dashboard
  # Per-asset value distribution across a set of latest snapshots, for the pie
  # chart. Asset balances grouped by symbol (BTC, ETH, USDC…), summed, non-zero
  # only, sorted by USD desc, each carrying its share of the total. Read-only.
  #
  #   Dashboard::AssetAllocation.new(snapshots).slices
  #   # => [#<Slice symbol: "ETH", usd_value:, pct: 62.5>, ...]
  class AssetAllocation
    Slice = Struct.new(:symbol, :usd_value, :pct, keyword_init: true)

    def initialize(snapshots)
      @snapshots = Array(snapshots).compact
    end

    def slices
      total = total_usd
      grouped
        .map { |symbol, group| build_slice(symbol, group, total) }
        .select { |slice| slice.usd_value.positive? }
        .sort_by { |slice| -slice.usd_value }
    end

    # Shape the pie chart's Stimulus controller consumes as JSON.
    def to_chart_data
      s = slices
      {
        labels: s.map(&:symbol),
        values: s.map { |slice| slice.usd_value.to_f },
        percentages: s.map { |slice| slice.pct }
      }
    end

    private

    def balances
      @snapshots.flat_map(&:asset_balances)
    end

    def grouped
      balances.group_by(&:symbol)
    end

    def total_usd
      balances.sum(BigDecimal(0)) { |b| b.usd_value || BigDecimal(0) }
    end

    def build_slice(symbol, group, total)
      usd = group.sum(BigDecimal(0)) { |b| b.usd_value || BigDecimal(0) }
      pct = total.positive? ? (usd / total * 100).to_f.round(2) : 0.0
      Slice.new(symbol: symbol, usd_value: usd, pct: pct)
    end
  end
end
