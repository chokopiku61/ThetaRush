# ThetaRush UI refactoring plan

Status: M6 and M7 step 7.1 completed and verified on 2026-11-13. M7 step 7.2 is next in the required order; UI implementation has not started. See the progress notes in [implementation.md](implementation.md).

## Goal and scope

Simplify the competitive programming interface, reduce application-owned JavaScript, and replace generic UI styling with a CSS library. Preserve practice submissions, contest participation, judging, standings, ratings, favorites, groups, and both interface locales.

Read together with [AGENTS.md](../AGENTS.md), [architecture.md](architecture.md), [spec.md](spec.md), [milestones.md](milestones.md), and [implementation.md](implementation.md).

This document adds a maintenance sequence. M1-M6 are checked off; M7 is the next unfinished milestone. Complete steps 6.1, 6.2, and 6.3 before starting the UI implementation below. Complete M7 steps in their existing order before adding submission broadcasts. Each numbered implementation step below is one session, with its own verification and stopping point.

## Findings from the repository

| Area | Current evidence | Implication |
| --- | --- | --- |
| Rendering | Rails 8.1, ERB, Propshaft, importmap, Turbo, Stimulus | Keep the existing rendering and asset architecture. |
| CSS | `application.css`: 1,003 lines; `theme_dark.css`: 1,814 lines | Generic components and two layers of theme definitions create a large maintenance surface. Line counts alone do not establish unused CSS. |
| Navigation | `sidebar_controller.js`: 210 lines, phased transitions, localStorage, global resize events | The shell and editor are coupled through layout notifications. |
| Problem workspace | One horizontal and two vertical split-pane instances in `problems/show` and `_editor_chrome` | Nested draggable panes make layout, mobile behavior, and keyboard interaction more complex. |
| Editor | `editor_controller.js`: 382 lines, Monaco AMD loading, Vim, Caps Lock mapping, explicit resizing | A library is already present; its integration and optional features account for substantial custom code. |
| Editor fallback | Source textarea starts with `visually-hidden`; `fallbackTextarea()` adds classes but does not remove that class | Static inspection indicates the failure fallback stays visually hidden. With JS disabled, the source field is also hidden. Confirm with a browser during implementation. |
| Custom runs | `custom_run_controller.js`: 150 lines; JSON POST; browser output rendering and sample comparison | Rails forms and HTML responses can replace much of this orchestration. |
| Verdict updates | `submission_status_controller.js`: 82 lines; HTML fetch, `outerHTML`, confetti | Use Turbo for DOM updates. The detail page currently relies on manual refresh instead. |
| Polling limit | Attempts are held on the controller instance, but each successful replacement creates a fresh instance | The nominal 120-attempt limit does not bound the overall polling session. |
| Decorations | `matrix_rain_controller.js`: 81 lines; global confetti import in status controller | Decorative behavior adds work unrelated to solving problems. |
| Useful small JS | Clipboard: 51 lines; countdown: 49; file upload: 69 | Keep narrow browser-only enhancements where they provide value. |
| Catalog | Existing GET form and server-side filters | Preserve this simple implementation; no client-side table framework needed. |
| Profile | Rating chart is rendered as SVG inside ERB | Keep JS-free rendering; extract geometry into a helper rather than adding a charting library. |
| Tests | Existing `ActionDispatch::IntegrationTest` classes under `test/controllers` | Coverage already exists. Audit and extend it instead of duplicating it based on folder names. |
| Tests coupled to design | Contest submission tests assert `.pkg-menu__*` and workspace classes | Move behavior assertions toward labels, links, form fields, and stable identifiers as the markup changes. |
| Documentation drift | Spec still says nothing is installed, describes custom CSS and explicit registration; current problem GET can create participation | Update documentation with the adopted design, and preserve current participation behavior during this refactor. |
| Cable configuration | Development uses async, production uses Solid Cable; architecture describes Redis | Resolve this mismatch in M7, including cross-process broadcasts from Sidekiq. |

These are source-level findings. No browser layout or performance measurements have been completed in this review.

### Verification attempted

- `bundle check`: dependencies are satisfied.
- `bundle exec rails test`: aborts during application loading with `NameError: uninitialized constant Rails::Generators`, originating from the installed `solid_cache-1.0.10` generator. Tests did not run. Investigate the loading path before drawing conclusions about application test failures. Do not change global gems or system configuration.
- No runtime UI changes, dependency installation, deletion, database preparation, or milestone status changes were made for this plan.

## Target design and library decisions

Use **Bulma CSS** for standard controls and layout primitives. It provides CSS-only components and can be delivered as a compiled stylesheet, which fits Propshaft without adding a JavaScript build pipeline. Use one exact release, stored locally with its license and provenance. Validate the version when implementation begins.

Retain a small ThetaRush stylesheet for the brand, verdict colors, statement formatting, and workspace layout. Vendor CSS counts toward transferred assets even though it is excluded from the custom-code maintenance budget. Measure both.

| Concern | Target | Reason |
| --- | --- | --- |
| Buttons, fields, selects, tables, notifications, tags, spacing | Bulma components | Replace generic handwritten styling with one consistent library. |
| Navigation | Labeled links, visible desktop menu, wrapping or native disclosure on mobile | Avoid phased collapse, overlay state, and resize notifications. |
| Expandable stderr, compiler output, previous submissions | Native `details` and `summary` | Already used on the submission detail page; no controller needed. |
| Page navigation and form requests | Existing Turbo Drive; Frames for independent results | Let Rails render HTML, retaining ordinary HTTP fallback. |
| Live standings | Action Cable and Turbo Streams, in M7 | Required by the existing milestone and architecture. |
| Code input | Visible textarea by default; optional Monaco enhancement | Baseline submission remains usable when JS is disabled or editor assets fail. |
| Editor preferences | Put existing Vim/Caps options behind an advanced disclosure | Reduce primary-screen clutter while preserving current capabilities initially. |
| File input | Native labeled file control; small FileReader enhancement for preview | No upload UI dependency. Preserve the existing size guard. |
| Clipboard and countdown | Small Stimulus controllers and native browser APIs | A dependency would add little value here. |
| Rating chart | Server-generated SVG plus existing history table | No new JS charting dependency. |
| Admin | Existing Administrate UI | Avoid applying public-site CSS to its separate layout. |

Do not introduce React, Vue, a component wrapper library, a second CSS framework, or separate libraries for dropdowns, split panes, animation, tables, or file upload. Replacing Monaco with CodeMirror is not part of the first pass: it would still require JavaScript and introduce a separate migration. Reconsider only if measurements after simplifying the workspace justify it.

Bulma is a styling library. It does not automatically implement keyboard behavior, focus management, or collapsing menus. Prefer normal links and native disclosure elements rather than rebuilding those behaviors.

## Proposed screen changes

| Screen | Proposed simplification | Preserve |
| --- | --- | --- |
| Global shell | Replace animated icon rail with labeled navigation. Keep Problems, Contests, Submissions prominent; secondary links in a disclosure or profile area; UI kit in footer. | All existing routes, locale selection, session controls, pinned contest access, admin visibility rules. |
| Home | Static title, short explanation, two primary links, compact statistics. Stop mounting matrix animation. | Branding and catalog/contest entry points. |
| Catalog and submission list | Library-styled tables and GET filters. Keep title, rating, tags, solved state prominent; make technical limits secondary on narrow screens. | Filter URLs, data, favorites, accessible labels, useful empty states. |
| Problem | Responsive CSS Grid: statement and submission panel on desktop, stacked sections on mobile. Use natural page flow instead of nested draggable panes. | Statement, limits, examples, contest navigation, source, language, Run, Submit, and verdict. |
| Submission panel | Language and source first, Run and Submit next. Place custom stdin/results and older submissions in native disclosures. | Current source on errors and result updates; separate practice and contest context. |
| Contest | Compact title, timing, participation state, problem list, and scoreboard link. | Server-side time guards, registration behavior, favorites and pin actions. |
| Scoreboard | Plain responsive table with rank, participant, solved count, and penalty. Add live updates only in M7. | Manual refresh, deterministic ordering, readable empty state. |
| Profile | Rating summary, history table, optional existing SVG, recent submissions. | Rating data and links to full history/submissions. |
| Auth, favorites, groups | Apply the shared library controls and spacing. | Devise forms, error states, group operations, authorization. |
| UI kit | Show the actual library-backed controls used by product screens. | A separate reviewable gallery required by M3. |

## Execution sequence

### Prerequisite: complete M6 in the existing order

- [x] **6.1:** Diagnose the application boot failure using project-local changes only. Audit existing integration coverage; add the practice submit -> mocked Judge0 verdict -> result flow and contest submit -> verdict -> scoreboard assertions. Cover Python and C++ payloads. Do not execute user code on the host.
- [x] **6.2:** Cover guest denial, closed/not-started contest submission, and invalid language or empty source. Include owner-only status access. Preserve current auto-participation behavior unless separately agreed.
- [x] **6.3:** Document commands, test doubles, required services, and manual Judge0 E2E. Run the default suite without real Judge0 and record the outcome before marking M6 complete.

Existing CSS-specific assertions may remain until their corresponding UI step. Do not turn this baseline phase into a redesign. Add browser tests for meaningful interactive behavior when it changes, not for every component class.

### Step R1: establish the library-backed UI kit

**Touch:** locally vendored Bulma stylesheet and license, `layouts/application.html.erb`, stylesheet entry points, `ui_kit/show.html.erb`, `plan/spec.md`.

- [ ] Add the pinned compiled stylesheet and explicit asset ordering: library, then ThetaRush overrides. Do not rely on filename sorting to express precedence.
- [ ] Pilot the components in the UI kit before migrating the shell. Keep legacy product styling isolated during this pilot so overlapping selectors such as `.button`, `.table`, `.tag`, `.input`, and `.select` cannot silently change unmigrated screens.
- [ ] Use a bounded migration scope or isolated kit layout; avoid running two global component systems on the same page.
- [ ] Establish one dark theme and a small set of brand, spacing, and verdict tokens. Preserve the existing logo and assets.
- [ ] Update the spec's frontend styling decision and obsolete planned-stack wording. Keep Rails, Hotwire, and Judge0 architecture intact.

**Verify:** kit controls, validation errors, labels, focus styles, tables, and disclosures at 360, 768, and 1440 CSS pixels; public CSS does not affect Administrate. Record screenshots and loaded assets.

### Step R2: simplify the global shell and ordinary screens

**Touch:** layout and navigation partials, navigation helpers, home, catalog, contests, auth, submissions list, profile, favorites, groups, locale entries, relevant CSS.

- [ ] Migrate ordinary screens to Bulma controls and layouts; consolidate recurring inline styles into shared classes.
- [ ] Replace phased sidebar behavior with labeled navigation that works without JS. Keep the pin slot accessible.
- [ ] Stop mounting sidebar and matrix controllers on the new layout; stop displaying canvas decoration. Keep files until deletion is authorized.
- [ ] Extract rating-chart geometry into a focused helper while preserving SVG and the history table.
- [ ] Preserve URLs, locale strings, Devise errors, authorization, and data semantics.

**Verify:** browse all existing navigation as guest, user, and admin; check sign in, sign out, refresh persistence, locale switching, filters, favorites, pin/unpin, group actions, and narrow-screen navigation. Do not mark R2 complete with unmigrated core routes.

### Step R3: simplify the problem workspace and make code entry resilient

**Touch:** `problems/show.html.erb`, `_editor_chrome.html.erb`, contest strip, editor and file-upload controllers, workspace CSS, relevant integration/system tests.

- [ ] Replace all three splitter instances with a responsive CSS Grid and ordinary stacked panels. Stop mounting the split-pane controller.
- [ ] Render a labeled, visible textarea as the baseline source field. Hide it only after successful Monaco initialization; restore it on failure.
- [ ] Load Monaco only on signed-in problem pages when enhanced editing is requested. Keep one source of truth and sync it for both Run and Submit.
- [ ] Keep advanced Vim/Caps settings in a disclosure initially. Any later removal requires a separate capability decision.
- [ ] Remove layout coupling to sidebar transitions and split-pane resize events as callers migrate. Keep only resizing needed for the actual editor host.
- [ ] Use native labeled file input. Keep a small client preview enhancement; provide server-side source-file handling with the same size limit for the no-JS path. Specify how file content and pasted source are prioritized, and validate the explicit Python/C++ language selection.
- [ ] Never execute an uploaded source file in Rails; treat it as text passed to the existing submission/judge boundary.

**Verify:** submission with JS disabled, Monaco load failure, Python and C++, file import, file size rejection, source preservation after errors, Run/Submit agreement, repeated Turbo visits, closed contest state, and mobile editing. Confirm no hidden source field remains as the only input path.

### Step R4: move custom runs to Rails-rendered responses

**Touch:** `custom_runs_controller.rb`, custom-run result partials, problem form, custom-run controller JS, locale entries, request/system tests.

- [ ] Use one source form with explicit Run/Submit actions, such as submitter `formaction`, to avoid nested forms or duplicated code fields.
- [ ] Return result HTML inside a stable Turbo Frame for interactive requests. Render stdout, stderr, compiler output, status, and validation errors on the server, escaped as text.
- [ ] Keep an ordinary HTML POST response when Turbo is unavailable. Preserve the entered source and stdin on validation or Judge0 errors; do not put source code in a query string.
- [ ] Retain JSON responses for existing clients/tests until their consumers are audited. Avoid a silent endpoint contract change.
- [ ] Make sample execution a normal form action carrying a sample identifier, with server-side sample lookup and the existing comparison semantics. Do not modify stored expected outputs.
- [ ] Keep existing Judge0 time/memory limits and execution path. Do not add new job infrastructure solely for this UI change; assess request latency separately if the current synchronous run path proves too slow.
- [ ] Let Turbo manage requests and frame replacement. Retain only small enhancements such as busy labels or sample-to-stdin convenience if needed.

**Verify:** successful run, compile/runtime failure, empty source, unsupported language, Judge0 error, guest request, sample comparison, HTML fallback, and JSON compatibility. Ensure a result update does not replace the editor or lose source text.

### Step R5: consolidate verdict rendering without adding live subscriptions

**Touch:** submission status partials, `submissions_controller.rb`, `submission_status_controller.js`, importmap, locales, tests.

- [ ] Use a shared status presentation for workspace and detail views with stable unique IDs. Keep manual refresh available.
- [ ] Until M7 is complete, retain bounded polling if automatic verdict refresh is needed. A small Stimulus scheduler may reload a Turbo Frame; Frames do not schedule polling themselves.
- [ ] Keep the overall timeout/deadline outside the replaced controller state, stop at terminal states, back off on errors, and offer a retry/refresh action when the bound is reached.
- [ ] Replace manual HTML parsing and `outerHTML` mutation with Turbo-managed HTML updates.
- [ ] Stop importing or triggering confetti in the refactored path. Leave dependency files in place pending the separate deletion decision.
- [ ] Handle multiple pending submissions, rather than polling only the latest and leaving an older pending row stale.

**Verify:** queued -> judging -> terminal, several pending submissions, timeout/retry, disconnect on navigation, owner-only status authorization, no source loss, and no duplicate timers after Turbo navigation.

### Existing M7: complete 7.1, 7.2, and 7.3 in order

- [ ] **7.1:** Resolve the Cable adapter mismatch and establish a subscription policy using the existing M7 instructions. Preserve public HTTP scoreboard access; document whether live subscriptions require sign in. Use Turbo's existing subscription machinery where sufficient.
- [ ] **7.2:** Extract a scoreboard partial, broadcast after committed scoring changes, and verify delivery from a separate Sidekiq process. Never broadcast a personalized layout or source code to the shared contest stream.
- [ ] **7.3:** Verify two browser sessions, correct ranking/penalty, reconnect behavior, and manual refresh fallback. Mark M7 complete only after that acceptance check.

### Step R6: replace submission polling with private Turbo Streams

This is a follow-on UI improvement after M7, not a prerequisite for its scoreboard acceptance.

**Touch:** verdict application path, private stream authorization, status partials and subscriptions, tests.

- [ ] Broadcast committed verdict changes to an owner-authorized stream. Check authorization on the server; a hidden subscription element is not access control.
- [ ] Replace only status/results, preserving the source form. Keep practice and contest histories separate.
- [ ] Eliminate the routine browser polling scheduler after stream delivery is verified; retain a refresh action and reconcile state on reconnect so missed events do not leave stale results.

**Verify:** owner receives pending and terminal updates, another user cannot subscribe to private results, two simultaneous submissions converge correctly, and disconnected browsers can recover via refresh/reconnect. No Judge0 browser requests.

### Step R7: measure, reconcile documentation, and prepare cleanup

- [ ] Run the relevant request/system suite, then the full suite. Repeat the two-session live acceptance check only if this step changes its behavior.
- [ ] Compare initial and final custom CSS/JS, transferred assets, editor startup, and core-screen screenshots. Distinguish library bytes from application-owned code.
- [ ] Update UI kit, spec, implementation notes, and README to describe the final behavior and testing commands. Keep original milestone completion evidence intact.
- [ ] Audit references before identifying obsolete controllers, CSS, confetti assets, Monaco extras, placeholder data, or unused partials. Do not assume files are unused from their names.
- [ ] Produce an exact deletion list and ask before deleting any file, dependency asset, or obsolete code block. Until approved, keep legacy files present and disconnected from migrated UI where appropriate. No broad cleanup of pre-existing untracked files.

**Verify:** all routes remain usable, documentation matches implementation, asset loading is explicit, no unintended requests for disconnected features, and cleanup candidates have reference evidence.

## Acceptance criteria

- Core practice and contest paths remain covered by automated integration tests, with Judge0 stubbed by default.
- All core screens work at 360, 768, and 1440 CSS pixels; wide tables may scroll within their container without making the whole page overflow.
- With JS disabled, users can navigate, authenticate, filter, choose a language, enter or upload source, run code through Judge0, submit, and manually refresh results. Live updates, clipboard, countdown ticks, and enhanced editor remain progressive enhancements.
- Ordinary screens need no new application JS for navigation, filters, tables, forms, or disclosures.
- No matrix animation, confetti, splitter, or phased-sidebar behavior is loaded by the final product views.
- Working target: at least 50% less active application-owned frontend JS and custom CSS than the recorded baseline. Report inactive legacy code separately; do not claim deletion-based savings before cleanup approval. This target excludes vendored libraries but includes their bytes in the asset comparison.
- Monaco and its optional plugins load only when requested on an editable problem page. No replacement editor or JS widget framework is added without measurement showing a benefit.
- Keyboard focus is visible; inputs have labels; verdicts include text; errors are associated with forms; no source is lost when only results update.
- Judging isolation, expected test data, scoring, rating algorithms, and server-side contest time guards retain their existing semantics.

## Sources for dependency and Hotwire decisions

- [Bulma repository](https://github.com/jgthms/bulma): CSS-only framework, no bundled JavaScript.
- [Bulma installation](https://bulma.io/documentation/start/installation/): compiled stylesheet and local download options.
- [Turbo Frames](https://turbo.hotwired.dev/handbook/frames): independent HTML request/response regions with matching frame IDs.
- [Turbo Streams](https://turbo.hotwired.dev/handbook/streams): HTML updates over HTTP responses or asynchronous transports.

The specific library version and measured asset cost must be recorded during R1. This plan does not add a dependency today.
