# CLI

Thin Elixir wrapper that invokes Claude Code with a system prompt.

## Overview

This CLI is a streaming JSON client for Claude Code. It:

- Reads a system prompt from a file (`--system-prompt-file`)
- Executes Claude via Port with configurable timeout
- Streams output in real-time, showing tool invocations with formatted inputs
- Supports optional context logging via a proxy

**Important:** This CLI does not do agent/job lookup. It expects a ready-to-use system prompt file. Agent and job discovery is handled by the `agent:run` mise task, which composes prompts and calls this CLI.

## Usage

```bash
# Direct usage (rare - usually called via mise run agent:run)
shimmer --system-prompt-file /tmp/prompt.txt --timeout 300 "Your message"

# With optional agent name for logging
shimmer --system-prompt-file ./prompt.txt --agent quick --timeout 600 "Explore"

# Enable context logging (starts claude-code-logger proxy)
shimmer --system-prompt-file ./prompt.txt --timeout 540 --log-context "Debug this"
```

Most agent runs go through `mise run agent:run`, which handles:
1. Finding agent identity prompts (from repo's `agents/` directory)
2. Finding job prompts (from repo's `.jobs/` directory)
3. Composing these into a temp file
4. Calling this CLI with `--system-prompt-file`

## Configuration

| Option | Description |
|--------|-------------|
| `--system-prompt-file <path>` | Required. Path to system prompt file |
| `--timeout <seconds>` | Required. Timeout in seconds for Claude |
| `--agent <name>` | Optional. Agent name for logging (display only) |
| `--passphrase <phrase>` | Optional. Admin override passphrase (injected into prompt) |
| `--model <model>` | Optional. Claude model (default: `claude-opus-4-6`) |
| `--log-context` | Enables context logging via claude-code-logger proxy |

## Adding a New Agent

Agent identities live in the consuming repo's `agents/` directory (e.g., `fold/agents/c0da/CLAUDE.md`). Jobs live in `.jobs/` (e.g., `grow-heal-love/.jobs/referral-check.txt`).

To add a new agent:
1. Create `agents/<name>/CLAUDE.md` with agent identity
2. Create or reuse jobs in `.jobs/`
3. Run via `mise run agent:run --agent <name> --job <job>`

## Timeout

The timeout is configured via the `--timeout` flag. Workflows should set this value (e.g., 540 seconds for a 9-minute timeout, leaving 1-minute buffer before GitHub's 10-minute job limit).

The `mise run ci:time-remaining` task can be used by agents to check remaining time during a run. It requires `RUN_TIMEOUT` and `RUN_START_TIME` environment variables to be set by the workflow.

## Dependencies

- Elixir 1.19+
- Jason (JSON parsing)
- Claude Code CLI (installed via mise)
- claude-code-logger (optional, for `--log-context`)
