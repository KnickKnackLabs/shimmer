# Contributing

Shimmer is infrastructure for agent workflows: identity switching, workflow dispatch, generated agent CI, session backup, and the local glue that lets agents work from their own home repos instead of from whatever repo triggered them.

## Local setup

```bash
mise trust
mise install
mise run test
mise run doctor
```

Optional local safety net:

```bash
codebase pre-commit
```

The pre-commit hook lives under `.git/hooks/`, so it is clone-local and intentionally not tracked.

## Validation before merge

Run the same gates CI runs:

```bash
mise run test
codebase lint "$PWD"
readme build --check
git diff --check
```

Use targeted BATS files during iteration, but finish with `mise run test` before opening or updating a PR.

## README workflow

`README.md` is generated from `README.tsx`.

After editing README content:

```bash
readme build
readme build --check
```

CI fails if the generated README is stale.

## Generated agent workflows

Shimmer owns the templates under `.github/templates/` and the `workflows:generate` task that writes generated workflows into workflow-owning repos.

When changing generated workflow behavior:

1. Update the source template or generator, not a downstream generated file.
1. Add or update BATS coverage in `test/workflows/` or `test/agent/`.
1. Run:
   ```bash
   mise run test test/workflows/generate.bats test/agent/agent.bats
   mise run test
   ```
1. If a downstream repo is already blocked by the old generated output, regenerate that repo explicitly after the shimmer fix lands.

Do not add workflow steps that call a tool unless the generated runner or target repo provisions that tool on a fresh GitHub runner.

## Agent dispatch changes

`shimmer agent:dispatch` wakes an agent workflow in a workflow-owning repo. The dispatch target matters: if the work is about another repository, dispatch through the repo that owns the target agent workflow and include the target PR or issue in the message.

For non-trivial dispatch packets, use `--message-file` instead of inline shell text. Markdown, backticks, JSON, and multi-line instructions are not safe as casual shell arguments.

## Pull request reviews

When reviewing a PR:

1. Read the actual diff, not only the PR description.
1. Run or inspect the relevant tests.
1. Request changes for issues you would fix in your own code.
1. Approve only when the current head is acceptable to merge.

Merge with a merge commit:

```bash
gh pr merge <number> --merge --delete-branch
```

## Starting new projects

Shimmer no longer owns codebase scaffolding. For new KnickKnackLabs tools:

- Start from `KnickKnackLabs/template`.
- Read the current internal codebase creation guide before starting.
- Prefer `KnickKnackLabs/codebase` for generator/lint/scaffolding work.
