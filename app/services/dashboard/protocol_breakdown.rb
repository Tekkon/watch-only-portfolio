module Dashboard
  # Protocol positions across a set of latest snapshots, for the protocol list.
  # Non-zero only, grouped by protocol (so the same protocol seen on multiple
  # addresses collapses into one row), sorted by USD desc. Read-only.
  #
  #   Dashboard::ProtocolBreakdown.new(snapshots).rows
  #   # => [#<Row protocol_id:, name:, chain:, logo_url:, usd_value:>, ...]
  class ProtocolBreakdown
    Row = Struct.new(:protocol_id, :name, :chain, :logo_url, :usd_value, keyword_init: true)

    def initialize(snapshots)
      @snapshots = Array(snapshots).compact
    end

    def rows
      positions
        .group_by { |p| [ p.protocol_id, p.chain ] }
        .map { |(_key), group| build_row(group) }
        .select { |row| row.usd_value.positive? }
        .sort_by { |row| -row.usd_value }
    end

    private

    def positions
      @snapshots.flat_map(&:protocol_positions)
    end

    def build_row(group)
      first = group.first
      Row.new(
        protocol_id: first.protocol_id,
        name: first.name,
        chain: first.chain,
        logo_url: first.logo_url,
        usd_value: group.sum(BigDecimal(0)) { |p| p.usd_value || BigDecimal(0) }
      )
    end
  end
end
