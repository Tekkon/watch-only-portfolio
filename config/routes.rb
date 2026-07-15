Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Landing: Connect-Wallet button (client-side redirect to /:address) + an
  # address search box. No account required — the default public entry point.
  root "portfolios#landing"

  # Address search box submits here; we normalize + redirect to the /:address
  # viewer (or back to landing with an error for an unrecognized address).
  get "/lookup", to: "portfolios#lookup", as: :lookup

  # PUBLIC watch-only viewer for any address. Greedy catch-all → declared LAST
  # and constrained to EVM (0x + 40 hex) / Bitcoin·Solana (base58) forms so it
  # can't swallow /dashboard, /addresses, /users, etc. (added later milestones).
  # Keep the constraint in sync with Address::EVM_FORMAT / BASE58_FORMAT.
  get "/:address", to: "portfolios#show",
    as: :portfolio,
    constraints: { address: /0x[0-9a-fA-F]{40}|[1-9A-HJ-NP-Za-km-z]{26,44}/ }
end
