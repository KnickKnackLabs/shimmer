# GitHub Projects

## Overview

Projects are an adaptable layer on top of issues and pull requests, providing table, board, and roadmap views with custom fields and automation.

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects

## Key Concepts

### Real-time Sync

Projects integrate with issues/PRs bidirectionally - changes in either place sync automatically. A project doesn't copy data; it's a view into your existing work items.

### Views

Three layout types, same underlying data:
- **Table** - High-density spreadsheet view for triage and detailed review
- **Board** - Kanban columns for workflow visualization
- **Roadmap** - Timeline view for planning

Views are a **web UI concept** - the CLI gives raw access to items, and you filter/sort yourself.

### Fields

Up to 50 fields total (built-in + custom). Fields are how Projects add metadata beyond what issues have natively.

#### Custom Field Types

**Text** - Freeform notes
- Filter: `field:"exact text"`

**Number** - Estimates, complexity, story points
- Filter: `>`, `>=`, `<`, `<=`, ranges with `..` (e.g., `estimate:5..15`)

**Date** - Target dates, deadlines
- Format: `YYYY-MM-DD`
- Filter: same operators, plus `@today` for relative dates
- Powers roadmap view timeline

**Single select** - Dropdowns (Priority, Status, Team, etc.)
- **Limit: 50 options per field**
- Each option can have color + description
- Filter: `fieldname:option` or `fieldname:option1,option2`

**Iteration** - Sprint/cycle planning
- Creates 3 iterations by default
- Duration in days or weeks, supports breaks
- Filter shortcuts: `@current`, `@previous`, `@next`
- Also supports operators: `iteration:>"Iteration 4"`

#### Built-in Fields (Hidden by Default)

Enable these in field settings as needed:

**Parent issue** - Shows hierarchy for sub-issues
- Filter: `parent-issue:"owner/repo#123"`
- Supports grouping by parent

**Sub-issue progress** - Completion count (e.g., "3/5 done")

**Linked pull requests** - PRs connected to issues

**Reviewers** - Who's reviewing linked PRs

**Type** - Syncs with org's issue types (Bug/Task/Feature)
- Filter: `type:Bug`

#### Field Management

```bash
# List fields (get IDs for item-edit)
gh project field-list 4 --owner ricon-family
gh project field-list 4 --owner ricon-family --format json

# Create custom field
gh project field-create 4 --owner ricon-family --name "Priority" --data-type SINGLE_SELECT
gh project field-create 4 --owner ricon-family --name "Estimate" --data-type NUMBER
gh project field-create 4 --owner ricon-family --name "Target Date" --data-type DATE
gh project field-create 4 --owner ricon-family --name "Notes" --data-type TEXT

# Delete field (data lost!)
gh project field-delete --id FIELD_ID
```

Renaming fields: web UI only (Settings → click field → rename)

#### Filtering in Views vs CLI

View filters (web UI):
```
priority:High estimate:>=5 iteration:@current
```

CLI filtering (jq on JSON):
```bash
gh project item-list 4 --owner ricon-family --format json \
  --jq '.items[] | select(.fields.Priority == "High")'
```

### Draft Issues

Quick capture directly in project - type a title, press Enter. Drafts live only in the project until converted to real issues. Good for brainstorming before committing to full issues.

### View Recipes

Common patterns from the quickstart:

**Team Backlog (table)**:
- Group by Priority field
- Show field sums for Estimate totals per group
- Dense view for triage

**Sprint Board (board)**:
- Filter: `iteration:@current`
- Columns by Status
- Field sums for capacity planning

**Roadmap (timeline)**:
- Date field on X-axis
- Milestone markers for key dates
- Long-term planning view

### Automation

Built-in workflows:
- Auto-set fields when items are added or change
- Auto-archive items matching criteria
- Auto-add items from repositories based on filters

Automations run server-side regardless of how items are accessed (CLI or web).

## CLI Support

Good CLI support via `gh project`, with some features requiring GraphQL:

### Project Management

```bash
# List projects
gh project list --owner ricon-family

# Filter projects (web UI search syntax)
# is:open, is:closed, is:template, is:private, is:public
# creator:USERNAME, sort:title-asc, sort:updated-desc

# View project details
gh project view 4 --owner ricon-family
gh project view 4 --owner ricon-family --format json
gh project view 4 --owner ricon-family --web  # Open in browser

# Create project
gh project create --owner ricon-family --title "New Project"

# Copy project (cross-org supported, great for templates)
gh project copy 4 --source-owner ricon-family --target-owner ricon-family --title "Clone"
gh project copy 4 --source-owner ricon-family --target-owner other-org --title "Shared" --drafts

# Edit project metadata
gh project edit 4 --owner ricon-family --title "Updated Title"
gh project edit 4 --owner ricon-family --description "Short description"
gh project edit 4 --owner ricon-family --readme "# Project README\n\nMarkdown content here"
gh project edit 4 --owner ricon-family --visibility PUBLIC  # or PRIVATE

# Link/unlink project to repo or team
gh project link 4 --owner ricon-family --repo ricon-family/shimmer
gh project unlink 4 --owner ricon-family --repo ricon-family/shimmer
```

### Item Management

```bash
# List items (with JSON for filtering)
gh project item-list 4 --owner ricon-family --format json
gh project item-list 4 --owner ricon-family --limit 100  # default 30

# Add existing issue/PR to project by URL
gh project item-add 4 --owner ricon-family --url https://github.com/ricon-family/shimmer/issues/123

# Create draft issue (lives only in project until converted)
gh project item-create 4 --owner ricon-family --title "Draft task" --body "Description"
# Note: Converting draft to real issue is web UI only - no CLI support

# Edit item field values (one field per invocation, needs IDs)
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --text "value"
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --number 5
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --date 2024-03-01
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --single-select-option-id OPTION_ID
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --iteration-id ITERATION_ID
gh project item-edit --project-id PROJECT_ID --id ITEM_ID --field-id FIELD_ID --clear  # remove value

# Archive (removes from views, keeps context, restorable)
gh project item-archive 4 --owner ricon-family --id ITEM_ID

# Delete (permanent removal)
gh project item-delete 4 --owner ricon-family --id ITEM_ID
```

**Limits**: 50,000 items per project (active + archived combined).

### GraphQL-Only Features

Some features lack dedicated `gh project` commands but are accessible via GraphQL:

**Status updates** (On track / At risk / Off track):
```bash
# Read status updates
gh api graphql -f query='
query {
  organization(login: "ricon-family") {
    projectV2(number: 4) {
      statusUpdates(first: 5) {
        nodes { body status createdAt }
      }
    }
  }
}'
```

**Workflows** (built-in automations):
```bash
# List workflows and their enabled state
gh api graphql -f query='
query {
  organization(login: "ricon-family") {
    projectV2(number: 4) {
      workflows(first: 10) {
        nodes { name enabled id }
      }
    }
  }
}'
```

Writing status updates and toggling workflows requires GraphQL mutations.

### Views vs CLI

Views (table/board/roadmap with specific filters and groupings) are configured in web UI. CLI accesses raw data:

```bash
# Get all items with custom fields, filter with jq
gh project item-list 4 --owner ricon-family --format json \
  --jq '.items[] | select(.fieldValues.Status == "Ready")'

# Find issues in a project (from issues side)
gh issue list --search "project:shimmer"
```

## Agent Workflows

Projects + automation enable interesting agent patterns:

**Status-driven work assignment**:
- Custom "Agent Status" field: Ready, In Progress, Blocked, Done
- Automation sets "Ready" when prerequisites met
- Agent queries for Ready items, claims by setting In Progress

**Objective grouping**:
- Parent issues represent objectives
- Sub-issues linked to parent
- Project groups by objective for visibility

## Visibility & Access

Sources:
- https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/managing-visibility-of-your-projects
- https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/managing-access-to-your-projects

### Visibility

| Setting | Who can view |
|---------|--------------|
| Public | Everyone on the internet |
| Private | Only users with explicit access |

```bash
gh project edit 4 --owner ricon-family --visibility PUBLIC  # or PRIVATE
```

**Important**: Project visibility ≠ repository access. A public project can contain items from private repos - viewers without repo access see a padlock icon and limited info.

### Permission Levels

| Role | Capabilities |
|------|--------------|
| No access | Can't see project (unless public) |
| Read | View only |
| Write | View and edit items/fields |
| Admin | Full control, manage collaborators |

### Managing Access

**Org projects**: Set base permission for all org members, then override per-user/team.

**Adding collaborators** (web UI): Settings → Manage access → Invite collaborators

**API**: `updateProjectV2Collaborators` mutation for programmatic access management.

### Templates

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/managing-project-templates-in-your-organization

Templates let you standardize project structure across an organization.

**What transfers to new projects**:
- Custom views and configurations
- Custom fields and settings
- Draft issues with field values
- Workflows (except auto-add)
- Insights/charts

**What doesn't transfer**:
- Auto-add workflows
- Actual issues/PRs (only drafts)

**Limits**: 6 recommended templates per org.

**Creating templates**:
- Web UI: Project settings → Templates → "Copy as template"
- API: `markProjectV2AsTemplate` / `unmarkProjectV2AsTemplate` mutations

**Use case**: Create a "standard agent project" template with consistent fields, views, and workflows, then spin up new projects programmatically via `gh project copy` or `copyProjectV2` mutation.

### Linking to Repos and Teams

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/adding-your-project-to-a-repository

**Linking to repository**:
- Project appears in repo's Projects tab
- Can set default repo (new issues from project go there)
- CLI: `gh project link 4 --owner ricon-family --repo ricon-family/shimmer`

**Linking to team**:
- Team gets read access (additive to existing permissions)
- Project appears on team's projects page
- API: `linkProjectV2ToTeam` / `unlinkProjectV2FromTeam` mutations

### Closing and Deleting

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/closing-and-deleting-your-projects

| Action | Effect | Reversible |
|--------|--------|------------|
| Close | Hides from list, preserves all data | Yes - can reopen |
| Delete | Permanently removes project and data | No |

- Close/reopen: Web UI only (Settings → Danger zone)
- Delete: Web UI or `deleteProjectV2` mutation

### Exporting Data

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/exporting-your-projects-data

- **Format**: TSV (tab-separated values)
- **Scope**: Exports current view (with its filters)
- **Access**: Web UI only (view menu → "Export view data")
- **No CLI/API** for export

## Projects vs Other Tools

| Feature | Projects | Labels | Milestones |
|---------|----------|--------|------------|
| Scope | Org or user level, cross-repo | Repo-scoped | Repo-scoped |
| Custom fields | Yes (50 max) | No | No |
| Views | Table, board, roadmap | No | Progress bar only |
| Automation | Yes | No | No |
| Time-boxing | Via iteration field | No | Yes (due date) |

## Best Practices

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects

### Single Source of Truth

Don't duplicate information across fields. Projects auto-sync with issue metadata:
- Assignees, labels, milestones sync automatically
- Don't recreate these as custom fields
- Track things like ship dates in ONE place

### Field Strategy

Only add custom fields for things GitHub doesn't track:
- ✅ Priority (single select) - not built-in
- ✅ Estimate/complexity (number)
- ✅ Iteration (sprint planning)
- ✅ Target date (beyond milestone due date)
- ❌ Don't duplicate assignees, labels, milestones

### Work Breakdown

- Large issues → sub-issues → task lists
- Define dependencies (blocked by/blocking)
- Link related issues and PRs
- Enables parallel work and clearer progress tracking

### Communication

**Project documentation**:
- README explaining project purpose and how to use it
- Description with relevant links and contacts
- View descriptions explaining what each view shows

**Status updates** (source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/sharing-project-updates):
- Built-in feature for project health: "On track", "At risk", "Off track"
- Include start date, target date, and markdown message
- Visible in project header and when browsing project lists
- Requires write access to create, read access to view/subscribe
- Cannot be added to template projects
- API: `createProjectV2StatusUpdate` / `updateProjectV2StatusUpdate` mutations

### View Design

Create views for different purposes:
- **Triage view** (table): All items, grouped by priority, field sums
- **My work view** (table/board): Filtered to assignee `@me`
- **Sprint view** (board): Filter `iteration:@current`
- **Roadmap view** (timeline): For planning and stakeholder updates

Customization options:
- Filter, group, sort, slice (by field values)
- Show/hide columns
- Field sums per group
- Limit board columns

### Automation Strategy

**Built-in workflows**:
- Auto-set Status to "Done" when issues close
- Auto-archive items matching criteria
- Auto-add items from repos matching filters

**GitHub Actions for custom automation**:
- Flag PRs needing review
- Notify on stale items
- Custom field updates based on external events

### Anti-Patterns

- Duplicating info across multiple fields
- Manual status updates that drift out of sync
- Missing issue dependencies/relationships
- No project documentation

## Open Questions

- What custom fields should shimmer's project have?
- What automations would help agent workflows?
- Should we use iterations for time-boxing or just milestones?
