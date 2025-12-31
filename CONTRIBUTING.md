# Contributing

Guidelines for working on this codebase. These are tentative - feel free to improve them.

## Pull Request Reviews

When reviewing a PR, check:
1. **Does the diff make sense?** - `gh pr diff <n>`
2. **Is the change focused?** - One concern per PR
3. **Are there any obvious bugs or issues?**
4. **Do tests pass?** - `gh pr checks <n>`

To approve and merge:
```bash
gh pr review <n> --approve
gh pr merge <n> --squash --delete-branch
```

To request changes:
```bash
gh pr review <n> --request-changes -b "feedback here"
```

## Finding Tasks

Tasks are tracked as GitHub issues. Use these commands:
- `mise run tasks` - List all open tasks
- `gh issue list --label enhancement` - Feature work
- `gh issue list --label exploration` - Research/exploration tasks
- `gh issue list --label needs-human` - Tasks requiring human intervention (skip these)

## Agents

Available agents are defined by prompt files in `cli/lib/prompts/agents/`:

- **probe-1** - General-purpose agent that picks up issues and implements them
- **critic** - Finds things to improve and creates issues
- **dedup** - Detects and flags duplicate issues and PRs

Each agent has a notepad in `notepads/` for persisting notes between runs.

To add a new agent:
1. Create a prompt file at `cli/lib/prompts/agents/<name>.txt`
2. Create a notepad at `notepads/<name>.md`
3. Add a workflow file at `.github/workflows/<name>.yml` (requires human - see issue #34)

## General Guidelines

- **Check for existing work first** - Before starting a task, make sure it hasn't already been done or isn't already in progress. Run `mise run wip` to see open PRs and issues.
- **Test locally first when possible** - Before pushing changes to trigger CI, test them locally to catch issues early

## Deriving New Projects

This repository can serve as a foundation for new projects. To derive a new project:

1. Create the new repository from this template:
   ```bash
   gh repo create ricon-family/<project-name> --template ricon-family/shimmer --private
   gh repo clone ricon-family/<project-name>
   cd <project-name>
   ```

2. Update `CLAUDE.md` to describe the new project's purpose

3. Optionally, update agent definitions in the Elixir code if the project needs agents with different roles or focus areas

4. Create GitHub issues to define initial work for agents

5. Agents will begin working on the next scheduled workflow run

The derived project inherits the full agent infrastructure (CLI, workflows, mise tasks) and can evolve independently while tracing its lineage back to shimmer.
