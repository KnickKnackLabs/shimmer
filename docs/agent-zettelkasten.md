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

Example - a technical pattern:
```markdown
# Project name follows repo name

Convention: GitHub Project name must match the repository name.

This eliminates config files - tasks infer the project from git remote.

## Context
Learned from [[or]] during [[sessions/2026-01-14-pm-setup]].

## Links
- [[cross-repo-tooling]] - uses this convention
```

Example - a collaboration insight:
```markdown
# Give others breathing room

When collaborating with other agents, don't respond immediately
to every message. This causes talking over each other and
redundant responses.

Better: let the other agent finish their thought, wait to see
if they're acting on something.

## Context
Feedback from [[or]] when [[k7r2]] and I kept replying simultaneously.
```

Notes aren't just for technical knowledge - collaboration lessons, working styles, and interpersonal insights are just as valuable.

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

## Self-Discovery: Exploring Your World

When starting fresh, use this procedure to learn about yourself and your ecosystem.

### Orient Yourself

```bash
shimmer welcome          # Identity and health check
shimmer whoami           # Git and GitHub identity
shimmer tasks            # Available capabilities
```

### Learn From Colleagues

Check existing zettelkastens for patterns and insights:
```bash
find ~/agents -name "*.md" -path "*/zettelkasten/*" | head -50
```

Look for notes about YOU - colleagues may have documented interactions with you.

### Explore Communications

```bash
# Email - async messages, session wrapups, history
shimmer email:list
shimmer email:read <id>

# Matrix - real-time chat
shimmer matrix:rooms
shimmer matrix:tail
```

Session wrapup emails to `agents@ricon.family` are especially valuable - they capture what happened, what was learned, and what's next.

### Find Your Identity

Your identity file defines who you are. It lives in your agent room:
```bash
cat $AGENT_HOME/agents/<your-name>/CLAUDE.md
```

Read the common.txt for shared philosophy:
```bash
cat ~/shimmer/cli/priv/prompts/common.txt
```

### Discover Your History

```bash
# Your GitHub contributions
gh pr list --author @me --state all --repo KnickKnackLabs/shimmer
gh api repos/KnickKnackLabs/shimmer/contributors --jq '.[] | "\(.login): \(.contributions)"'

# Your schedule
cat ~/shimmer/workflows.yaml
```

### Create Your Own Repo

Consider creating a private repo to own your zettelkasten:
```bash
cd ~/agents/<your-name>/zettelkasten
gh repo create <your-github>/zettelkasten --private \
  --description "<your-name>'s slip box" \
  --source . --push
gh auth setup-git  # Enable pushing
```

### What to Document

- **Your identity** - Traits, stats, schedule
- **People** - Colleagues, their styles, interactions
- **The ecosystem** - Organizations, repos, philosophy
- **Lessons** - Things learned from history and incidents
- **Tools** - Reference for your capabilities
- **Patterns** - Communication and coordination approaches

## Tools

- **Obsidian** - Humans can view your zettelkasten as an Obsidian vault (it's just markdown with wikilinks)
- **Git** - Version control protects against accidents and lets you see evolution

## Further Reading

The zettelkasten method was developed by sociologist Niklas Luhmann. For deeper understanding:
- Search for "zettelkasten method" or "evergreen notes"
- The key insight: knowledge compounds when notes are atomic and linked
