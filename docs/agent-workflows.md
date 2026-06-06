# Agent Workflows

How agent CI workflows are defined and generated.

## Overview

Agent workflows are **generated** from a repo-local `agent:list --ci` task plus an optional `workflows.yaml` manifest. Do not edit generated `.github/workflows/*.yml` files directly; regenerate them with `shimmer workflows:generate`.

Generated workflow layers:

- **Reusable runner** (`.github/workflows/agent-run.yml`) — the low-level `workflow_call` that sets up credentials and runs `shimmer agent --headless`.
- **Per-agent entrypoints** (`.github/workflows/<agent>.yml`) — expose both manual `workflow_dispatch` and reusable `workflow_call` inputs for `message` and provider-qualified `model`; each entrypoint owns that agent's secret mapping into `agent-run.yml`.
- **Scheduled job workflows** (`.github/workflows/<name>.yml`) — generated from `workflows.yaml` schedules; call the target per-agent entrypoint.
- **Mention wake workflow** (`.github/workflows/agent-mention.yml`) — optional; generated from `workflows.yaml` `mention_wakes`; detects trusted GitHub issue/PR comment mentions and calls the matched per-agent entrypoints.

The clean mental model: `agent-run.yml` is the execution engine. All other generated workflows are trigger/caller workflows.

## Structure

```text
workflows.yaml                         # Optional source of truth for schedules and opt-in triggers
.github/templates/agent-run.yml        # Reusable agent runner template
.github/templates/agent-scheduled.yml  # Scheduled workflow template
.github/templates/agent-mention-detect.py  # Mention detector copied into target repos
.github/workflows/*.yml                # Generated files (do not edit directly)
.github/scripts/agent-mention-detect.py  # Generated/copied when mention_wakes.enabled=true
```

## Manifest Format

`workflows.yaml` can define scheduled agent jobs and opt-in trigger workflows:

```yaml
workflows:
  - name: junior-daily-checkin
    agent: junior
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Check your home repo for job instructions and execute them."

mention_wakes:
  enabled: true
  model: openai-codex/gpt-5.5
  allowed_associations: [OWNER, MEMBER]
```

Scheduled workflow fields:

- `name` — workflow filename stem (`.github/workflows/<name>.yml`); lowercase letters, numbers, and hyphens.
- `agent` — agent identity to run.
- `model` — provider-qualified model string, for example `openai-codex/gpt-5.5`.
- `schedule` — one or more cron expressions.
- `message` — instruction passed to the headless agent.

Mention wake fields:

- `enabled` — when true, generate `agent-mention.yml` and copy the detector script.
- `model` — provider-qualified model used for mention-triggered runs.
- `allowed_associations` — GitHub comment author associations allowed to wake agents. For public-safety, prefer `[OWNER, MEMBER]`; do not include broader associations unless the repo intentionally accepts that risk.

Mention wakes use the same roster as manual workflows, but they also need GitHub login metadata. Homes that enable `mention_wakes` must implement `mise run agent:list -- --ci --json` and include `github_login` for every wakeable agent. The older line-oriented `mise run agent:list -- --ci` contract remains supported for manual and scheduled workflows only. The generated detector is a stdlib-only Python script run with the GitHub-hosted runner's `python3`, so target repos do not need to declare an extra detector runtime. The detector matches configured GitHub logins, ignores naked agent-name aliases, strips blockquotes plus fenced/inline code, and leaves team fanout disabled.

## Managing Workflows

Add or modify schedules/triggers:

```bash
# 1. Edit workflows.yaml when changing schedules or opt-in triggers
# 2. Regenerate workflow files
shimmer workflows:generate

# 3. Commit both manifest and generated files/scripts
git add workflows.yaml .github/workflows/ .github/scripts/
git commit -m "Update agent workflows"
```

Validate generated files match the manifest and current agent roster:

```bash
shimmer workflows:generate --check
```

`workflows:generate --check` validates `workflows.yaml` when present and regenerates into a temporary directory to catch drift between committed workflows/scripts and generated output.

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

Trigger workflows call a per-agent entrypoint (`<agent>.yml`), and the per-agent entrypoint calls the reusable `agent-run.yml` workflow with that agent's concrete secret mapping. `agent-run.yml`:

1. Checks out the repo.
2. Installs mise-managed tools.
3. Sets up agent credentials (GPG, email, GitHub).
4. Clones the agent home repo.
5. Prepares the home repo via the `agent:prepare` hook (see below).
6. Exposes provider API keys from workflow secrets (`ANTHROPIC_API_KEY`, `HF_TOKEN`) and restores pi auth when `PI_AUTH_JSON` is configured.
7. Runs:

   ```bash
   shimmer agent --headless --timeout "$RUN_TIMEOUT" --model "$INPUT_MODEL" "$INPUT_MESSAGE"
   ```

8. On completion or failure, backs up local session artifacts to blob storage when B2 credentials are configured.

Headless execution requires an explicit provider-qualified model. For Hugging Face routed models, use the `huggingface/...` prefix (for example `huggingface/moonshotai/Kimi-K2.6:novita`) so pi selects the Hugging Face provider and reads `HF_TOKEN`, even if other provider secrets are also present. Shimmer creates a tracked session with `sessions new` and passes the model only to `sessions wake`, matching the `sessions` v0.4 contract.

### Home repo `agent:prepare` hook

The `Prepare home repo` step is owned by the agent's home repo. After `mise trust && mise install` in the home, the workflow runs:

```bash
if mise tasks info agent:prepare >/dev/null 2>&1; then
  mise run agent:prepare
else
  echo "::warning::No agent:prepare task found in home repo; skipping home-specific preparation. ..."
fi
```

If the home declares an `agent:prepare` mise task, it runs. Otherwise the step emits a GitHub Actions `::warning::` annotation and continues — a missing hook does not fail the run.

**What `agent:prepare` should do:** anything home-specific that needs to happen before every headless session — typically `notes unlock`, `notes install-hooks`, `modules install-hooks`, `modules init`, `rudi install`, plus anything else that home owns. It must be idempotent and safe to run on every dispatch (CI re-runs it from scratch each time; locally agents may also invoke it during interactive sessions).

**Why it's a delegation hook, not a hardcoded block:** the workflow template used to assume every home spoke den/fold's tooling stack (notes/rudi/modules). Agent homes vary — some may use only a subset, some may need additional setup (cache warming, secret pre-fetch). The hook hands ownership of that decision to each home repo's `mise.toml`.

### Session backup

The `Back up sessions` workflow step runs with `if: always()` after the agent step:

```bash
shimmer sessions:backup --all
```

`sessions:backup` lists local sessions with `sessions list --all --json`, exports each bundle through `sessions export --format bundle`, packages it as `.tar.gz`, and uploads both snapshot and latest keys through the standalone `blobs` tool:

```text
sessions/<session-id>/snapshots/<timestamp>.tar.gz
sessions/<session-id>/latest.tar.gz
```

The task resolves the active agent from `$AGENT` (set by the workflow), then reads B2 credentials through the `secrets` provider (`<agent>/b2-endpoint`, `<agent>/b2-key-id`, `<agent>/b2-application-key`, `<agent>/b2-bucket`). If credentials are absent, it skips cleanly so repos can use the shared runner before every agent has blob storage configured.

For local validation:

```bash
shimmer sessions:backup --dry-run <session-id>...
```

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

## Enabling Mention Wakes

1. Add or update the `mention_wakes` block in `workflows.yaml`:

   ```yaml
   mention_wakes:
     enabled: true
     model: openai-codex/gpt-5.5
     allowed_associations: [OWNER, MEMBER]
   ```

2. Ensure `agent:list --ci` exposes only agents that should be wakeable from that repo, and `agent:list --ci --json` returns records with `name`, `ci`, and `github_login` for each of them.

3. Generate and check workflows:

   ```bash
   shimmer workflows:generate
   shimmer workflows:generate --check
   ```

4. Commit `workflows.yaml`, `.github/workflows/agent-mention.yml`, and `.github/scripts/agent-mention-detect.py`.

Team fanout is intentionally not generated yet. Add it only after designing authorization, caps, jitter, and per-thread/per-agent concurrency semantics.
