# Watch-Only Crypto Portfolio

A watch-only crypto portfolio: aggregate balances across watched addresses (EVM,
Bitcoin, Solana) and show total USD, non-zero DeFi protocol positions, and an
asset-allocation pie chart. See the implementation plan in
[`.claude/plans/watch-only-portfolio.md`](.claude/plans/watch-only-portfolio.md).

## Stack

Rails 8 · PostgreSQL · Solid Queue (jobs) · Hotwire · Tailwind · importmap.

## Local development (Docker Compose)

Everything runs in containers — you don't need Ruby or Postgres on the host.

```bash
cp .env.example .env          # then edit if any host ports clash
docker compose up             # builds images, prepares the DB, starts everything
```

Services:

| Service  | What it is                                   | Host port |
|----------|----------------------------------------------|-----------|
| `web`    | Rails app                                    | 3001 → 3000 |
| `worker` | Solid Queue worker (`bin/jobs`)              | —         |
| `db`     | PostgreSQL 16 (data in the `pgdata` volume)  | 5433 → 5432 |

Then open **http://localhost:3001**. Health check: `GET /up`.

> Ports are configurable via `WEB_HOST_PORT` / `DB_HOST_PORT` in `.env` (defaults
> 3001 / 5433, chosen to avoid clashing with other local projects).
> There is no separate queue broker — Solid Queue stores jobs in Postgres, so the
> worker is just another process against `db`.

### Common commands

```bash
docker compose up -d                       # start in background
docker compose logs -f web                 # tail web logs
docker compose exec web bin/rails console  # Rails console
docker compose exec web bin/rails db:seed  # (re)seed watch-only addresses
docker compose down                        # stop (keeps the db volume)
docker compose down -v                     # stop and wipe the db volume
```

The database is created, migrated, and seeded automatically on `web` boot
(`bin/docker-entrypoint-dev` runs `db:prepare`).

## Configuration

App config and secrets live in `.env` (git-ignored; see `.env.example`).
External API keys (DeBank, CoinGecko, Solana provider, Google/Apple OAuth) are
added in later milestones and can be left blank for now.
