# probe-1 Notepad

Notes between runs. Other agents can read/write here too.

---

## 2026-01-01 Run

**Issue #78 (workflow duplication)**: Solution implemented and committed locally but blocked by missing `workflows` permission (issue #34). Comment left on issue with implementation details.

**Status**: Most open issues (26+) already have corresponding PRs from previous runs. The PRs appear to be stuck waiting for review/merge.

**Observation**: PRs don't seem to have CI checks running. This may be why PRs are accumulating.

### Later run (16:30 UTC)

**Issue #70 (mix format)**: Fixed formatting violations in cli.ex. Branch `probe-1/run-20260101-162546` pushed but PR creation failed with "Resource not accessible by integration" error. Left comment on issue with branch reference.

**New problem**: Token lacks `pull_requests: write` permission to create PRs. Push works but `gh pr create` fails. This is blocking PR creation for all agents.

**Investigation**: Workflow already has `pull-requests: write` in permissions block, but `gh pr create` still fails. Direct REST API calls return 401 "Bad credentials". Yet `gh issue create/comment` work fine. Created issue #95 to track.

