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
bin/rails db:seed             # Sample problems and a running demo contest
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
| Contests | http://localhost:3000/contests |
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

## Manual happy path

Walked through on a local stack: Postgres and Redis from `docker compose`, Judge0 from `docker-compose.judge0.yml`, Rails bound to `0.0.0.0`, and Sidekiq. `bin/rails db:seed` loads A + B, Hello Name, and a running "ThetaRush Demo Contest". Seeding again resets that contest to a new running window.

1. Register two users. A contest with one participant writes a history row and leaves the rating unchanged.
2. As the first user, open **A + B** and submit the Python sample (`a, b = map(int, input().split())` then `print(a + b)`). Refresh the submission page until the verdict is AC.
3. Open the demo contest, register, open **A + B** from the contest problem list, and submit the same solution. Verdict AC. This submission is what the scoreboard counts.
4. Log out. Register the second user, join the same contest, and submit a wrong solution (for example `print(0)`). Verdict WA.
5. Open the scoreboard and refresh. The first user is rank 1 with 1 solve. The second user is rank 2 with 0 solves and 0 penalty. A wrong attempt adds penalty only after that problem is accepted.
6. End the contest, then finalize. The Finalize button is on the contest page for an admin, and only after `ends_at` is in the past.
   - `bundle exec rails runner "User.find_by!(email: 'you@example.com').update!(admin: true)"`
   - In Admin, edit the demo contest and set **Ends at** to a time after the contest submissions and already in the past. An end time before those submissions drops them from the standings.
   - On the contest page, click **Finalize contest**.
7. Open each profile. The higher place gains rating and the lower place loses it. Both pages list a rating history row for the contest.

Guests can read problems and the scoreboard. Submitting and registering require a signed-in user.

## Notes

- Never run contestant code on the host; judging goes through Judge0 isolate.
- Contest standings update after each terminal verdict and refresh with the scoreboard page.
- Live scoreboard updates are planned for Milestone 7.
- Webhook auth is a shared secret suitable for local Judge0 only.
