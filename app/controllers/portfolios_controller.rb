class PortfoliosController < ApplicationController
  # Landing (root): Connect-Wallet button + address search box. If the browser
  # already has a wallet connected, a Stimulus controller redirects to its
  # /:address on load; otherwise the user connects or searches. No server state.
  def landing
  end

  # Address search box target. Normalizes the submitted address and redirects to
  # the public viewer, or back to landing with a flash for unrecognized input.
  def lookup
    raw = params[:address].to_s.strip
    chain_family = Address.chain_family_for(raw)

    if chain_family.nil?
      redirect_to root_path, alert: "#{raw.presence || 'That'} doesn't look like an EVM, Bitcoin, or Solana address."
    else
      redirect_to portfolio_path(Address.normalize(raw, chain_family))
    end
  end

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
