# Starting New Projects

How to spin off a new codebase using shimmer.

## Overview

When starting a new project, use `shimmer code:init` to bootstrap it with context. This creates a new directory with:

- A `CLAUDE.md` seeded with planning context
- A `README.md` with shimmer setup instructions
- An initial git commit

The key benefit: when you start a fresh Claude Code session in the new directory, it picks up the context from your planning discussion instead of starting from scratch.

## Workflow

### 1. Plan Together

Start a Claude session in shimmer and discuss the new project:

- What does it do?
- What's the architecture?
- What are the key decisions?
- Any constraints or requirements?

This conversation becomes the seed for the new project's `CLAUDE.md`.

### 2. Initialize

Claude runs `code:init` with the planning context:

```bash
shimmer code:init ~/projects/my-thing --name "My Thing" <<'EOF'
# My Thing

Brief description of what this project does.

## Overview

Purpose and goals established during planning.

## Architecture

- Key component 1
- Key component 2

## Decisions

- Decision 1: We chose X because Y
- Decision 2: Using Z for this reason

## Development

How to run/build/test (if known).

## Notes

Any other context the next session should know.
EOF
```

### 3. Continue

Start a fresh Claude Code session in the new directory:

```bash
cd ~/projects/my-thing
claude
```

The session loads `CLAUDE.md` and has full context from the planning discussion.

## What Makes a Good Seed

The seed should capture enough context that a fresh session can continue without re-explaining. Include:

- **Purpose**: What the project does and why it exists
- **Architecture**: High-level structure and key components
- **Decisions**: Choices made during planning and their rationale
- **Constraints**: Requirements, limitations, or guidelines
- **Next steps**: What to work on first (if known)

Don't include:
- Generic boilerplate (the session can generate that)
- Obvious things (standard tooling, common patterns)
- Temporary notes that won't matter later

## Discovery

Run `shimmer code:init:welcome` to:

- See this workflow explained
- List existing projects
- Check agent availability

## Quick Reference

| Task | Command |
|------|---------|
| Initialize new codebase | `shimmer code:init <path> [--name <name>]` |
| See workflow and projects | `shimmer code:init:welcome` |

## After Initialization

Once the codebase is created, you may want to:

1. **Set up GitHub** - Create a repo and push
2. **Add mise tooling** - Useful for consistent dev environments
3. **Configure agent workflows** - If you want scheduled agent runs (see `docs/agent-workflows.md`)

These are optional and depend on your project's needs.
