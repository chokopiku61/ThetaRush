# ThetaRush

Competitive programming site (Rails + Judge0 CE). Supported languages: Python and C++.

## Prerequisites

- Ruby (see `.ruby-version`)
- Docker Desktop (Postgres, Redis, Judge0)
- Bundler

## Quick start

```bash
bundle install
docker compose up -d          # Postgres (5433), Adminer (8089), Redis (6379)
bin/rails db:prepare
bin/rails db:seed             # A+B and Hello Name sample problems
bin/rails server
```

In another terminal:

```bash
bundle exec sidekiq
```

### Judge0 CE (for real verdicts)

```bash
docker compose -f docker-compose.judge0.yml up -d
```

Wait until `http://localhost:2358/about` responds, then submit a solution while Sidekiq and Rails are running.

Copy `.env.example` to `.env` if you need to override URLs or the webhook secret. Prefer `bin/rails server -b 0.0.0.0` so Judge0 callbacks via `host.docker.internal` can reach Rails. `JudgeSubmissionJob` also polls Judge0 if the webhook does not arrive.

On Docker Desktop (cgroup v2), Judge0 is configured to use isolate with setrlimit limits instead of cgroup (`--cg`), which avoids the `/box` internal error while keeping the isolate sandbox.

### Useful URLs

| Service | URL |
|---------|-----|
| App | http://localhost:3000 |
| Problems | http://localhost:3000/problems |
| Sidekiq Web (dev) | http://localhost:3000/sidekiq |
| Adminer | http://localhost:8089 |
| Judge0 | http://localhost:2358 |

### Import problems

Idempotent upsert from `db/seeds/problems/*.json`:

```bash
bin/rails db:seed
# or
bin/rails import:problems
```

## Notes

- Never run contestant code on the host; judging goes through Judge0 isolate.
- Contests, scoreboard scoring, and live updates are later milestone steps.
- Webhook auth is a shared secret suitable for local Judge0 only.
