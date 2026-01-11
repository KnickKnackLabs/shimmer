# GitHub Issues

## Overview

Issues are flexible tools for planning, discussing, and tracking work. They accommodate various use cases: bug reports, feature requests, ideas, and team discussions.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/learning-about-issues/about-issues

## Core Features

### Sub-Issues
Break larger work items into smaller, hierarchical sub-issues.

**Limits**:
- Max 100 sub-issues per parent
- Up to 8 levels of nesting

**Features**:
- Can add existing issues as sub-issues (even cross-repo)
- Integrates with Projects for filtering/grouping by hierarchy
- Progress visible on parent issue

**CLI Support via Extension**: The `gh` CLI doesn't natively support sub-issues, but the [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) extension provides full CLI access:

```bash
# Install
gh extension install yahsan2/gh-sub-issue

# Commands
gh sub-issue add <parent> <child>           # Link existing issue
gh sub-issue create --parent 123 --title "Task" --label bug --assignee @me
gh sub-issue list 123 --state open --json   # List with JSON output
gh sub-issue remove 123 456 --force         # Unlink sub-issue
```

Supports same flags as `gh issue create`: `--body`, `--label`, `--assignee`, `--milestone`, `--project`.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues

### Issue Dependencies
Define blocking relationships between issues.

**Relationship types**:
- "blocked by" - this issue depends on another's completion
- "blocking" - this issue prevents another from completion

**Features**:
- Visual "Blocked" icon on project boards and Issues page
- Helps identify bottlenecks

**CLI Support**: No direct `gh` CLI support. An extension exists ([gh-issue-dependency](https://github.com/torynet/gh-issue-dependency)) but appears unmaintained - not recommended for use. Would need GraphQL API via `gh api graphql` for programmatic access.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies

### Metadata Organization
Issues support categorization through:
- **Issue types** - Categorize by kind of work (Bug, Feature, Task)
- **Labels** - Flexible tagging (we have these: priority, rfc, exploration, etc.)
- **Milestones** - Group issues toward a goal

### Issue Types

Org-level classification for issues. **Best practice**: Use types for Bug/Feature/Task instead of labels.

**Defaults**: Task, Bug, Feature (can customize up to 25 per org)

**CLI Support**: No native `gh issue create --type` yet, but REST API workaround exists:
```bash
# Set type after creation
gh api -X PATCH repos/{owner}/{repo}/issues/1234 --field type=Bug

# Or in search
gh issue list --search "type:Bug"
```

**Management**: Org settings → Planning → Issue types (UI only for creating/editing types)

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-types-in-an-organization
CLI tracking: https://github.com/cli/cli/issues/9696

### Cross-Linking
- Mention issues with `#` to create references
- Use keywords like `fixes #123` in PRs to auto-close issues
- Creates traceable connections across work items

### Linking PRs to Issues

**Auto-close keywords** (in PR body or commit messages):
- `close`, `closes`, `closed`
- `fix`, `fixes`, `fixed`
- `resolve`, `resolves`, `resolved`

Syntax examples:
- Same repo: `Closes #10`
- Cross-repo: `Fixes org/repo#100`
- Multiple: `Resolves #10, resolves #123`
- Case-insensitive, colon optional: `CLOSES: #10`

**Important**: Auto-close only works for PRs targeting the **default branch**.

**CLI usage**:
```bash
gh pr create --title "Fix bug" --body "Fixes #123"
```

**Limits**: Up to 10 issues can be linked per PR.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue

### Projects Integration
Projects use issue metadata for views and filters. Issues are the atoms that Projects organize.

## Creation Methods
- Web UI
- GitHub Desktop
- GitHub CLI (`gh issue create`)
- REST/GraphQL APIs
- GitHub Mobile

### CLI Creation (Agent Workflow)

Agents can create fully-configured issues non-interactively:

```bash
gh issue create --title "Title" --body "Description" \
  --assignee @me,user2 \
  --label "bug,help wanted" \
  --project projectname \
  --milestone "milestone name"
```

Key flags:
- `--title` / `--body` - Core content
- `--body-file file` - Read body from file (`-` for stdin), useful for longer descriptions
- `--assignee` - Comma-separated users (`@me` for self)
- `--label` - Can use `--label "a,b"` or `--label a --label b`
- `--project` - Add to project by title
- `--milestone` - Associate with milestone by name
- `--template` - Use issue template by name
- `-R OWNER/REPO` - Create in different repo
- `--recover` - Recover input from failed run

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue and `gh issue create --help`

### CLI Editing

Modify existing issues with `gh issue edit`:

```bash
gh issue edit 23 --add-assignee "@me" --remove-assignee monalisa
gh issue edit 23 --add-label "bug" --remove-label "wontfix"
gh issue edit 23 --add-project "Roadmap" --remove-project "Old"
gh issue edit 23 --milestone "v1.0"
gh issue edit 23 --title "New title" --body "New body"
gh issue edit 23 34 56 --add-label "help wanted"  # Bulk edit!
```

Key flags:
- `--add-assignee` / `--remove-assignee` - Modify assignees (`@me` supported)
- `--add-label` / `--remove-label` - Modify labels
- `--add-project` / `--remove-project` - Modify project membership
- `--milestone` / `--remove-milestone` - Set or clear milestone
- `--title` / `--body` / `--body-file` - Update content

**Limit**: Max 10 assignees per issue.

Source: `gh issue edit --help`

### CLI Listing and Filtering

List and filter issues with `gh issue list`:

```bash
gh issue list --label "bug" --assignee "@me"
gh issue list --milestone "v1.0" --state all
gh issue list --author monalisa --state closed
gh issue list --search "error no:assignee sort:created-asc"
gh issue list --json number,title,labels,assignees --jq '.[] | select(.labels[].name == "priority:high")'
```

Key flags:
- `--assignee` / `--author` / `--mention` - Filter by user
- `--label` - Filter by label (can repeat)
- `--milestone` - Filter by milestone
- `--state` - open|closed|all (default: open)
- `--search` - Full search query syntax
- `--json fields --jq expr` - JSON output with jq filtering
- `--limit` - Max results (default 30)

JSON fields available: `assignees`, `author`, `body`, `closed`, `closedAt`, `comments`, `createdAt`, `id`, `labels`, `milestone`, `number`, `projectItems`, `state`, `title`, `updatedAt`, `url`

### Search Query Syntax

Full search syntax for `--search` flag:

**Boolean operators:**
- `AND` / `OR` (spaces default to AND)
- Parentheses for grouping (up to 5 levels): `(type:"Bug" AND assignee:me) OR (type:"Feature")`
- `-qualifier` for negation: `-label:wontfix`

**Common qualifiers:**
```
author:username       # Created by
assignee:username     # Assigned to
involves:username     # Mentions someone
label:"label name"    # Has label
type:"Bug"            # Issue type
milestone:"v1.0"      # In milestone
linked:pr             # Linked to a PR
reason:completed      # Close reason (completed | "not planned")
has:label             # Has any label
no:project            # Not in any project
no:assignee           # Unassigned
```

**PR-specific:**
```
is:draft              # Draft PRs
review:none           # No reviews
review:approved       # Approved
review:changes_requested
reviewed-by:username
is:merged / is:unmerged
```

**Sorting:** `sort:created-asc`, `sort:updated-desc`, `sort:comments-desc`

Examples:
```bash
gh issue list --search "label:bug no:assignee sort:created-asc"
gh issue list --search "assignee:@me -label:wontfix"
gh issue list --search "(type:Bug OR type:Feature) AND no:project"
```

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests

### CLI Administration

**Close issue**:
```bash
gh issue close 123 --reason "completed"      # or "not planned"
gh issue close 123 --comment "Closing because..." --reason "not planned"
```

**Delete issue** (requires admin perms):
```bash
gh issue delete 123 --yes
```

**Transfer issue** (same org/owner only, open issues only):
```bash
gh issue transfer 123 owner/other-repo
```
Preserves: comments, assignees, labels (by name), milestones (by name+date). Original URL redirects.

**Mark as duplicate** (no dedicated command - add a comment via CLI):
```bash
gh issue comment 123 --body "Duplicate of #97"
```
Creates timeline event. Can undo via web UI.

**Duplicate/copy issue**: No CLI support - web UI only.
Copies title, body, assignees, type, labels, milestones, projects. Cross-repo supported.

## Task Lists

Markdown task lists can be embedded in issue descriptions:
```markdown
- [ ] First task
- [ ] Second task
```

These can later be converted to full issues. Useful for drafting work breakdown before committing to separate issues.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/learning-about-issues/quickstart

## Collaboration Features
- **@mentions** - Draw attention to specific people
- **Assignments** - Clarify ownership
- **Saved replies** - Efficiency for common responses
- **Notifications** - Subscribers get updates; recent issues appear on dashboard

## Issues vs Discussions

| Issues | Discussions |
|--------|-------------|
| Tasks, bugs, trackable work | Questions, announcements, broader conversations |
| Have state (open/closed) | More free-form |
| Tied to project boards | Community-oriented |

Issues can be converted to Discussions when appropriate.

---

## Open Questions

- How should we use sub-issues vs labels for grouping related work?
- Should high-level objectives be issues (with sub-issues) or something else?
- What issue types would be useful for shimmer?

## Work Breakdown Hierarchy

GitHub supports a clear hierarchy for breaking down work:

```
Issues
  └── Sub-issues (hierarchical parent-child relationships)
        └── Task lists (markdown checkboxes within issue body)
```

- **Issues**: Top-level work items
- **Sub-issues**: Create parent-child relationships between issues for complex work
- **Task lists**: Lightweight decomposition within an issue; show completion count; auto-check when linked issues close

This hierarchy allows representing work at different granularities without over-creating issues.

Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/learning-about-issues/planning-and-tracking-work-for-your-team-or-project

## Labels Strategy

Labels can categorize issues by multiple dimensions:
- **Project goals** - Which objective does this serve?
- **Issue status** - Current state (if not using Projects)
- **Work type** - Bug, feature, enhancement, etc.
- **Severity** - For bugs: critical, major, minor

Labels enable filtering to find related work (e.g., combine "front-end" + "bug").

**Shimmer current labels**: priority:high/medium/low, rfc, exploration, parking-lot, needs-human, etc.

## Issue Templates

Standardize issue creation with templates for common work types:
- Release tracking
- Large initiatives
- Feature requests
- Bug reports

Templates help contributors provide consistent, useful information.

**Agent consideration**: Unlike the web UI which shows a template picker, agents must explicitly know template names and use `--template "Template Name"`. May need wrapper tooling or agent prompts to ensure template usage.

## Topics to Explore Further

- Sub-issues (detailed guide)
- Issue dependencies (detailed guide)
- Issue types configuration
- Issue templates setup
