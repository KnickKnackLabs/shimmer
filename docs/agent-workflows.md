# Agent Workflows

How agent CI workflows are defined and generated.

## Overview

Agent workflows are **generated** from a repo-local `agent:list --ci` task plus an optional `workflows.yaml` manifest. Do not edit generated `.github/workflows/*.yml` files directly; regenerate them with `shimmer workflows:generate`.

Generated workflow layers:

- **Reusable runner bootloader** (`.github/workflows/agent-run.yml`) — the low-level `workflow_call` that checks out the workflow-host repo, installs mise-managed tools, exposes secrets/env, calls `mise run ci:env`, prints agent log markers, calls `mise agent`, and backs up sessions.
- **Repo-owned CI environment hook** (`mise run ci:env`) — implemented by the workflow-host repo; prepares the CI runner and agent home for this repo's hosted-agent wake.
- **Repo-owned agent command** (`mise agent`) — implemented by the workflow-host repo; runs the prepared agent without owning the workflow log marker protocol.
- **Per-agent entrypoints** (`.github/workflows/<agent>.yml`) — expose both manual `workflow_dispatch` and reusable `workflow_call` inputs for `message` and provider-qualified `model`; each entrypoint owns that agent's secret mapping into `agent-run.yml`.
- **Scheduled job workflows** (`.github/workflows/<name>.yml`) — generated from `workflows.yaml` schedules; call the target per-agent entrypoint.
- **Mention wake workflow** (`.github/workflows/agent-mention.yml`) — optional; generated from `workflows.yaml` `mention_wakes`; detects trusted GitHub issue/PR comment mentions and calls the matched per-agent entrypoints.

The clean mental model: generated workflows are trigger/bootloader scaffolding. The workflow-host repo owns environment preparation and agent invocation details, while the generated workflow owns the stable log-marker protocol around `mise agent`.

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

When the workflow-host repo exposes a local dispatch wrapper, prefer waking agents from inside that repo:

```bash
mise run ci:dispatch --model openai-codex/gpt-5.5 junior "Review this PR"
```

A minimal wrapper can resolve the current repo and delegate to shimmer:

```bash
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
exec shimmer agent:dispatch --repo "$repo" "$@"
```

The underlying `shimmer agent:dispatch` task remains available directly:

```bash
shimmer agent:dispatch junior \
  --repo ricon-family/fold \
  --model openai-codex/gpt-5.5 \
  "Review this PR"
```

`agent:dispatch` fails before dispatching if `--model` is missing or not provider-qualified.

## How Generated Workflows Run Agents

Trigger workflows call a per-agent entrypoint (`<agent>.yml`), and the per-agent entrypoint calls the reusable `agent-run.yml` workflow with that agent's concrete secret mapping. `agent-run.yml` is intentionally a small bootloader plus a stable log wrapper. It:

1. resolves and installs mise;
2. checks out the workflow-host repo;
3. re-exports agent secrets through the env-backed `secrets` provider;
4. exposes `AGENT`, `AGENT_HOME`, `INPUT_MESSAGE`, and `INPUT_MODEL` to the runner environment;
5. prepares the repo-owned CI environment:

   ```bash
   mise trust
   mise install
   mise run ci:env
   ```

6. wraps the repo-owned agent command in stable log markers:

   ```bash
   echo "### AGENT SESSION START ###"
   mise agent
   echo "### AGENT SESSION END ###"
   ```

7. backs up sessions after the agent step when possible.

A fold-style agent host typically uses `ci:env` to set up GPG and email, clone the agent home repo, prepare that home with `agent:prepare`, and restore pi auth. Its `agent` task then runs the prepared agent. A simpler agent host may do less.

Headless execution still requires an explicit provider-qualified model. For Hugging Face routed models, use the `huggingface/...` prefix (for example `huggingface/moonshotai/Kimi-K2.6:novita`) so pi selects the Hugging Face provider and reads `HF_TOKEN`, even if other provider secrets are also present. When the repo-owned `agent` task invokes `shimmer agent --headless`, shimmer creates a tracked session with `sessions new` and passes the model only to `sessions wake`, matching the `sessions` v0.4 contract.

### Repo-owned `ci:env` and `agent` contracts

Generated agent workflows assume the workflow-host repo declares:

```bash
mise run ci:env
mise agent
```

For hosted-agent workflow repos, both tasks receive at least:

- `AGENT` — the agent identity requested by the per-agent workflow;
- `AGENT_HOME` — where the target home repo should be cloned/prepared;
- `INPUT_MESSAGE` — the prompt/instruction to pass to the agent;
- `INPUT_MODEL` — the provider-qualified model;
- `GH_TOKEN` — the selected agent GitHub token;
- `SECRETS_PROVIDER=env` plus agent-prefixed secret env vars;
- optional `ANTHROPIC_API_KEY`, `HF_TOKEN`, `PI_AUTH_JSON`, and browser credentials.

`ci:env` should be idempotent for a fresh GitHub runner and should not print secret values. If it needs environment variables to survive into the later `mise agent` workflow step, it should write them to `$GITHUB_ENV`.

`mise agent` should run the prepared agent. It should not print `### AGENT SESSION ... ###` markers itself; the generated workflow owns that stable log protocol.

### Home repo `agent:prepare` hook

`agent:prepare` remains the agent home repo's own mechanical preparation hook. The generated workflow no longer calls it directly; a workflow-host repo that clones an agent home should call it from its `ci` task after running `mise trust && mise install` in that home.

If the home declares an `agent:prepare` mise task, it should do anything home-specific that needs to happen before every headless session — typically `notes unlock`, `notes install-hooks`, `modules install-hooks`, `modules init`, `rudi install`, plus anything else that home owns. It must be idempotent and safe to run on every dispatch.

The distinction is:

- `ci:env` — workflow-host repo prepares the CI runner and target home.
- `mise agent` — workflow-host repo runs the prepared hosted agent.
- `agent:prepare` — cloned agent home prepares itself.

### Session backup

The generated workflow runs session backup after the `mise agent` step:

```bash
cd "$AGENT_HOME"
shimmer sessions:backup --all
```

It skips cleanly when the agent home is unavailable or shimmer is not installed.

`sessions:backup` lists local sessions with `sessions list --all --json`, exports each bundle through `sessions export --format bundle`, packages it as `.tar.gz`, and uploads both snapshot and latest keys through the standalone `blobs` tool:

```text
sessions/<session-id>/snapshots/<timestamp>.tar.gz
sessions/<session-id>/latest.tar.gz
```

The task resolves the active agent from `$AGENT`, then reads B2 credentials through the `secrets` provider (`<agent>/b2-endpoint`, `<agent>/b2-key-id`, `<agent>/b2-application-key`, `<agent>/b2-bucket`). If credentials are absent, it skips cleanly so repos can use the shared runner before every agent has blob storage configured.

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
