# Agent Workflows

How agent workflows are defined and generated.

## Overview

Agent workflows are **generated** from a manifest file. Never edit `.github/workflows/<agent>-*.yml` directly - your changes will be overwritten.

## Structure

```
workflows.yaml              # Source of truth - defines agent/job/schedule
.github/templates/          # Workflow template
.github/workflows/*.yml     # Generated files (don't edit)
```

## The Manifest

`workflows.yaml` defines which agents run which jobs and when:

```yaml
jobs:
  probe:
    agents:
      quick:
        schedule: "0 */4 * * *"    # Every 4 hours
  triage:
    agents:
      rho:
        schedule: "0 14-22 * * *"  # Hourly during work hours
```

## Managing Workflows

**Add or modify agent schedules:**
```bash
# 1. Edit workflows.yaml
# 2. Regenerate workflow files
mise run workflows:generate

# 3. Commit both manifest and generated files
git add workflows.yaml .github/workflows/
git commit -m "Update agent schedules"
```

**Validate workflows match manifest:**
```bash
mise run workflows:check
```

This runs in CI to catch drift between the manifest and generated files.

## How It Works

The `workflows:generate` task:
1. Reads jobs and agents from `workflows.yaml`
2. For each agent/job pair, applies the template from `.github/templates/agent-job.yml`
3. Writes the result to `.github/workflows/<agent>-<job>.yml`

Generated workflows call the reusable `agent-run.yml` workflow, which:
- Sets up the agent's credentials (GPG, email, Matrix)
- Creates a working branch
- Runs the CLI: `mix shimmer --agent <agent> --job <job>`

## Adding a New Agent Job

1. Add the agent/job entry to `workflows.yaml`:
   ```yaml
   jobs:
     probe:
       agents:
         new-agent:
           schedule: "0 */6 * * *"
   ```

2. Ensure the agent has an identity in the caller repo's `agents/<agent>/CLAUDE.md`

3. Ensure the job has a prompt in `.jobs/<job>.txt`

4. Generate and commit:
   ```bash
   mise run workflows:generate
   git add workflows.yaml .github/workflows/
   git commit -m "Add new-agent probe workflow"
   ```
