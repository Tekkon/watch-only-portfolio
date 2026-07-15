class PortfoliosController < ApplicationController
  # Public, watch-only viewer for any address: GET /:address.
  # Reads only from cached snapshots (query objects) — no external calls here;
  # keeping the cache warm is the refresh job's job (Milestone 5).
  def show
    raw = params[:address]
    chain_family = Address.chain_family_for(raw)

    if chain_family.nil?
      return render :invalid_address, status: :unprocessable_entity, locals: { raw: raw }
    end

    normalized = Address.normalize(raw, chain_family)
    @address = Address.find_by(address: normalized, chain_family: chain_family)

    # Ad-hoc lookup of an address nobody has watched yet: nothing cached to show.
    # The snapshot gets populated once the refresh job runs (Milestone 5).
    snapshots = Array(@address&.latest_snapshot)

    @raw_address = raw
    @chain_family = chain_family
    @total = Dashboard::TotalBalance.new(snapshots).usd
    @protocols = Dashboard::ProtocolBreakdown.new(snapshots).rows
    @allocation = Dashboard::AssetAllocation.new(snapshots)
    @synced_at = @address&.last_synced_at
  end
end
