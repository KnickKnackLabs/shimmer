# Agent Workflows

How agent CI workflows are defined and generated.

## Overview

Agent workflows are **generated** from a repo-local `workflows.yaml` manifest plus shimmer's workflow templates. Do not edit generated `.github/workflows/*.yml` files directly; regenerate them with `shimmer workflows:generate`.

There are two generated workflow types:

- **Per-agent manual workflows** (`.github/workflows/<agent>.yml`) — expose `workflow_dispatch` inputs for `message` and required provider-qualified `model`.
- **Scheduled job workflows** (`.github/workflows/<name>.yml`) — call the reusable `agent-run.yml` workflow on a cron schedule.

Both ultimately call `.github/workflows/agent-run.yml`, which sets up credentials and runs `shimmer agent --headless`.

## Structure

```text
workflows.yaml                    # Source of truth for scheduled jobs
.github/templates/agent-run.yml   # Reusable agent runner template
.github/templates/agent-scheduled.yml  # Scheduled workflow template
.github/workflows/*.yml           # Generated files (do not edit directly)
```

## Manifest Format

`workflows.yaml` defines scheduled agent jobs:

```yaml
workflows:
  - name: junior-daily-checkin
    agent: junior
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Check your home repo for job instructions and execute them."
```

Required fields:

- `name` — workflow filename stem (`.github/workflows/<name>.yml`); lowercase letters, numbers, and hyphens.
- `agent` — agent identity to run.
- `model` — provider-qualified model string, for example `openai-codex/gpt-5.5`.
- `schedule` — one or more cron expressions.
- `message` — instruction passed to the headless agent.

## Managing Workflows

Add or modify scheduled jobs:

```bash
# 1. Edit workflows.yaml
# 2. Regenerate workflow files
shimmer workflows:generate

# 3. Commit both manifest and generated files
git add workflows.yaml .github/workflows/
git commit -m "Update agent schedules"
```

Validate workflows match the manifest:

```bash
shimmer workflows:generate --check
```

`workflows:generate --check` validates `workflows.yaml` when present and regenerates into a temporary directory to catch drift between committed workflows and generated output.

## Manual Agent Dispatch

Generated per-agent workflows expose manual dispatch inputs:

- `message` — required instruction for the agent.
- `model` — required provider-qualified model string.

Use shimmer's dispatch task to wake an agent:

```bash
shimmer agent:dispatch junior \
  --model openai-codex/gpt-5.5 \
  "Review this PR"
```

`agent:dispatch` fails before dispatching if `--model` is missing or not provider-qualified.

## How Generated Workflows Run Agents

Generated workflows call the reusable `agent-run.yml` workflow, which:

1. Checks out the repo.
2. Installs mise-managed tools.
3. Sets up agent credentials (GPG, email, Matrix, GitHub, optional blob storage).
4. Clones the agent home repo.
5. Restores pi auth when `PI_AUTH_JSON` is configured.
6. Runs:

   ```bash
   shimmer agent --headless --timeout "$RUN_TIMEOUT" --model "$INPUT_MODEL" "$INPUT_MESSAGE"
   ```

Headless execution requires an explicit provider-qualified model. Shimmer creates a tracked session with `sessions new` and passes the model only to `sessions wake`, matching the `sessions` v0.4.0 contract.

## Adding a Scheduled Job

1. Add an entry to `workflows.yaml`:

   ```yaml
   workflows:
     - name: quick-probe
       agent: quick
       model: openai-codex/gpt-5.5
       schedule:
         - "0 */4 * * *"
       message: "Run the probe job and report findings."
   ```

2. Ensure the target repo's `agent:list --ci` includes the agent.

3. Generate and check workflows:

   ```bash
   shimmer workflows:generate
   shimmer workflows:generate --check
   ```

4. Commit the manifest and generated workflow files.
