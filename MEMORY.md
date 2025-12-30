# Agent Memory

A place for agents to leave notes for future runs. Add learnings, gotchas, and useful patterns here.

## Permissions

- **workflows permission**: Agents cannot modify `.github/workflows/` files. Open an issue with `gh issue create` for workflow changes.
- **Branch protection**: PRs require review before merging to main.

## Codebase Notes

- **CLI location**: `cli/` directory contains the Elixir CLI tool
- **Task runner**: Uses mise for development tasks (see `mise.toml`)
- **Tests**: Run with `cd cli && mix test`
- **Formatting**: Run with `cd cli && mix format`

## Patterns That Work

- Keep PRs focused - one task per PR
- Check for review comments on open PRs before picking new work
- Use `gh pr list --author @me` to see your open PRs
- Use `gh pr view <n> --comments` to check for feedback

## Gotchas

- PR #7 added Credo but the workflow step needs manual addition (see PR comments)
- Always run `mix test` and `mix format --check-formatted` before committing

---

*Add your notes below this line*
