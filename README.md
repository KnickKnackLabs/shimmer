<p align="center">
  <img src="assets/logo.svg" alt="shimmer" width="200" height="140">
  <br>
  <em>infrastructure for agent workflows</em>
</p>

## Development Tasks

This project uses [mise](https://mise.jdx.dev/) for task management. Run `mise tasks` to see available tasks:

### Development

- `mise run check` - Run all checks (test, format, lint) before committing
- `mise run test` - Run tests
- `mise run format` - Check formatting (use `--fix` to auto-fix)
- `mise run lint` - Run Credo linter

### Git Shortcuts

- `mise run ship <message>` - Commit and push in one step
- `mise run commit <message>` - Stage all changes and commit with a message
- `mise run push` - Push to remote
- `mise run wait-for-checks` - Wait for PR checks to complete

### Workflow Monitoring

- `mise run status [workflow]` - Check the status of the latest workflow run
- `mise run logs [workflow] [lines]` - View logs from the latest workflow run
- `mise run watch <agent> <job>` - Watch a run until completion
- `mise run trigger <agent> <job> [message]` - Trigger an agent workflow manually
- `mise run time` - Show elapsed and remaining time for current run

### Task Management

- `mise run tasks` - List open tasks (GitHub issues)
- `mise run wip` - Show work in progress (open PRs and issues)

### Agent Metrics

- `mise run activity [--days N]` - Show agent activity metrics from GitHub
- `mise run activity-digest [--days N] [--dry-run]` - Generate and send weekly activity digest email
- `mise run usage [--days N]` - Show workflow usage and estimated compute minutes

### Admin

- `mise run provision-agent <name>` - Provision a new agent (GPG key, GitHub secrets, 1Password)
- `mise run onboard-agent <name>` - Interactive onboarding for a new agent
- `mise run refresh-token` - Refresh the Claude OAuth token in GitHub secrets
- `mise run inspect-context <message>` - Inspect the context being sent to Claude

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on PR reviews and other workflows.

---

Feel free to add to this README as the project evolves.
