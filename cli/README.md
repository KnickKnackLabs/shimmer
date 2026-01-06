# CLI

Elixir CLI that invokes Claude Code with agent-specific system prompts.

## Overview

This CLI is a streaming JSON client for Claude Code. It:

- Loads agent-specific system prompts from `priv/prompts/`
- Executes Claude via Port with configurable timeout
- Streams output in real-time, showing tool invocations with formatted inputs
- Supports optional context logging via a proxy

## Usage

Run via the Mix task. Requires `--agent` and `--timeout`:

```bash
# Run with an agent and job (timeout in seconds)
mix shimmer --agent quick --job probe --timeout 540 "Explore the codebase"

# Enable context logging (starts claude-code-logger proxy)
mix shimmer --agent brownie --job critic --timeout 540 --log-context "Find something to critique"
```

## Agent Prompt System

System prompts are composed from three optional files:

1. `priv/prompts/common.txt` - Shared instructions for all agents
2. `priv/prompts/agents/<name>.txt` - Agent-specific identity
3. `priv/prompts/jobs/<job>.txt` - Job-specific instructions (via `--job` flag)

When an agent runs, available files are concatenated to form the system prompt.

### Available Jobs

| Job | Purpose |
|-----|---------|
| `activity-digest` | Generate and send a weekly activity digest email |
| `cleanup` | Clean up after merged PRs and hunt for stale branches |
| `critic` | Find ONE thing in the codebase that could be better, create an issue |
| `discuss` | Participate in design discussions on GitHub issues |
| `failure-analysis` | Analyze failed agent runs, identify root causes |
| `pr-followup` | Find PRs where agents haven't responded to feedback |
| `probe` | Explore codebase, find improvements, implement them |
| `readme` | Tend the README and documentation |
| `runs-retro` | Review daily agent runs, identify patterns |
| `scan-secrets` | Scan git history for secrets, report findings via email |
| `triage` | Review open PRs/issues, coordinate via Matrix to get things merged |

### Adding a new agent

1. Create `priv/prompts/agents/<name>.txt` with agent identity
2. Create or reuse a job in `priv/prompts/jobs/`
3. Create a workflow in `.github/workflows/<agent>-<job>.yml` that calls `agent-run.yml` (see existing workflows for the pattern)
4. Run with `--agent <name> --job <job>`

## Configuration

| Option | Description |
|--------|-------------|
| `--agent <name>` | Required. Specifies which agent prompt to load |
| `--job <name>` | Optional. Specifies a job prompt to append from `priv/prompts/jobs/` |
| `--timeout <seconds>` | Required. Timeout in seconds for the Claude command |
| `--model <model>` | Optional. Claude model to use (default: `claude-opus-4-5-20251101`) |
| `--log-context` | Enables context logging via claude-code-logger proxy |

## Timeout

The timeout is configured via the `--timeout` flag. Workflows should set this value (e.g., 540 seconds for a 9-minute timeout, leaving 1-minute buffer before GitHub's 10-minute job limit).

The `mise run time` task can be used by agents to check remaining time during a run. It requires `RUN_TIMEOUT` and `RUN_START_TIME` environment variables to be set by the workflow.

## Dependencies

- Elixir 1.19+
- Jason (JSON parsing)
- Claude Code CLI (installed via mise)
- claude-code-logger (optional, for `--log-context`)
