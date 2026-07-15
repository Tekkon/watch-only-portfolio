# Watch-Only Crypto Portfolio — Implementation Plan

## 1. Goal & Scope

A **watch-only** crypto portfolio web app (Ruby on Rails) that aggregates balances
across watched addresses and renders a dashboard showing:

- **Overall balance in USD** (sum across all addresses, chains, wallet tokens + DeFi).
- **List of protocols** with money locked, showing **only non-zero balances**, sorted by USD desc.
- **Pie chart** of value distribution across **crypto assets** (BTC, ETH, SOL, stablecoins, …).

It supports **three ways to view a portfolio**:
1. **Connect a browser wallet** (MetaMask, Rabby, Trust, etc.) → the connected address's portfolio is shown **by default** on landing. No account required.
2. **View any address** via a public route **`/:address`** → anyone can look up any address's portfolio.
3. **Register / sign in** (email via Devise, Google/Apple OAuth, or wallet sign-in) → a user **manages a saved list of addresses** and sees their **aggregated** portfolio.

### Decisions locked in (from Q&A)
| Topic | Decision |
|---|---|
| Chains | **EVM** (ETH, Arbitrum, Base, …) + **Bitcoin** + **Solana** |
| Wallets | **Multi-user.** Anon quick-view (connected wallet / `/:address`) + registered users who save & manage their own address list |
| Auth | **Devise** — email/password + **OmniAuth Google & Apple** + optional **wallet sign-in (SIWE)** |
| Refresh | **On-demand + background cache** — serve cached data, refresh when stale / via background job |
| Data source | Plan for **DeBank**, but keep it **swappable** behind an adapter interface |

### Non-goals (v1)
- No trading / transactions / signing of *transactions* (watch-only — wallet is used only for read + optional login signature).
- No historical time-series charts (can be a later phase; DeBank exposes `total_net_curve` if wanted).

---

## 2. Architecture Overview

```
                    ┌───────────────────────────────────────────┐
   Browser  ─────►  │  Rails app                                 │
   (Dashboard,      │                                            │
    Hotwire/        │  Controllers → Query objects → DB (cache)  │
    Turbo)          │                        ▲                   │
                    │                        │ writes            │
                    │            ┌───────────┴───────────┐       │
                    │            │  RefreshPortfolioJob   │       │
                    │            │  (Sidekiq/Solid Queue) │       │
                    │            └───────────┬───────────┘       │
                    │                        │                   │
                    │        DataSource adapters (swappable):    │
                    │   ┌──────────┬──────────────┬───────────┐  │
                    │   │ DeBank   │ Bitcoin      │ Solana    │  │
                    │   │ (EVM)    │ (explorer)   │ (Zerion/  │  │
                    │   │          │              │ CoinStats)│  │
                    │   └────┬─────┴──────┬───────┴─────┬─────┘  │
                    └────────┼────────────┼─────────────┼────────┘
                             ▼            ▼             ▼
                       pro-openapi   BTC explorer   Solana portfolio API
                       .debank.com   (mempool/      (+ CoinGecko for
                                      blockstream)    any missing prices)
```

**Core idea:** a normalized internal model (Assets & Positions in USD) that every adapter
maps into. The dashboard reads only from the DB; adapters + jobs keep the DB fresh.

---

## 3. Data Sources (researched July 2026)

### 3.1 DeBank Cloud Open API — EVM (primary DeFi source)
- Base URL: `https://pro-openapi.debank.com/v1`
- Auth: **`AccessKey` header** (prepaid **units**; each call spends units).
- Endpoints we use:
  - `GET /user/total_balance?id={address}` → `total_usd_value`, `chain_list[]` (`id`, `name`, `usd_value`). Also returns wallet token USD.
  - `GET /user/all_complex_protocol_list?id={address}` → array of protocols: `id`, `name`, `chain`, `logo_url`, `portfolio_item_list[]` each with `stats.net_usd_value` (+ `asset_token_list` for underlying assets).
  - `GET /user/all_token_list?id={address}` → wallet-held (non-protocol) tokens with `amount`, `price`, `symbol`, `chain` — needed for the per-asset pie chart.
  - `GET /account/units` → remaining unit budget (surface in an admin/health view; log low-balance warnings).
- Docs: https://docs.cloud.debank.com/en/readme/api-pro-reference/user

### 3.2 Bitcoin (native BTC — DeBank does not cover)
- Use a free explorer API: **mempool.space** (`https://mempool.space/api/address/{addr}`) or **Blockstream** (`https://blockstream.info/api/address/{addr}`) for confirmed balance in sats.
- Price BTC via **CoinGecko** (`/simple/price?ids=bitcoin&vs_currencies=usd`).
- No DeFi positions for native BTC — it's a single wallet asset.

### 3.3 Solana (DeBank support limited/none)
- Use **Zerion API** (Solana wallet portfolio + DeFi positions) or **CoinStats API** (free tier ~20k credits/mo, resolves per-wallet Solana DeFi positions). Pick one adapter; keep both swappable.
- Fallback for plain token balances: Solana RPC + **CoinGecko** for pricing.

### 3.4 Pricing fallback
- **CoinGecko** as the canonical price oracle for any asset an adapter returns without a USD price (BTC, some SPL tokens). Cache prices briefly.

> All external base URLs, keys, and rate limits live in a single `config/data_sources.yml` +
> Rails credentials, so swapping providers never touches business logic.

---

## 4. The Adapter Abstraction (swappability)

A single Ruby interface every provider implements. The refresh job iterates watched
addresses, routes each to the adapter(s) for its chain family, and merges normalized results.

```ruby
# app/services/data_sources/base.rb
module DataSources
  class Base
    # address: Address record. Returns a normalized DataSources::Result.
    def fetch(address) = raise NotImplementedError
  end

  # Normalized value objects returned by EVERY adapter:
  Result   = Struct.new(:total_usd, :assets, :protocols, keyword_init: true)
  AssetBal = Struct.new(:symbol, :chain, :amount, :usd_value, keyword_init: true)
  Position = Struct.new(:protocol_id, :protocol_name, :chain, :logo_url, :usd_value, keyword_init: true)
end
```

Adapters: `DataSources::Debank` (EVM), `DataSources::Bitcoin`, `DataSources::Solana`.
A `DataSources::Registry` maps a chain family → adapter, so adding a chain = adding one class.
Every adapter is unit-tested against **recorded fixtures** (VCR) so we never spend live units in tests.

---

## 5. Data Model (ActiveRecord)

```
users                                 # Devise
  - id
  - email            (string, unique; nullable if wallet-only signup)
  - encrypted_password
  - name             (string, nullable)
  - primary_wallet   (string, nullable)   # address used for wallet sign-in
  - + Devise cols (reset/remember/confirmable/etc.)
  - timestamps

identities                            # OmniAuth links (Google, Apple, wallet/SIWE)
  - id
  - user_id          (fk)
  - provider         (enum: google_oauth2, apple, ethereum)  # ethereum = SIWE
  - uid              (string)          # OAuth sub, or checksummed 0x address for SIWE
  - index [provider, uid] unique
  - timestamps

siwe_nonces                           # short-lived nonces for wallet sign-in (anti-replay)
  - id
  - nonce            (string, unique)
  - address          (string, nullable) # bound once issued to a connect attempt
  - expires_at       (datetime)
  - consumed_at      (datetime, nullable)
  - timestamps

# An address is a chain address that can be watched. Owned addresses belong to a
# user's saved list; ad-hoc (/:address, connected-wallet quick view) addresses are
# ownerless and shared/cached so lookups are cheap and don't multiply snapshots.
addresses
  - id
  - user_id          (fk, nullable)    # null = ad-hoc / public lookup (not in anyone's list)
  - label            (string, nullable — e.g. "Main ETH wallet")
  - address          (string, indexed)
  - chain_family     (enum: evm, bitcoin, solana)   # routes to adapter
  - active           (boolean, default true)
  - last_synced_at   (datetime, nullable)
  - index [user_id, address, chain_family] unique   # no dup in a user's list
  - timestamps

# Cached snapshot per address per refresh (drives the dashboard):
portfolio_snapshots
  - id
  - address_id       (fk)
  - total_usd        (decimal)
  - fetched_at       (datetime)
  - raw_payload      (jsonb)          # optional: store raw provider response for debugging
  - timestamps

asset_balances                        # for the pie chart (per-asset aggregation)
  - id
  - portfolio_snapshot_id (fk)
  - symbol           (string)          # BTC, ETH, SOL, USDC…
  - chain            (string)
  - amount           (decimal)
  - usd_value        (decimal)
  - timestamps

protocol_positions                    # for the protocol list
  - id
  - portfolio_snapshot_id (fk)
  - protocol_id      (string)          # provider protocol id
  - name             (string)
  - chain            (string)
  - logo_url         (string, nullable)
  - usd_value        (decimal)
  - timestamps
```

**Query objects** (read side, DB only):
- `Dashboard::TotalBalance` → sum of latest snapshots' `total_usd`.
- `Dashboard::ProtocolBreakdown` → protocol positions across latest snapshots, **`usd_value > 0`**, grouped by protocol, sorted desc.
- `Dashboard::AssetAllocation` → asset balances grouped by `symbol`, summed, as `{symbol, usd, pct}` for the pie.

> Snapshots make refresh atomic (build a new snapshot, then point "latest" at it) and give
> free history if we later want time-series. "Latest snapshot per address" via a scope/`distinct on`.

> **Shared cache across ownership:** balances are a property of the *(address, chain_family)* pair,
> not of who saved it. So the refresh/cache layer keys on the normalized address string. A user's
> saved address and an anonymous `/:address` lookup of the same address hit the **same** cached
> snapshot — we don't refetch or store twice. Practically: snapshots can hang off a canonical
> address record (dedupe `addresses` by `[address, chain_family]` for the fetch, while a user's
> list is a join/label on top). Keeps DeBank unit spend down.

---

## 6. Refresh Strategy (on-demand + background cache)

- **Staleness threshold**: e.g. 10 min (configurable). `Address#stale?` = `last_synced_at` older than threshold.
- **On page load**: dashboard renders immediately from cached snapshots. If any address is stale,
  enqueue `RefreshPortfolioJob` (non-blocking) and show a "refreshing…" indicator via Turbo Stream;
  the dashboard updates live when the job broadcasts completion.
- **Background schedule**: a recurring job (Solid Queue recurring / sidekiq-cron) refreshes all
  active addresses every N minutes, so the cache is usually warm.
- **Unit safety**: batch/de-dupe calls; respect DeBank unit budget; exponential backoff + circuit
  breaker per adapter so one failing provider doesn't blank the whole dashboard (serve last-known-good).
- **Manual refresh**: a "Refresh now" button enqueues the job for all addresses.

Job library: **Solid Queue** (Rails 8 default, no Redis) unless you prefer Sidekiq. Recommend Solid Queue.

---

## 7. Authentication & Wallet Connect

Two independent capabilities that happen to both involve a wallet — keep them separate:

### 7.1 Connect wallet to VIEW (no account) — the default landing experience
- A **"Connect Wallet"** button uses the injected EIP-1193 provider (`window.ethereum`) so MetaMask / Rabby / Trust / any browser wallet works. A Stimulus controller calls `eth_requestAccounts`, gets the address, and **redirects to `/:address`** — no signature, no server auth.
- This is just a convenience shortcut to the public viewer. On landing, if a wallet is already connected we render its portfolio **by default**; otherwise show a connect button + an address search box.
- Solana wallets (Phantom) can be added the same way via `window.solana` (later phase; EVM first).

### 7.2 Accounts & sign-in (Devise) — for saving/managing an address list
- **Devise** with modules: `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`, `confirmable`, `omniauthable`.
- **Email/password** standard registration.
- **OmniAuth Google** — `omniauth-google-oauth2`.
- **OmniAuth Apple** — `omniauth-apple` (Sign in with Apple; needs Apple Developer key/team/service ID + JWT client secret). Apple quirks to plan for: only returns name/email on **first** authorization, and requires the private-key-signed client secret — budget a bit of extra setup here.
- OAuth callbacks resolve/create a `User` + `Identity`, matching on verified email when possible so a user who signed up by email can later link Google/Apple.

### 7.3 Wallet SIGN-IN (SIWE) — optional, wallet as an identity
Distinct from 7.1: this actually **logs you in** so a wallet can own a saved address list without email.
- Flow (EIP-4361 "Sign-In with Ethereum"):
  1. Client requests a **nonce** → server issues a fresh cryptographically-random nonce (`siwe_nonces`), bound to the connect attempt, short TTL.
  2. Wallet signs a standard SIWE message (domain, address, chain id, nonce, issued-at/expiry) via `personal_sign`.
  3. Server verifies the signature with **`ecrecover`** (Ruby: the `eth`/`siwe` gem, or `eth` for `Eth::Signature.personal_recover`), checks recovered address == claimed, **domain + nonce match**, not expired, nonce **not already consumed**; then marks the nonce consumed and signs the user in via a Devise session, creating a `User` + `Identity(provider: ethereum, uid: checksummed address)` on first use.
- Security: unique per-attempt nonce (anti-replay), verify `domain`/`chainId`, honor expiry. **Never** treat "wallet connected" (7.1) as authenticated — only a verified signature (7.3) authenticates.

### 7.4 Authorization
- Anonymous: can hit `/` and `/:address` (public viewer) only.
- Authenticated: can additionally manage **their own** addresses; scope every write to `current_user`. A user can only edit addresses where `user_id == current_user.id`.

---

## 8. Routes & UI / Frontend

### Routes
```
root              "portfolios#landing"       # connected-wallet portfolio by default, else connect/search
GET  /dashboard    -> user's aggregated saved-address portfolio   (auth required)
resources :addresses                          # manage saved list                (auth required)
devise_for :users  (+ omniauth callbacks: google_oauth2, apple)
POST /siwe/nonce   -> issue nonce             # wallet sign-in (7.3)
POST /siwe/verify  -> verify signature, sign in
GET  /:address     -> "portfolios#show"       # PUBLIC viewer for any address  (LAST route — catch-all)
```
> `/:address` is a greedy catch-all, so it must be declared **last** and constrained
> (`constraints: { address: /0x[0-9a-fA-F]{40}|[a-km-zA-HJ-NP-Z1-9]{26,44}/ }` for EVM/BTC/Solana forms)
> so it doesn't swallow `/dashboard`, `/addresses`, `/users`, etc. Also handle **ENS/`.eth` names**
> here later (resolve → address) if wanted.

### UI
- **Rails 8 + Hotwire (Turbo + Stimulus)**, server-rendered. No SPA.
- **Landing (`/`)**: Connect-Wallet button (Stimulus + `window.ethereum`) + address search. If a wallet is connected, render its portfolio inline (redirect to `/:address`).
- **Public portfolio (`/:address`)** and **user dashboard (`/dashboard`)** share the same portfolio partials:
  - Big **total USD** header.
  - **Protocol list** partial (Turbo Frame) — non-zero only, logo + name + chain + USD.
  - **Asset pie chart** — a Stimulus controller wrapping **Chart.js** (via importmap), fed by `AssetAllocation` JSON.
  - Dashboard aggregates across all of the user's saved addresses; `/:address` shows a single address.
- **Addresses management** (`/addresses`, auth): CRUD to add/remove/label saved addresses, pick chain family, toggle active. "Add the wallet I'm connected with" shortcut.
- **Auth pages**: Devise views + "Continue with Google / Apple / Wallet" buttons.
- Turbo Streams broadcast snapshot updates so the dashboard live-refreshes after a job completes.
- Styling: Tailwind (Rails 8 `tailwindcss-rails`) — light, no design system needed for v1.

---

## 9. Security / Config

- **Watch-only**: never store private keys or seed phrases. Only public addresses. Wallet interaction is limited to reading the address (7.1) and an optional login **signature** (7.3) — we never request transaction signing. Make this explicit in README + validations (reject anything that looks like a key).
- **SIWE**: fresh per-attempt nonce, single-use (consumed), TTL-bounded; verify domain + chain id + expiry; constant-time nonce lookup. Prevents replay / cross-site signature reuse.
- **OAuth**: store only provider `uid` + verified email; Apple client secret (signed JWT) generated from the Apple private key held in credentials, never committed.
- **Public `/:address`**: input-validate & normalize the address; rate-limit the endpoint (e.g. `rack-attack`) so it can't be used to burn DeBank units or as an SSRF/enumeration vector.
- **Authorization**: all address writes scoped to `current_user`; anonymous users are read-only on the public viewer.
- API keys (DeBank AccessKey, Solana provider key, CoinGecko, Google/Apple OAuth) in **Rails credentials** / ENV — never committed.
- Rate-limit outbound calls; add `Faraday` with retry + timeout middleware.

---

## 10. Tech Stack Summary

| Concern | Choice |
|---|---|
| Framework | Rails 8, Ruby 3.3+ |
| DB | PostgreSQL (jsonb for raw payloads) |
| Auth | **Devise** + `omniauth-google-oauth2` + `omniauth-apple` |
| Wallet sign-in | SIWE (EIP-4361) — `eth` / `siwe` gem for `ecrecover` verification |
| Wallet connect (client) | injected EIP-1193 (`window.ethereum`) via Stimulus |
| Jobs | Solid Queue (recurring for scheduled refresh) |
| Realtime | Turbo Streams (Solid Cable) |
| HTTP client | Faraday (+ retry/timeout) |
| Rate limiting | rack-attack (protect `/:address`, siwe endpoints) |
| Charts | Chart.js via importmap + Stimulus |
| CSS | Tailwind |
| Testing | RSpec/Minitest + VCR + WebMock for adapters |
| Local run | **Docker Compose** — `web`, `worker`, `db` (+ optional `redis`) |

---

## 11. Local Dev with Docker Compose

Run everything locally with `docker compose up`. Services:

| Service | Image / build | Role |
|---|---|---|
| **`db`** | `postgres:16` | PostgreSQL. Named volume for data; healthcheck gates the app. |
| **`web`** | build `./Dockerfile` | Rails app (`bin/rails server -b 0.0.0.0`), port `3000:3000`. |
| **`worker`** | same image as `web` | **Solid Queue** worker (`bin/jobs`) — runs background + recurring refresh jobs. Same code, different command. |
| **`redis`** | `redis:7` | **Only if we switch to Sidekiq.** With Solid Queue it's not needed (queue lives in Postgres). Listed as optional. |

> **Why no separate "queue" service by default:** Solid Queue stores jobs in **Postgres**, so
> the "queue" is just another process (`worker`) against the same `db` — not a broker container.
> Solid Cable (Turbo Stream broadcasts) also uses Postgres. If we pick **Sidekiq** instead (open
> question #1), add the `redis` service and point both `web` and `worker` at it.

### Dockerfile
- Base the app image on the **Dockerfile that Rails 8 generates** (`rails new` ships a production `Dockerfile`). For local dev we add a lightweight target/compose override that mounts the source for live reload and installs dev gems. Multi-stage: build (gems + assets) → slim runtime.
- Node/Yarn not required (importmap + `tailwindcss-rails` ships a standalone binary), keeping the image small.

### compose.yaml (shape)
```yaml
services:
  db:
    image: postgres:16
    environment: { POSTGRES_USER: app, POSTGRES_PASSWORD: app, POSTGRES_DB: watch_only_dev }
    volumes: [ "pgdata:/var/lib/postgresql/data" ]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U app"], interval: 5s, retries: 10 }
    ports: [ "5432:5432" ]

  web:
    build: .
    command: ./bin/rails server -b 0.0.0.0 -p 3000
    env_file: [ .env ]                 # DATABASE_URL, DEBANK_ACCESS_KEY, OAuth keys, etc.
    volumes: [ ".:/rails" ]            # dev live-reload (dev override only)
    ports: [ "3000:3000" ]
    depends_on: { db: { condition: service_healthy } }

  worker:
    build: .
    command: ./bin/jobs               # Solid Queue supervisor
    env_file: [ .env ]
    volumes: [ ".:/rails" ]
    depends_on: { db: { condition: service_healthy } }

  # redis:                            # ONLY if switching to Sidekiq
  #   image: redis:7
  #   ports: [ "6379:6379" ]

volumes: { pgdata: {} }
```

### Conventions
- **`DATABASE_URL`** points `web`/`worker` at the `db` service (`postgres://app:app@db:5432/watch_only_dev`).
- Secrets & API keys via **`.env`** (git-ignored) → env vars; `.env.example` committed as a template.
- First-run: `docker compose run --rm web ./bin/rails db:prepare` (or an entrypoint that runs `db:prepare` before boot).
- `bin/dev`-style convenience: a short README section with `docker compose up` / `run --rm web bin/rails c` / `run --rm web bin/rails test`.
- Keep a plain **non-Docker** path working too (some devs prefer local Ruby); Docker is the documented default.

---

## 12. Milestones (incremental, each shippable)

1. ✅ **Skeleton + Docker** — `rails new` (Postgres, Tailwind, importmap, Solid Queue). `compose.yaml` with `db`/`web`/`worker`, `.env.example`, `db:prepare` on boot (via `bin/docker-entrypoint-dev`). Address model (`chain_family` enum + watch-only key/seed guardrail + `[address, chain_family]` unique index). Seeds 3 public addresses. `docker compose up` boots web on **:3001**; worker processes Solid Queue jobs; verified end-to-end. *No external calls yet.*
2. ✅ **DeBank EVM adapter** — `total_balance`, `all_complex_protocol_list`, `all_token_list` behind the adapter interface (`DataSources::Base`/`Debank`/`HttpClient`/`Registry`), config in `config/data_sources.yml`. Normalize → snapshot models (`portfolio_snapshots`/`asset_balances`/`protocol_positions`) via `PortfolioRefresher` (atomic snapshot writer). Manual `portfolio:refresh` rake task. **RSpec** + VCR fixtures (AccessKey scrubbed, `record: :none`); 8 examples, 0 failures. *Cassette data is hand-authored — re-record against a real address once `DEBANK_ACCESS_KEY` is available.*
3. ✅ **Public viewer + dashboard read side** — query objects (`Dashboard::TotalBalance`/`ProtocolBreakdown`/`AssetAllocation`) + shared portfolio partials (`portfolios/_total`/`_protocols`/`_asset_chart`/`_portfolio`); **`/:address`** public route (constrained to EVM/base58, declared last); `PortfoliosController#show` reads cached snapshots only; total USD, non-zero protocol list, asset pie (Chart.js via importmap + `asset_chart` Stimulus controller). Empty state for never-synced/ad-hoc lookups. **FactoryBot** factories; **RSpec** query + request specs; 24 examples, 0 failures. *Test env forced to the test DB in `rails_helper` (Compose exports `RAILS_ENV=development`); dropped `DATABASE_URL` in favor of discrete `POSTGRES_*` host/port/user/password keys in database.yml so each env picks its own database (dev/test never collide).*
4. ✅ **Connect Wallet (view)** — `root "portfolios#landing"` with a Connect-Wallet button + address search box. `wallet_connect` Stimulus controller drives the injected EIP-1193 provider (`window.ethereum`): silently redirects to the already-authorized wallet's `/:address` on load (connected wallet shown by default, plan §7.1), or `eth_requestAccounts` on button click; reveals button/divider only when a provider exists; surfaces reject (4001)/no-account errors. Search box → `GET /lookup` normalizes + redirects to `/:address`, or bounces to landing with a flash for unrecognized input. Layout gains a header + flash region. **RSpec** request specs (landing + lookup normalize/trim/invalid); 29 examples, 0 failures.
5. **Background refresh** — `RefreshPortfolioJob`, shared-cache keying, staleness check on page load, recurring schedule, Turbo Stream live update.
6. **Auth — Devise** — email/password registration + `confirmable`. Then **Google & Apple OAuth**. User model + identities.
7. **Saved address list** — `/addresses` CRUD scoped to `current_user`; `/dashboard` aggregates a user's addresses; "add my connected wallet" shortcut.
8. **Wallet sign-in (SIWE)** — nonce issue/verify endpoints, `ecrecover`, Identity(provider: ethereum), Devise session.
9. **Bitcoin adapter** — explorer balance + CoinGecko pricing.
10. **Solana adapter** — Zerion or CoinStats; DeFi positions + tokens.
11. **Hardening** — circuit breaker / last-known-good, unit-budget monitoring, rack-attack rate limits, error surfacing, README.

---

## 13. Open Questions / To Confirm Before Coding

1. **Job/queue**: OK with **Solid Queue** (Rails 8 default, no Redis → no separate queue container, just a `worker`), or do you want **Sidekiq** (adds a `redis` service)?
2. **Solana provider**: **Zerion** or **CoinStats** for the Solana adapter? (Both have free tiers; I'll pick CoinStats unless you prefer Zerion.)
3. **BTC explorer**: **mempool.space** vs **Blockstream** — either is fine; default mempool.space.
4. **Wallet sign-in (SIWE)**: do you want it in v1, or start with just email + Google/Apple and add SIWE later? (Connect-wallet-to-*view* is in v1 regardless.)
5. **Apple sign-in**: confirm you have (or will set up) an **Apple Developer** account — it's required for the Service ID + private key. If not, we ship Google first and add Apple later.
6. **Email confirmation**: turn on Devise `confirmable` (needs an outbound mailer/SMTP), or skip email verification for v1?
7. **Deployment target** (affects OAuth callback URLs + scheduling): local only, a VPS, Fly.io/Render, or undecided?
8. **Staleness window**: default 10 min acceptable, or do you want fresher/cheaper?

---

*Sources:* DeBank Cloud API docs (docs.cloud.debank.com), mempool.space / Blockstream explorer APIs,
Zerion & CoinStats Solana portfolio APIs, CoinGecko price API, SIWE / EIP-4361 (docs.login.xyz,
spruceid/siwe), Devise + omniauth-google-oauth2 / omniauth-apple. Researched 2026-07-14.
