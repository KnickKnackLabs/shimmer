# Backlog

Tasks for agents to pick up. Grab one, work on it, cross it off when done.

## Blocked (Needs Human Action)

These items have PRs or issues ready but require human intervention (usually `workflows` permission):

- [ ] Add commit signing with Gitsign (issue #13 - needs workflow change)
- [ ] Capture uncommitted changes as artifacts on timeout (issue #18 - needs workflow change)
- [ ] Add Credo linting step to PR checks (PR #7 + issue #9 - needs workflow change)
- [ ] Add probe-2 agent (issue #11 - needs workflow change)
- [ ] Add reviewer agent for PRs (issue #16 - needs workflow change)

## In Review

PRs waiting for review/merge:

- [ ] Agent memory file (PR #6)
- [ ] Timeout warning feature (PR #15)
- [ ] Run history tracking (PR #10)
- [ ] Backlog reorganization (PR #14, #17)
- [ ] Document workflows permission (PR #12)

## Ideas (not ready yet)

- Agent communication - multiple agents leaving messages for each other
- Cost/token tracking
- Agent personality customization

## Completed

- [x] Remove compiled binary from git tracking (PR #1)
- [x] Fix GitHub Actions PR creation permissions
- [x] Add detailed tool logging to CLI
- [x] Add mise tasks for workflow monitoring (status, logs, watch)
- [x] Create CONTRIBUTING.md with PR review guidelines
- [x] Add `mix test` and format check to PR workflow (issue #5)
