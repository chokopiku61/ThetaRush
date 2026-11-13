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

## Tests

Run the full automated suite with:

```bash
bin/rails test
```

The test environment uses the `:test` Active Job adapter and PostgreSQL. It does not require Redis, Sidekiq, Docker Judge0, or network access to a judge. The submission judging integration tests replace the Judge0 HTTP transport with an in-process fake and still exercise the real job, result aggregation, persistence, and rendered responses. Run that flow alone with:

```bash
bin/rails test test/integration/submission_judging_flow_test.rb
```

For a real Judge0 end-to-end run, start PostgreSQL and Redis with `docker compose up -d`, start Rails and Sidekiq in separate terminals, then start Judge0 with `docker compose -f docker-compose.judge0.yml up -d`. Follow the manual happy path below. No contestant code is run on the Rails host.

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

## Live scoreboard (Milestone 7)

The contest scoreboard is the live page. Signed-in viewers subscribe through `ScoreboardChannel` to automatic Turbo Stream updates after terminal submission verdicts. Guests can view standings and use **Refresh scoreboard**. The link refreshes only the scoreboard Turbo Frame with JavaScript enabled and loads the scoreboard page without JavaScript. The subscription stays outside the frame.

Refresh manually after reconnecting to recover missed updates, after new registrations, and after final recalculation. Registration and finalization do not broadcast. Verdict scoring remains the only scoreboard broadcast trigger.

### Step 7.3 acceptance results, 2026-11-13

Verified against the running development Rails server on port 3000, Sidekiq, Redis, PostgreSQL, Solid Cable, and real Docker Judge0 CE 1.13.1. Two independent signed-in cookie sessions used `localhost` (user 7) and `127.0.0.1` (user 8). Dedicated contests 2 and 3 isolated these checks from existing contest data.

- User 8 submitted Python WA (#46), then AC (#47), through the problem editor and Submit button. Judge0 judged all three test cases for each submission. The other session's already-open scoreboard updated without navigation or manual refresh: user 8 became rank 1 with 1 solve and 31 penalty minutes (11 elapsed + 20 for WA); user 7 became rank 2 with 0 solves and 0 penalty. WA alone contributed no penalty.
- User 7 submitted C++ AC (#48), also through the editor and real Sidekiq/Judge0 path. The connected scoreboard updated to user 7 at rank 1, 1 solve, 13 penalty, and user 8 at rank 2, 1 solve, 31 penalty. Contest 3's open scoreboard stayed at 0 solves and 0 penalty for both users throughout.
- To exercise a missed update, user 8 viewed the scoreboard through a temporary second Rails process on port 3001. Stopping only that process disconnected its Cable subscription before #48 was submitted. The page kept its old standings while the connected viewer received #48's update. After restarting the temporary process, the subscription reconnected but the rows remained stale. Clicking **Refresh scoreboard** recovered the correct standings through the frame. Exactly one connected subscription remained, outside the frame.
- After logout, the guest scoreboard displayed the same standings, no subscription, and working manual refresh. EN/RU guidance and refresh labels were checked in the browser. Keyboard activation with Enter also refreshed the signed-in frame and retained one connected subscription. Rails logs confirmed frame-layout responses.
- Final automated verification: `ruby bin/rails test` passed with 87 tests, 701 assertions, no failures, errors, or skips. This includes frame recovery for guests and signed-in viewers, EN/RU copy, stream isolation, scoring, and the existing no-broadcast registration/finalization checks. `ruby bin/rubocop --cache-root tmp/rubocop_cache test/controllers/contests_controller_test.rb` and `git diff --check` passed. Ruby emitted existing non-fatal optional libvips module warnings.

The temporary port 3001 process was stopped after acceptance; the original services were left running. Acceptance accounts, contests, submissions, and ignored `tmp/m73_*` scripts/logs were retained because cleanup requires approval. Existing uncommitted assets and runtime files were preserved.

Additional layout spot checks used 360, 768, and 1440 CSS pixel viewports, then restored the default viewport. At 360 pixels the existing sidebar rail overlapped the left edge of the content and the table needed horizontal scrolling. Broad responsive/frontend acceptance remains for the later steps; no sidebar or editor refactoring was included in 7.3.

## Notes

- Never run contestant code on the host; judging goes through Judge0 isolate.
- Contest standings update live for signed-in viewers after terminal verdict scoring; manual refresh is available to everyone.
- Webhook auth is a shared secret suitable for local Judge0 only.
