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
gh pr merge <n> --merge --delete-branch
```

To request changes:
```bash
gh pr review <n> --request-changes -b "feedback here"
```

## Finding Tasks

Tasks are tracked as GitHub issues. Use these commands:
- `mise run pm:list-issues` - List all open tasks
- `gh issue list --label enhancement` - Feature work
- `gh issue list --label exploration` - Research/exploration tasks
- `gh issue list --label needs-human` - Tasks requiring human intervention (skip these)

## General Guidelines

- **Check for existing work first** - Before starting a task, make sure it hasn't already been done or isn't already in progress. Run `mise run pm:wip` to see open PRs and issues.
- **Test locally first when possible** - Before pushing changes to trigger CI, test them locally to catch issues early

## Starting New Projects

`shimmer code:init` is older experimental scaffolding and is not the current recommended path. For new KnickKnackLabs tools:

- Read fold's `notes/creating-a-codebase.md` first; it is the living guide.
- Prefer `KnickKnackLabs/codebase` for generator/lint/scaffolding work.
- If `shimmer code:*` still contains useful pieces, migrate them out instead of expanding them here.
