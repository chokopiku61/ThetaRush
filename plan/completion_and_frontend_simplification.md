# Complete ThetaRush milestones and simplify frontend implementation

Status: approved direction saved from the planning chat on 2026-11-13. M1-M6 and M7.1-M7.2 are recorded as complete in implementation.md. Implementation of this follow-on plan has not started.

## How to execute

- Read AGENTS.md, plan/architecture.md, and plan/milestones.md first, then plan/implementation.md and this file.
- Verify current repository state before acting. Preserve existing uncommitted work.
- Complete steps in the order below. One step is one implementation session; verify it, record evidence, and stop before the next step.
- Mark a step complete in this file only after its required verification. Update the matching original milestone checklist when applicable.
- This file supersedes the conflicting Bulma, textarea-first, fixed-pane, and functionality-removal proposals in plan/ui_refactoring.md. Do not implement those older proposals. Step R1 will reconcile that document.
- Ask before deleting files or dependencies, changing secrets or environment files, or taking irreversible actions, following AGENTS.md.

## Summary and constraints

Complete M7.3 first, then add nickname management and reduce custom JavaScript without removing functionality or redesigning the interface.

- Preserve the current visual identity, custom CSS, Monaco as the default editor, Vim/Caps settings, file import, sample execution, custom runs, and submissions.
- Preserve navigation, resizable panes, preferences, animations, and other existing interactions. Simplify their implementation where equivalent behavior is available.
- Keep Rails, ERB, Propshaft, importmap, Turbo, Stimulus, and Judge0. Do not add Bulma or another frontend framework.
- Use one implementation session per step. Verify each step before marking it complete.
- Preserve existing uncommitted work. Ask before deleting files or dependencies.

## 1. Finish the remaining milestone

### [ ] Step 7.3: Live scoreboard acceptance

- Add a Turbo Frame and refresh link around the scoreboard, keeping the subscription outside the frame.
- Add EN/RU copy describing authenticated automatic updates and public manual refresh.
- Verify two independent signed-in browser sessions against Rails, Sidekiq, Solid Cable, and real Judge0.
- Exercise WA followed by AC, correct penalty and ranks, isolation between contests, guest access, and refresh after a missed update during disconnection.
- Preserve the current broadcast scope: verdict scoring broadcasts; registration and final recalculation require refresh.
- Record actual results in README and the implementation plan. Mark M7 complete only after browser acceptance succeeds.

## 2. Add nickname selection and editing

### [ ] Step N1: Registration and profile forms

- Reuse User#username as the nickname shown in profiles and standings. Do not add another name field.
- Add a required nickname field to registration and permit it through Devise.
- Reject missing or blank nicknames in web registration. Preserve generated usernames for internal creation paths and existing accounts.
- Extend the singular profile resource with GET /profile/edit and PATCH /profile.
- Edit only current_user, permitting only username. Do not expose user IDs or allow changes to email, password, rating, or admin status.
- Use ordinary Rails forms and existing styling. Successful updates redirect to the profile; invalid updates render the form with HTTP 422 and EN/RU errors.
- Keep the existing rules: trim whitespace, allow 3-20 Latin letters, digits, or underscores, and enforce case-insensitive uniqueness.
- Keep the session active after a nickname change. No password confirmation is required for this non-credential update.

### [ ] Step N2: Database integrity and coverage

- Check existing usernames for case-insensitive collisions before adding a unique index on lower(username).
- Retain the existing index. If collisions exist, report them and request a naming decision rather than automatically renaming accounts.
- Handle concurrent duplicate-name attempts as validation errors.
- Ensure profiles, navigation, submissions, and refreshed standings display the current username through existing associations.
- Do not add username-change broadcasts. Already-open standings reflect the new name on their next scoreboard update or refresh.

Verification for N1-N2: valid registration, missing nickname, invalid characters and length, case-insensitive duplicates, unchanged nickname, successful editing, guest denial, protected-attribute injection, and preservation of ratings and ownership. Add relevant tests in each step, then extend concurrency and database-integrity coverage in N2.

## 3. Simplify frontend implementation

### [ ] Step R1: Reconcile documentation and record a baseline

- Update plan/ui_refactoring.md to replace its Bulma redesign and functionality-removal proposals with the agreed preservation requirements.
- Reconcile its outdated milestone and test status with plan/implementation.md.
- Record custom JS/CSS size, loaded modules, screenshots, and the behaviors each controller currently provides.
- Use that inventory as the regression checklist. Do not treat fewer lines alone as proof of improvement.

### [ ] Step R2: Move custom runs to Rails-rendered responses

- Keep the existing Run, sample execution, stdin, and Submit controls.
- Use one source form with explicit Run/Submit actions, avoiding duplicated source fields and nested forms.
- Return server-rendered results inside a stable Turbo Frame, leaving Monaco and source input outside the replaced area.
- Move sample lookup, comparison, validation, and escaped output rendering to Rails.
- Preserve existing JSON responses for compatible clients and tests.
- Provide ordinary HTML responses when Turbo is unavailable. Preserve source, language, stdin, and contest context on errors.
- Keep the existing Judge0 execution path and resource limits.

### [ ] Step R3: Replace verdict polling with private Turbo Streams

- Reuse the established Cable infrastructure for owner-authorized submission subscriptions.
- Render shared status fragments with stable per-submission identifiers.
- Broadcast committed judging, terminal verdict, and job-failure changes. Broadcast failures must not alter persisted judging results.
- Update multiple pending submissions independently, keeping practice and contest contexts separate.
- Preserve the existing visibility of submission detail pages; subscription authorization must independently require ownership.
- Keep manual refresh and a small reconnect reconciliation mechanism to recover missed changes.
- Disconnect the polling implementation only after private stream delivery is verified.
- Preserve existing verdict presentation and acceptance effects, triggering effects only on an actual transition to Accepted.

### [ ] Step R4: Simplify Monaco integration and preserve fallback

- Keep Monaco enabled by default, including Vim mode, Caps-to-Escape behavior, language switching, and saved preferences.
- Use Monaco's existing facilities for layout where they can replace duplicate resize orchestration.
- Preserve draggable panes, keyboard resizing, bounds, and saved pane sizes. Do not replace them with a fixed layout.
- Render a usable textarea before editor initialization. Hide it only after Monaco succeeds and restore it on failure.
- Keep one synchronized source value for Run, Submit, and file import.
- Preserve file preview and language detection. Add server-side text-file handling for the no-JavaScript path, retaining the existing 256 KiB limit.
- Treat an attached file as the source when present; otherwise use textarea content. Explain that precedence beside the input.

### [ ] Step R5: Simplify loading and small controllers

- Replace eager loading of every controller with explicit registration of controllers used by the application.
- Load Monaco and its optional plugins only on editable problem pages.
- Preserve sidebar collapse, mobile navigation, stored preferences, split panes, clipboard, countdown, and decorative effects.
- Replace custom implementation with native HTML, CSS, or existing library features only when behavior and accessibility remain equivalent.
- Keep small Stimulus controllers where browser behavior still requires JavaScript.
- Avoid new widget libraries whose integration would exceed the code they replace.

## 4. Verification and completion

After each step, run focused tests and verify the affected browser behavior. Run the full Rails suite after integration.

Acceptance requires:

- Practice and contest submissions work in Python and C++.
- Run, sample comparison, file import, editor preferences, pane resizing, and navigation retain their behavior.
- Result updates never discard source or recreate the editor unnecessarily.
- Repeated Turbo visits do not create duplicate timers, listeners, editors, or subscriptions.
- Nickname forms and core submission flows work without JavaScript; live updates and editor enhancements degrade to manual refresh and textarea input.
- Layout and keyboard behavior remain usable at 360, 768, and 1440 CSS pixels.
- Automated judging tests use fake Judge0 transport; real Judge0 is exercised separately for browser acceptance.
- Judging isolation, expected test outputs, scoring, ratings, and contest time guards remain unchanged.

### [ ] Final verification and documentation

- Update README, the UI kit, specification, and implementation checklists to match verified behavior.
- Report changes in custom code, downloaded assets, and retained inactive files separately.
- Prepare an exact cleanup list and request approval before deleting obsolete files or dependencies.
- Record completed checks, test results, remaining limitations, and any blocked acceptance checks here.
