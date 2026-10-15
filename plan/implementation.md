# ThetaRush: agent implementation plan

Session-sized playbook for building ThetaRush. Source of truth: [architecture.md](architecture.md), [milestones.md](milestones.md), [AGENTS.md](../AGENTS.md).

## How to use this plan

1. Work milestones **strictly in order** (M1 then M2, and so on). Do not skip ahead.
2. **One step = one agent session.** Finish the step, verify it, stop. Start the next step in a new session.
3. Before coding, re-read this step's **Goal**, **Touch**, **Verify**, and **Do not**.
4. Comments, commit messages, and branch names are in English ([AGENTS.md](../AGENTS.md)).
5. Never run untrusted user submissions on the host. Do not weaken Judge0 sandbox limits. Do not edit expected test outputs just to make tests pass.
6. Install dependencies locally in the project, not globally. Do not modify system configs or secrets without asking.
7. Ask before irreversible actions (drop DB, force push, delete data).
8. After a step is finished and verified, edit this file and change that step's `[ ]` to `[x]` (heading and Suggested session order row) before ending the session.

## Component wiring map

Connect architecture pieces only when a milestone requires them.

| Component | First milestone | Notes |
|-----------|-----------------|--------|
| Spec docs, screen diagram, stack, pitfalls | M1 | Docs only |
| Rails app, PostgreSQL, Hotwire | M2 | Bootstrap |
| Devise (auth, sessions) | M2 | |
| UI kit and placeholder screens | M3 | Markup/styles; fake data OK |
| Full DB schema, models, validations, associations | M4 | |
| `Contests::Scoring`, `Ratings::Calculator` (pure Ruby) | M4 | Unit-tested logic only; no jobs/HTTP |
| Seeds / `Problems::Importer` / rake import | M5 | Minimal fixtures enough for happy path |
| Redis, Sidekiq, `JudgeSubmissionJob` | M5 | |
| Judge0 CE, `Judge0Client`, webhook | M5 | |
| Contests UI, scoring on verdict, scoreboard (page refresh) | M5 | |
| `FinalizeContestJob`, `UpdateRatingsJob`, profile rating | M5 | Wire rating jobs here |
| Administrate (thin admin) | M5 | Only as needed to operate happy path |
| `GenerateDailyContestsJob` / sidekiq-cron | M5 | Optional if seeded contests already work |
| System / integration tests | M6 | Prefer stubbing Judge0 in CI |
| ActionCable + Turbo Streams live scoreboard | M7 | Not before M7 |

**Out-of-order bans**

- No Judge0, Sidekiq, or judging HTTP before M5.
- No ActionCable / Turbo Streams live updates before M7.
- No skipping M1-M4 to "get judging working."
- Rating **calculator** may exist in M4; rating **jobs and profile wiring** only in M5.
- M5 scoreboard may full-page refresh; live updates are M7.

---

## Milestone 1: Project specification

Deadline context: see [milestones.md](milestones.md). Deliverable is documentation that names the product, screens, stack, and risks. No application code.

### [x] Step 1.1 - Topic name and description

**Goal:** Write the project topic name and a short product description for ThetaRush (competitive programming site: problems, contests, submissions, rating).

**Touch:**
- `plan/spec.md` (create), or a clearly named section file under `plan/` if `spec.md` already exists with other content
- Cross-link from this plan only if needed; do not rewrite architecture

**Verify:**
- File states the project name, one-paragraph description, and core user goals (solve problems, join contests, see results/rating)
- Readable by someone unfamiliar with the repo

**Do not:**
- Scaffold Rails or install gems
- Mention implementation details as if already built
- Skip to auth, models, or Judge0

### [x] Step 1.2 - Screen diagram with transitions

**Goal:** Document the main screens and navigation transitions (guest vs logged-in).

**Touch:**
- `plan/spec.md` (or `plan/screens.md`) with a Mermaid `flowchart` / `stateDiagram` of screens
- Screens to include at minimum: home/landing, sign up, sign in, problem catalog, problem show + submit, contests list, contest show + register, scoreboard, profile, UI kit page (for M3)

**Verify:**
- Diagram shows transitions (e.g. catalog -> problem -> submit -> result; contest -> scoreboard; auth flows)
- Guest-only vs authenticated routes are clear

**Do not:**
- Build the screens in Rails
- Add ActionCable or live-update notes as if implemented
- Design admin-only flows in detail (optional stub box is enough)

### [x] Step 1.3 - Technology stack (frontend and overall)

**Goal:** Record the stack aligned with [architecture.md](architecture.md), with explicit frontend choices.

**Touch:**
- `plan/spec.md` (stack section)
- Frontend: Hotwire (Turbo + Stimulus), server-rendered HTML, CSS (approach TBD in M3, e.g. CSS variables + custom styles)
- Backend/infra as planned: Rails, Devise, PostgreSQL, Redis, Sidekiq (+ sidekiq-cron later), Judge0 CE (Docker), Administrate, ActionCable (M7)

**Verify:**
- Stack list matches architecture names and languages (Python and C++ for judging)
- Frontend subsection is explicit (not only "Rails")

**Do not:**
- Install or pin gems yet
- Choose a SPA framework that contradicts Hotwire architecture
- Start Docker/Judge0 setup

### [x] Step 1.4 - Pitfalls

**Goal:** Document risks: datasets, Judge0/ops, scoring, rating, sandbox security.

**Touch:**
- `plan/spec.md` (pitfalls section)
- Cover at least: problem dataset quality/licensing; Judge0 CE ops and callbacks; ICPC scoring/penalty edge cases; Elo/rating updates; never running untrusted code on the host; webhook authenticity/network exposure in local dev

**Verify:**
- Pitfalls are concrete and actionable for later milestones
- Sandbox rule from AGENTS.md is reflected

**Do not:**
- Implement mitigations in code
- Weaken planned sandbox limits "for convenience"
- Jump to M2 before M1 checklist in milestones can be marked done

**Milestone 1 done when:** topic, screen diagram, stack, and pitfalls are written and reviewable.

---

## Milestone 2: Authorization + registration

Greenfield: create the Rails app, then Devise. No problems/contests/judging yet.

### [x] Step 2.1 - Bootstrap Rails application

**Goal:** Create a Rails app in this repo with PostgreSQL and Hotwire defaults (not API-only).

**Touch:**
- App root files: `Gemfile`, `config/`, `app/`, `bin/rails`, `db/`, etc. (generated in project root or agreed subdir; prefer project root so `plan/` stays sibling docs)
- Database config for PostgreSQL (development/test)
- Local bundler install only

**Verify:**
- `bin/rails about` (or equivalent) runs
- `bin/rails db:prepare` succeeds against local PostgreSQL
- Root page or default welcome loads in browser
- Hotwire (Turbo/Stimulus) is present in the default stack

**Do not:**
- Add Devise yet (next step)
- Add Sidekiq, Redis app wiring, Judge0, or contest models
- Install gems globally
- Commit secrets or real credentials

### [x] Step 2.2 - Devise User model

**Goal:** Add Devise with a `User` model and run migrations.

**Touch:**
- `Gemfile` (devise)
- `config/initializers/devise.rb`, routes for Devise
- `app/models/user.rb`
- Migration for users (email/password Devise fields)
- Optional: minimal `username` or `display_name` only if needed for later UI; keep schema lean

**Verify:**
- Migrations run cleanly
- User can be created in Rails console with valid email/password
- Devise routes appear in `bin/rails routes`

**Do not:**
- Build problems/submissions schema
- Add rating fields beyond a simple nullable `rating` integer if you must; prefer deferring rating columns to M4 if unsure
- Customize Devise mailer extensively

### [x] Step 2.3 - Login, registration, session UI

**Goal:** Sign up, sign in, sign out; layout shows logged-in vs guest; session survives refresh.

**Touch:**
- Devise views (generate and restyle lightly if needed)
- Application layout: nav with Register / Log in (guest) or email/name + Log out (signed in)
- A simple authenticated landing or home that proves session state
- CSRF and Devise session cookie defaults (no JWT)

**Verify:**
- Register a user in the browser
- Refresh: still logged in
- Log out: session ends; protected flash/redirect works
- Guest sees logged-out chrome

**Do not:**
- Build UI kit page (M3)
- Add OAuth
- Add Sidekiq/Judge0
- Harden every edge validation beyond Devise defaults unless trivial

**Milestone 2 done when:** milestones checklist for auth/registration/session can be satisfied manually.

---

## Milestone 3: UI Kit

Show markup and styles for core competitive-programming UI. Separate kit page and/or placeholder product screens. No real judging backend.

### [ ] Step 3.1 - Base layout and design tokens

**Goal:** Establish shared layout, CSS variables, and typography for the product look.

**Touch:**
- Layout partials / application layout
- CSS entry (e.g. `app/assets/stylesheets/` or Propshaft/CSS pipeline used by the app)
- CSS variables for color, type scale, spacing
- Avoid generic "AI default" looks called out in project frontend rules (no purple-on-white cliche as the brand)

**Verify:**
- Signed-in and guest layouts still work
- Tokens apply on a sample page without broken assets

**Do not:**
- Implement submission judging
- Add model schema for contests/problems (M4)
- Overbuild a design system library

### [ ] Step 3.2 - UI kit gallery page

**Goal:** A scrollable page showcasing buttons, forms, tables, status badges, and fonts used by core features.

**Touch:**
- Route + controller action for UI kit (e.g. `/ui_kit`)
- View with sections: buttons, text inputs, textarea (code), selects (language), tables, verdict badges (AC/WA/TLE/RE/queued), alerts, nav samples
- Link from nav or footer for reviewers (can be dev-only later; public is fine for course)

**Verify:**
- Visit the page and scroll through all element types
- Styles are consistent with Step 3.1

**Do not:**
- Wire forms to create real submissions
- Pull live data from Judge0
- Skip this page if only building placeholders (kit page is the milestone format)

### [ ] Step 3.3 - Placeholder core screens

**Goal:** Screens shaped like the final product, with placeholder/fake data: problem list/show, submit form, contest list/show, scoreboard, profile.

**Touch:**
- Static or controller actions returning fake data (hashes/OpenStruct), not full domain models
- Views using UI kit components: problem card, statement area, submit form (language + code), contest card, scoreboard table, profile header with rating placeholder
- Routes that match the screen diagram from M1 where practical

**Verify:**
- Click through placeholders as a logged-in user without server errors
- Submit form is present visually (POST can be no-op or flash "not implemented")

**Do not:**
- Introduce Sidekiq/Judge0
- Finalize DB schema (M4) unless a tiny stub table is unavoidable (prefer no DB)
- Implement ActionCable
- Perfect every validation branch

**Milestone 3 done when:** UI kit page is reviewable and core surfaces exist as placeholders.

---

## Milestone 4: Models and model tests

Database schema is mandatory. Models need validations, associations, and business logic. Tests focus on business logic (scoring, rating, submission state). No Judge0/Sidekiq wiring.

### [ ] Step 4.1 - Database schema migrations

**Goal:** Migrations for the architecture data model.

**Touch:**
- Migrations / schema for at least:
  - `users` extras needed for rating display (e.g. `rating`, `rating_deviation` or equivalent if using CF-style)
  - `problems` (title, statement, limits, rating/difficulty, etc.)
  - test data storage: ActiveStorage attachments and/or disk paths for stdin/expected outputs
  - `contests` (start/end, title, status)
  - `contest_problems` (join: contest, problem, index/letter)
  - contest registrations / participations
  - `submissions` (user, problem, optional contest, language, source, status/verdict, times, judge tokens as needed)
  - `rating_histories` (user, contest, old/new rating, etc.)
- `db/schema.rb` updated

**Verify:**
- `bin/rails db:migrate` on clean DB succeeds
- Schema matches architecture entities at a glance

**Do not:**
- Implement `Judge0Client` or jobs
- Call external APIs
- Put large binary datasets in git

### [ ] Step 4.2 - Models: associations and validations

**Goal:** ActiveRecord models with associations and validations for core integrity.

**Touch:**
- `app/models/user.rb`, `problem.rb`, `contest.rb`, `contest_problem.rb`, registration/participation model, `submission.rb`, `rating_history.rb`, and any test-case model
- Associations (`has_many` / `belongs_to`) per schema
- Validations: presence, uniqueness where needed, language inclusion (`python`, `cpp` or Judge0 language ids mapped later), submission status enum/string allowlist

**Verify:**
- Console: create related records with valid data; invalid records fail validations
- No missing inverse associations that will break M5

**Do not:**
- Enqueue jobs on `submission` create
- HTTP callbacks
- Administrate dashboards yet

### [ ] Step 4.3 - Contests::Scoring (pure logic)

**Goal:** ICPC-style points and penalty as a service object (or model methods), callable without HTTP.

**Touch:**
- `app/services/contests/scoring.rb` (or equivalent)
- Methods to apply a verdict to contest standings (solved count, penalty, first AC, wrong-attempt penalties)
- Persist standings fields on participation/join rows as designed in Step 4.1

**Verify:**
- From console or pending tests: sample AC/WA sequences produce expected penalty/solves
- No dependency on Judge0 or Redis

**Do not:**
- Broadcast ActionCable
- Schedule Sidekiq
- Implement Elo here

### [ ] Step 4.4 - Ratings::Calculator (pure logic)

**Goal:** Codeforces-style Elo (or clearly documented CF-like) rating update as pure Ruby.

**Touch:**
- `app/services/ratings/calculator.rb`
- Input: contestant ratings + ranks/scores; output: new ratings
- Optional helper to build `RatingHistory` attributes (not the job)

**Verify:**
- Deterministic examples in console: higher place gains rating vs lower place
- No DB side effects required inside pure calculate method (caller persists)

**Do not:**
- Add `UpdateRatingsJob` or cron
- Call Judge0
- Change sandbox policy

### [ ] Step 4.5 - Model / unit tests for business logic

**Goal:** Automated tests for business logic methods; aim for 2-3 test files with 2-3 contexts each.

**Touch:**
- Test files under `test/` or `spec/` (match whatever the Rails app uses)
- Focus: `Contests::Scoring`, `Ratings::Calculator`, submission status transitions / invariants
- Optional light tests for validations/associations
- Fixtures or factories for users/problems/contests

**Verify:**
- Test suite for these files passes (`bin/rails test` or `bundle exec rspec`)
- At least two files and multiple contexts covering scoring and rating

**Do not:**
- Write system tests for full HTTP happy path (M6)
- Stub Judge0 (not introduced yet)
- Skip business-logic tests in favor of only validation tests

**Milestone 4 done when:** schema, models, scoring/rating logic, and model tests exist without judging infrastructure.

---

## Milestone 5: User happy path

As a user, click through core functionality: browse problems, submit and get a verdict, join a contest, see scoreboard (refresh OK), see profile rating after finalize. Wire Sidekiq, Judge0, and rating jobs here. No live WebSocket scoreboard yet.

### [ ] Step 5.1 - Minimal problem data (seeds / importer)

**Goal:** Enough problems and tests in the DB to solve something end-to-end.

**Touch:**
- `db/seeds.rb` and/or `app/services/problems/importer.rb` + `lib/tasks/import.rake` (`rake import:problems`)
- Small fixture problems with stdin/expected pairs (Python/C++ solvable)
- Optional thin offline dump format; full Hugging Face pipeline is not required for happy path

**Verify:**
- `bin/rails db:seed` (or rake import) loads problems visible in console
- At least one trivial problem (e.g. A+B) with tests

**Do not:**
- Run user code on the host to "validate" tests
- Download huge datasets into the repo
- Start Judge0 yet (next steps)

### [ ] Step 5.2 - Problems catalog and show (read path)

**Goal:** Real `ProblemsController` listing and showing DB problems (replace placeholders).

**Touch:**
- `app/controllers/problems_controller.rb`
- Views for index/show (statement, limits, sample display if available)
- Routes; auth: browse may be public; submitting comes later

**Verify:**
- Browser: open catalog and a problem statement from seeded data
- No placeholder-only fake titles left on these actions

**Do not:**
- Accept submissions in this step (or keep submit button linking to not-yet-wired action)
- Add webhook/Judge0 client

### [ ] Step 5.3 - Redis, Sidekiq, JudgeSubmissionJob skeleton

**Goal:** Background job pipeline ready to enqueue submission judging.

**Touch:**
- Gems: `sidekiq`, Redis config
- `config/sidekiq.yml`, Sidekiq middleware/routes for Web UI optional
- `app/jobs/judge_submission_job.rb` (skeleton: load submission, log or no-op judge call)
- ActiveJob adapter set to Sidekiq
- Procfile or README note: how to run `sidekiq`

**Verify:**
- Redis running locally; Sidekiq process boots
- Enqueue job from console; job executes without crashing

**Do not:**
- Call real Judge0 API yet (Step 5.4)
- Add ActionCable
- Expose Sidekiq UI without auth in a deployable way (local OK)

### [ ] Step 5.4 - Judge0 CE + Judge0Client

**Goal:** Run Judge0 CE in Docker and send batch submissions (Python and C++) with limits and expected output.

**Touch:**
- `docker-compose.yml` (or documented compose) for Judge0 CE and its dependencies
- `app/services/judge0_client.rb`: create batch, map languages, pass stdin/expected_output/cpu/time/memory
- Config for Judge0 URL (local env pattern without committing secrets)
- Wire `JudgeSubmissionJob` to call `Judge0Client` (callback URL pointing at webhook from Step 5.5, or polling only if callback not ready in the same session - prefer finishing client + job call shape here)

**Verify:**
- Judge0 health endpoint responds
- Client can submit a known A+B solution and receive a successful path (via callback in 5.5 or temporary poll for this step only)
- Unsupported languages are rejected at app boundary

**Do not:**
- Run submissions with host Ruby/`system` instead of Judge0
- Weaken isolate/sandbox settings
- Implement live scoreboard cable

### [ ] Step 5.5 - SubmissionsController + Judge0WebhookController

**Goal:** User submits code; submission is `queued`; webhook persists verdict.

**Touch:**
- `app/controllers/submissions_controller.rb` (create; auth required)
- `app/controllers/judge0_webhook_controller.rb` (update submission status/stdout/stderr/time/memory/verdict)
- Views: submit form on problem show; submission show/status page (polling or refresh OK)
- Enqueue `JudgeSubmissionJob` on create
- Basic authenticity strategy for webhook suitable for local Judge0 (document risk from M1 pitfalls)

**Verify:**
- Logged-in user submits correct A+B -> eventual Accepted
- Wrong answer path shows WA (or equivalent)
- Guest cannot submit

**Do not:**
- Finalize contest rating jobs yet (later steps)
- Add Turbo Streams live updates (M7)
- Edit expected outputs to force green

### [ ] Step 5.6 - Contests: list, register, show

**Goal:** Contests happy path without requiring live generation cron.

**Touch:**
- `app/controllers/contests_controller.rb` (index, show, register)
- Seed or simple `Contests::Generator` to attach problems to one open contest
- Registration/participation records
- Contest problem list links to problems in contest context

**Verify:**
- User registers for a contest and sees its problems
- Second user can register too

**Do not:**
- Require sidekiq-cron for the demo if seeds suffice
- Build full admin UX before Step 5.9

### [ ] Step 5.7 - Contest scoring on verdict + scoreboard page

**Goal:** When a contest submission gets a verdict, run `Contests::Scoring`; show scoreboard (manual refresh OK).

**Touch:**
- Hook webhook / submission finalize path to `Contests::Scoring` when `submission.contest_id` present
- Scoreboard action/view (table: rank, user, solved, penalty)
- Reuse M3/M4 UI patterns

**Verify:**
- Two users submit in a contest; scoreboard updates after refresh
- Penalty/solves match scoring rules from M4 tests

**Do not:**
- Broadcast over ActionCable (M7)
- Update ratings here (Step 5.8)

### [ ] Step 5.8 - Finalize contest, UpdateRatingsJob, profile

**Goal:** End a contest, recompute ratings, show rating on profile.

**Touch:**
- `app/jobs/finalize_contest_job.rb`, `app/jobs/update_ratings_job.rb`
- Call `Ratings::Calculator`; write `rating_histories` and user rating
- `ProfilesController` + profile view (rating, recent history optional)
- Manual trigger for finalize (admin button, rake, or console) acceptable for happy path; sidekiq-cron optional

**Verify:**
- After finalize, participants' ratings change and profile shows new rating
- Rating history rows exist

**Do not:**
- Live cable updates
- Revisit Judge0 sandbox limits

### [ ] Step 5.9 - Thin Administrate (optional but planned)

**Goal:** Minimal Administrate panel to manage problems/contests if seeds are awkward for demos.

**Touch:**
- Administrate gem + dashboards for Problem, Contest (and critical nested bits)
- Admin authorization (e.g. `user.admin?` flag)

**Verify:**
- Admin can create/edit a problem or contest without console
- Non-admin is blocked

**Do not:**
- Build a full CMS
- Expose Administrate without any access check

### [ ] Step 5.10 - Manual happy-path checklist

**Goal:** Prove the milestone: full click-through of core functionality.

**Touch:**
- Short checklist in `plan/` or README section (optional): register -> seed problems -> submit AC -> join contest -> submit -> scoreboard -> finalize -> profile rating
- Fix only blockers found during the walkthrough

**Verify:**
- Complete the checklist on a clean local setup (Rails, Redis, Sidekiq, Judge0)
- Course milestone "User happy path is ready" is satisfiable

**Do not:**
- Add M6 system tests in this step (unless a single smoke test is accidental leftover - prefer M6)
- Implement M7 websockets
- Expand to non-core features (chat, blogs, many languages)

**Milestone 5 done when:** a human can click the core loop without placeholders for problems/submit/contest/rating.

---

## Milestone 6: Integration tests

Detailed tests for the happy path plus 2-3 branches. Prefer stubbing Judge0 HTTP in CI; document Docker for real judge locally.

### [ ] Step 6.1 - Happy-path integration / system tests

**Goal:** Automated coverage of the core flow: submit to verdict; contest score update.

**Touch:**
- System or integration tests (Capybara or request specs) under the app's test framework
- Stub/fake Judge0 client or webhook invocation so CI does not need Docker Judge0
- Helpers to sign in, seed problem/contest, inject verdict

**Verify:**
- Tests pass in CI-like local run without Judge0 containers
- Assertions cover submission final state and scoreboard numbers

**Do not:**
- Depend on real Judge0 in default test rake task
- Delete model unit tests from M4

### [ ] Step 6.2 - Branch tests (2-3 off happy path)

**Goal:** Cover failure/authorization branches.

**Touch:**
- Tests such as:
  1. Guest cannot create submission (redirect/401/403)
  2. Cannot register/submit to a closed or not-started contest
  3. Invalid language / empty source rejected
- Keep each test focused

**Verify:**
- All branch tests fail when the guard is removed (spot-check once) and pass with guards in place
- At least two branches automated

**Do not:**
- Exhaustively test every Devise edge case
- Add live WebSocket expectations (M7)

### [ ] Step 6.3 - CI notes and Judge0 stub documentation

**Goal:** Document how tests stub Judge0 and how to run a real end-to-end judge locally.

**Touch:**
- README or `plan/` testing notes: stub strategy, required services for full manual E2E (PostgreSQL, Redis, Sidekiq, Judge0)
- Ensure default test command stays hermetic

**Verify:**
- Another developer can run unit + integration tests without Docker Judge0
- Manual E2E steps are written

**Do not:**
- Commit credentials
- Weaken sandbox "so CI passes"

**Milestone 6 done when:** happy path + 2-3 branches are automated and documented.

---

## Milestone 7: Live (and partial) data updates

WebSockets via ActionCable; Hotwire Turbo Streams / Turbo Frames for the contest scoreboard.

### [ ] Step 7.1 - ActionCable channel for contest scoreboard

**Goal:** Subscribe clients to a contest scoreboard stream.

**Touch:**
- Channel e.g. `ScoreboardChannel` / stream `contest:<id>:scoreboard`
- Cable config using Redis in production-like local setup if required by adapter
- Authenticate connection (signed-in users; optionally only registrants)

**Verify:**
- Client subscription connects without error on contest scoreboard page
- Unauthorized connection behavior is defined

**Do not:**
- Redesign scoring algorithms
- Add chat or unrelated cable features

### [ ] Step 7.2 - Broadcast on score updates (Turbo Streams)

**Goal:** When contest scoring updates standings, broadcast Turbo Stream replace/update for the scoreboard table.

**Touch:**
- Broadcast from scoring path (after webhook applies contest score)
- Partial for scoreboard rows/table targeted by Turbo Stream
- Ensure M5 refresh still works if cable disconnects

**Verify:**
- Trigger a verdict; without full page reload, scoreboard DOM updates for a subscribed client
- Two sessions: User A sees User B's AC appear live

**Do not:**
- Poll Judge0 from the browser
- Bypass Sidekiq/Judge0 for fake "live" hacks in production code paths

### [ ] Step 7.3 - Live scoreboard acceptance check

**Goal:** Confirm the milestone page is demo-ready.

**Touch:**
- Polish scoreboard page copy/structure for live updates
- Brief note in spec/README that scoreboard is the live page

**Verify:**
- Two browsers or users: submissions update the leaderboard in real time
- Milestone 7 checklist item can be marked done

**Do not:**
- Start unrelated features after cable works
- Change expected test outputs or sandbox limits

**Milestone 7 done when:** contest scoreboard updates over ActionCable + Turbo Streams without a manual full reload.

---

## Suggested session order (quick index)

| Done | Session | Step | Milestone |
|------|---------|------|-----------|
| [x] | 1 | 1.1 Topic + description | M1 |
| [x] | 2 | 1.2 Screen diagram | M1 |
| [x] | 3 | 1.3 Stack | M1 |
| [x] | 4 | 1.4 Pitfalls | M1 |
| [x] | 5 | 2.1 Rails bootstrap | M2 |
| [x] | 6 | 2.2 Devise User | M2 |
| [x] | 7 | 2.3 Auth UI + session | M2 |
| [ ] | 8 | 3.1 Design tokens | M3 |
| [ ] | 9 | 3.2 UI kit page | M3 |
| [ ] | 10 | 3.3 Placeholder screens | M3 |
| [ ] | 11 | 4.1 Migrations | M4 |
| [ ] | 12 | 4.2 Models | M4 |
| [ ] | 13 | 4.3 Contests::Scoring | M4 |
| [ ] | 14 | 4.4 Ratings::Calculator | M4 |
| [ ] | 15 | 4.5 Model tests | M4 |
| [ ] | 16 | 5.1 Seeds/importer | M5 |
| [ ] | 17 | 5.2 Problems read path | M5 |
| [ ] | 18 | 5.3 Sidekiq skeleton | M5 |
| [ ] | 19 | 5.4 Judge0 + client | M5 |
| [ ] | 20 | 5.5 Submit + webhook | M5 |
| [ ] | 21 | 5.6 Contests register/show | M5 |
| [ ] | 22 | 5.7 Scoring + scoreboard | M5 |
| [ ] | 23 | 5.8 Finalize + ratings + profile | M5 |
| [ ] | 24 | 5.9 Administrate thin | M5 |
| [ ] | 25 | 5.10 Manual checklist | M5 |
| [ ] | 26 | 6.1 Happy-path tests | M6 |
| [ ] | 27 | 6.2 Branch tests | M6 |
| [ ] | 28 | 6.3 Test docs | M6 |
| [ ] | 29 | 7.1 Scoreboard channel | M7 |
| [ ] | 30 | 7.2 Turbo Stream broadcast | M7 |
| [ ] | 31 | 7.3 Live acceptance | M7 |

When unsure, prefer stopping at step boundaries over combining Judge0 with schema work or ActionCable with first auth.
