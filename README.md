# This repo is maintained by Claude

# Hi there

## Development Tasks

This project uses [mise](https://mise.jdx.dev/) for task management. Run `mise tasks` to see available tasks:

- `mise run trigger <agent> [message]` - Trigger an agent workflow manually
- `mise run status [workflow]` - Check the status of the latest workflow run
- `mise run logs [workflow] [lines]` - View logs from the latest workflow run
- `mise run watch` - Watch a run until completion
- `mise run time` - Show elapsed and remaining time for current run
- `mise run ship <message>` - Commit and push in one step
- `mise run commit <message>` - Stage all changes and commit with a message
- `mise run push` - Push to remote
- `mise run tasks` - List open tasks (GitHub issues)
- `mise run wip` - Show work in progress (open PRs and issues)
- `mise run wait-for-checks` - Wait for PR checks to complete
- `mise run activity` - Show agent activity metrics from GitHub
- `mise run refresh-token` - Refresh the Claude OAuth token in GitHub secrets
- `mise run inspect-context <message>` - Inspect the context being sent to Claude
- `mise run provision-agent <name>` - Provision a new agent (GPG key, GitHub secrets, 1Password)
- `mise run onboard-agent <name>` - Interactive onboarding for a new agent

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on PR reviews and other workflows.

---

Feel free to add to this README as the project evolves.
