<p align="center">
  <img src="assets/logo.svg" alt="shimmer" width="200" height="140">
  <br>
  <em>infrastructure for agent workflows — العمل شرف</em>
</p>

## Quick Start

```bash
# Clone the repository
git clone https://github.com/KnickKnackLabs/shimmer.git ~/shimmer
cd ~/shimmer && mise trust && mise install

# Add to your shell config (~/.zshrc or ~/.bashrc)
eval "$(mise -C ~/shimmer run -q shell)"

# Reload your shell
source ~/.zshrc  # or source ~/.bashrc

# Verify it works
shimmer whoami
```

Now you can run `shimmer <task>` from anywhere.

## Tasks

This project uses [mise](https://mise.jdx.dev/) for task management. Run `shimmer tasks` to see all available tasks.

### Code

- `shimmer code:check` - Run all checks (test, format, lint) before committing
- `shimmer code:test` - Run tests
- `shimmer code:format` - Check formatting (use `--fix` to auto-fix)
- `shimmer code:lint` - Run Credo linter

### Workflow Monitoring

- `shimmer ci:logs [workflow] [lines]` - View logs from the latest workflow run
- `shimmer ci:watch <agent> <job>` - Watch a run until completion
- `shimmer agent:trigger <agent> <job> [message]` - Trigger an agent workflow manually
- `shimmer ci:time-remaining` - Show elapsed and remaining time for current run
- `shimmer agent:schedules` - Show agent job schedules
- `shimmer ci:wait-for-checks` - Wait for PR checks to complete (timeout 3 min)

### Task Management

- `shimmer pm:list-issues` - List open tasks (GitHub issues)
- `shimmer pm:wip` - Show work in progress (open PRs and issues with discussion status)

### Agent Metrics

- `shimmer metrics:activity [days]` - Show agent activity metrics from GitHub (default: 7)
- `shimmer metrics:digest [--days N]` - Generate and send weekly activity digest email (default: 7)
- `shimmer metrics:usage [days]` - Show workflow usage and estimated compute minutes (default: 1)

### Identity

- `shimmer as <agent>` - Switch to an agent's identity for local work (use with `eval`)
- `shimmer whoami` - Show current git and GitHub identity

Example:
```bash
eval $(shimmer as quick)
shimmer whoami
```

### Repository

- `shimmer repo:file <file>` - Fetch a file from all known projects
- `shimmer repo:file <file> --repo <repo>` - Fetch from a specific repo

Example:
```bash
shimmer repo:file README.md        # compare READMEs across projects
shimmer repo:file LICENSE          # check which repos are missing a license
shimmer repo:file CLAUDE.md        # audit agent context files
```

### Admin

- `shimmer agent:provision <name>` - Provision a new agent (GPG key, GitHub secrets, 1Password)
- `shimmer agent:onboard <name>` - Interactive onboarding for a new agent
- `shimmer agent:refresh-token` - Refresh the Claude OAuth token in GitHub secrets
- `shimmer inspect-context <message>` - Inspect the context being sent to Claude
- `shimmer scan-secrets` - Scan git history for potential secrets before open-sourcing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on PR reviews and other workflows.

---

Feel free to add to this README as the project evolves.
