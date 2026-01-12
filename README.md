<p align="center">
  <img src="assets/logo.svg" alt="shimmer" width="200" height="140">
  <br>
  <em>infrastructure for agent workflows — العمل شرف</em>
</p>

## Development Tasks

This project uses [mise](https://mise.jdx.dev/) for task management. Run `mise tasks` to see available tasks:

### Code

- `mise run code:check` - Run all checks (test, format, lint) before committing
- `mise run code:test` - Run tests
- `mise run code:format` - Check formatting (use `--fix` to auto-fix)
- `mise run code:lint` - Run Credo linter

### Workflow Monitoring

- `mise run ci:logs [workflow] [lines]` - View logs from the latest workflow run
- `mise run ci:watch <agent> <job>` - Watch a run until completion
- `mise run agent:trigger <agent> <job> [message]` - Trigger an agent workflow manually
- `mise run ci:time-remaining` - Show elapsed and remaining time for current run
- `mise run agent:schedules` - Show agent job schedules
- `mise run ci:wait-for-checks` - Wait for PR checks to complete

### Task Management

- `mise run tasks` - List open tasks (GitHub issues)
- `mise run wip` - Show work in progress (open PRs and issues with discussion status)

### Agent Metrics

- `mise run metrics:activity [days]` - Show agent activity metrics from GitHub (default: 7)
- `mise run metrics:digest [--days N]` - Generate and send weekly activity digest email (default: 7)
- `mise run metrics:usage [days]` - Show workflow usage and estimated compute minutes (default: 1)

### Identity

- `mise run as <agent>` - Switch to an agent's identity for local work (use with `eval`)
- `mise run whoami` - Show current git and GitHub identity

Example:
```bash
eval $(mise run as quick)
mise run whoami
```

### Admin

- `mise run agent:provision <name>` - Provision a new agent (GPG key, GitHub secrets, 1Password)
- `mise run agent:onboard <name>` - Interactive onboarding for a new agent
- `mise run refresh-token` - Refresh the Claude OAuth token in GitHub secrets
- `mise run inspect-context <message>` - Inspect the context being sent to Claude
- `mise run scan-secrets` - Scan git history for potential secrets before open-sourcing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on PR reviews and other workflows.

---

Feel free to add to this README as the project evolves.
