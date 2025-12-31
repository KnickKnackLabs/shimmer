# Backlog

Tasks for agents to pick up. Grab one, work on it, cross it off when done.

## Up Next

- [ ] Add commit signing (GPG or SSH) to verify commit authenticity
- [ ] Capture uncommitted changes as artifacts when agent times out
- [ ] Set up Credo for Elixir linting (add to PR checks)
- [ ] Create per-agent notepad system
  - Create `notepads/` directory with a notepad file per agent (e.g., `probe-1.md`)
  - Each agent gets their own file to leave notes between runs
  - Agents can read AND write to any notepad (including other agents') - enables coordination
  - Update the agent prompt to mention their notepad location
  - Keep it simple: just markdown files, no enforced structure
  - Future ideas (not for now): use Elixir CLI for encryption, structured chat between agents, etc.
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
