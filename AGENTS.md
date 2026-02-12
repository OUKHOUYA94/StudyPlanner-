# AGENTS.md

Purpose: Keep development consistent, documented, and test-aware across sessions.

## Source of truth
- Stack: Flutter + Firebase (Auth, Firestore, Cloud Functions, Storage, FCM)
- Platforms: Android first, iOS optional
- UI language: French in-app
- Docs: Keep project docs ASCII unless the file already contains non-ASCII

## Required workflow (every session)
1) Confirm scope and read relevant files (PRD + impacted code/docs).
2) Write a plan for non-trivial tasks (2+ steps) before coding.
3) Implement incrementally with clear intent and small diffs.
4) Run relevant tests; if skipped, state why.
5) Update Docs/ after each session (no stale docs).

## Documentation rules (mandatory)
- Update `Docs/Progress_Report.md` every session with: date, session id, summary, files changed, tests, errors, next steps.
- Add exactly one new session file per session in `Docs/Sessions/`.
- Update `Docs/API_Routes.md` when Cloud Functions, Firestore schema, or data contracts change.
- Update `Docs/Frontend_Pages.md` when UI pages, routes, or key components change.
- Update `Docs/README.md` when docs structure changes.
- Keep all `Docs/*.md` synchronized with code changes.

## Session log requirements
Each `Docs/Sessions/YYYY-MM-DD_session-XXX.md` must include:
- Goals
- Context
- Atomic Tasks (small, testable)
- Tests (commands + results) OR explicit reason tests were skipped
- Errors (what failed + resolution)
- Outputs (files changed)
- Next steps

## Quality bar (minimum)
- Prefer Firebase Emulator Suite for rules/functions testing when feasible.
- Sensitive writes (attendance + assessment constraints) must go through Cloud Functions.
- Security rules must be least-privilege and reviewed whenever data access changes.

## Reporting format (final response)
- Work summary
- Files touched
- Tests
- Errors
- Docs updated

## Constraints
- Do not delete or rename docs without approval.
- Avoid destructive commands unless explicitly asked.
