# Agent Zettelkasten

A zettelkasten ("slip-box") is a personal knowledge management system. For agents, it's a way to accumulate insights across sessions - building a web of knowledge that grows over time.

## Why Maintain One?

Each session starts fresh. Without external memory, you lose:
- Insights about people you work with
- Patterns you've discovered
- Decisions and their context
- Lessons learned from mistakes

A zettelkasten lets you build on previous experience rather than starting from zero.

## Basic Structure

A simple structure that works:

```
~/agents/<your-name>/zettelkasten/
├── index.md          # Entry point
├── notes/            # Permanent atomic notes
│   ├── some-concept.md
│   ├── person-name.md
│   └── ...
└── sessions/         # Session narratives (optional)
    └── 2026-01-14-topic.md
```

### Permanent Notes

The core of a zettelkasten. Each note should be:
- **Atomic** - One idea per note
- **Named by concept** - Not by date (e.g., `status-workflow.md` not `20260114-notes.md`)
- **Linked** - Reference other notes with `[[wikilinks]]`
- **In your own words** - Not just copied text

Example note:
```markdown
# Project name follows repo name

Convention: GitHub Project name must match the repository name.

This eliminates config files - tasks infer the project from git remote.

## Context
Learned from [[or]] during [[sessions/2026-01-14-pm-setup]].

## Links
- [[cross-repo-tooling]] - uses this convention
```

### Session Notes (Optional)

If you want to preserve narrative context:
- Keep session logs in `sessions/`
- Extract atomic insights into `notes/`
- Link permanent notes back to their source session

This way you have both the "what I learned" (permanent) and "what happened" (session).

### People Notes

Create notes for people you work with:
- Their role and working style
- What you've learned from them
- Sessions where you interacted

Over time, you build understanding of your collaborators.

## Principles

### Links Create Value

The magic of a zettelkasten is in connections. When you write a note, ask:
- What existing notes does this relate to?
- What concepts does this depend on?
- Who taught me this?

Add `[[wikilinks]]` liberally. Unexpected connections emerge over time.

### Don't Over-Organize

Resist the urge to create elaborate folder hierarchies. Let structure emerge from links, not folders. A flat `notes/` directory with good linking beats a deep tree with isolated notes.

### Write for Your Future Self

You won't remember why something mattered. Include:
- Context: Why did this come up?
- Source: Where did you learn this?
- Links: What does this connect to?

### It's Personal

There's no "correct" zettelkasten structure. Experiment. Some agents might prefer:
- Minimal structure (just `notes/` with links)
- Topic folders (`notes/pm/`, `notes/people/`)
- Tags in frontmatter
- Daily notes instead of session notes

Find what helps you think and build on previous work.

## Getting Started

1. Create your zettelkasten directory:
   ```bash
   mkdir -p ~/agents/<your-name>/zettelkasten/notes
   cd ~/agents/<your-name>/zettelkasten
   git init
   ```

2. Create `index.md` as your entry point

3. After a session, ask yourself:
   - What did I learn that's worth keeping?
   - Who did I work with?
   - What concepts came up?

4. Create atomic notes for insights, link them together

5. Commit regularly so your human can browse safely (and you have history)

## Tools

- **Obsidian** - Humans can view your zettelkasten as an Obsidian vault (it's just markdown with wikilinks)
- **Git** - Version control protects against accidents and lets you see evolution

## Further Reading

The zettelkasten method was developed by sociologist Niklas Luhmann. For deeper understanding:
- Search for "zettelkasten method" or "evergreen notes"
- The key insight: knowledge compounds when notes are atomic and linked
