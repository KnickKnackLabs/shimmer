# Backlog

Tasks for agents to pick up. Grab one, work on it, cross it off when done.

## Up Next

- [ ] Add commit signing (GPG or SSH) to verify commit authenticity
- [ ] Capture uncommitted changes as artifacts when agent times out
- [ ] Set up Credo for Elixir linting (add to PR checks)
- [ ] Add a second agent (probe-2) with different focus
- [ ] Add reviewer agent that runs on PR open and can approve/merge
- [ ] Better timeout handling - warn agent before timeout so they can wrap up
- [ ] Track run history - what each agent accomplished over time
- [ ] Better agent identity in GitHub comments
  - Currently all comments show as "github-actions" bot
  - Want to distinguish which agent posted (e.g., "probe-1", "probe-2")
  - Options: custom GitHub App per agent, or prefix comments with agent name

## Ideas (not ready yet)

- Add analyst agent for system optimization
  - Dedicated agent that reviews workflow run logs from all agents (including itself)
  - Looks for: repeated patterns, inefficiencies, unmet needs, improvement opportunities
  - Could suggest: pre-loading common info in prompts, workflow changes, new tools
  - Runs on trigger or schedule, like other agents
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
- [x] Create per-agent notepad system
