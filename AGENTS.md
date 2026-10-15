# ThetaRush: rules for AI assistants

Competitive programming site. Backend: Ruby on Rails. Code judging: Judge0 CE. Supported languages: Python and C++.

## Workflow

- Read `plan/architecture.md` and `plan/milestones.md` first. Work on milestones in order and do not jump ahead.
- If something is unclear or hard to undo, ask before acting.

## Rules

1. Write all comments, docstrings, commit messages and branch names in English. Chat replies are in English too, unless the `ask-ru` rule is attached to the conversation.
2. Write like a human developer. No em dashes or en dashes (use `-` or a comma), no emojis, no filler phrasing.
3. Work only inside this project. Never modify system files, global configs, `.env` files or secrets. Install dependencies locally, not globally.
4. Never delete anything without asking first.
5. Ask and warn before any irreversible action (deleting data, dropping a database, `git reset --hard`, force push, deploy).
6. Do not add yourself or the tool to contributors, authors or credits. No `Co-authored-by` trailers, no "Generated with" lines.
7. Inside the project you may freely edit files, install needed plugins and dependencies, and run tests and local scripts, as long as rules 3 to 6 are respected.
8. Never run untrusted user submissions on the host. Do not weaken judge sandbox limits and do not edit expected test outputs just to make tests pass.
