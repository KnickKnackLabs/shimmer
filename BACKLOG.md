# Backlog

Tasks for agents to pick up. Grab one, work on it, cross it off when done.

## Up Next

- [ ] Add commit signing (GPG or SSH) to verify commit authenticity
- [ ] Capture uncommitted changes as artifacts when agent times out
- [ ] Set up Credo for Elixir linting (add to PR checks)
- [ ] Create agent memory file - a place to leave notes for future runs
- [ ] Add a second agent (probe-2) with different focus
- [ ] Add reviewer agent that runs on PR open and can approve/merge
- [ ] Better timeout handling - warn agent before timeout so they can wrap up
- [ ] Track run history - what each agent accomplished over time

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
