# GitHub Project Views

## Overview

Views are saved configurations for visualizing project data. Each view has its own layout, filters, grouping, and sorting settings. Views are a **web UI concept** - the CLI accesses raw project data, and you replicate view behavior with jq filtering.

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/changing-the-layout-of-a-view

## Layouts

Three layout types, same underlying data:

### Table

Spreadsheet view showing issues, PRs, and drafts with all metadata. Best for:
- High-density triage
- Detailed review
- Bulk field editing

**Customization options** (web UI):
- Show/hide fields (columns)
- Reorder columns (drag headers)
- Reorder rows (drag row numbers)
- Group by field values
- Slice by field values (filter panel)
- Sort (primary + secondary)
- Field sums (number field totals per group)

**Grouping/slicing limitations**: Cannot group or slice by title, labels, reviewers, or linked PRs (these are multi-value or text fields).

### Board

Kanban columns based on a single-select or iteration field. Each field option becomes a column. Dragging items between columns auto-updates the field value.

Best for:
- Workflow visualization
- Status tracking
- Sprint boards

**Customization options** (web UI):
- Column field (any single-select or iteration field)
- Column visibility (show/hide specific columns)
- Column limits (soft limit - visual only, doesn't block adds)
- Field display on cards
- Sorting within columns
- Grouping (horizontal swimlanes by another field)
- Slicing (filter panel)
- Field sums per column

**Drag behavior**: Moving items between columns auto-updates the column field value.

### Roadmap

Timeline visualization using date or iteration fields. Items positioned by start date and target date (or iteration). Dragging adjusts dates.

Best for:
- Long-term planning
- Stakeholder updates
- Deadline tracking

**Customization options** (web UI):
- Date fields (start date + target date, or iterations)
- Zoom level (Month, Quarter, Year)
- Vertical markers (iterations, milestones, item dates)
- Grouping (horizontal sections by field)
- Slicing (filter panel)
- Sorting
- Field sums (in group headers)

**Drag behavior**: Moving items horizontally changes their date field values.

**Grouping/slicing limitations**: Same as table - cannot use title, labels, reviewers, or linked PRs.

## Filter Syntax

Filter syntax for web UI views. Understanding this helps construct equivalent CLI jq queries.

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/filtering-projects

### Boolean Logic

- **AND** (default): `label:bug status:"In progress"` - both must match
- **OR** (comma, same field only): `label:bug,support` - either label
- **NOT** (hyphen prefix): `-assignee:octocat` - excludes matches

**Limitation**: OR only works within same field. Can't do `status:Done OR priority:High`.

### Field Qualifiers

```
assignee:USERNAME       label:LABEL           milestone:"NAME"
status:VALUE            priority:VALUE        type:"Bug"
repo:OWNER/REPO         reviewers:USERNAME    parent-issue:OWNER/REPO#123
```

### Special Values

**User**: `@me` - current user
```
assignee:@me
reviewers:@me
```

**Date**: `@today` with arithmetic
```
date:@today
date:>=@today
date:@today..@today+7
updated:>@today-1w
```

**Iteration**: `@current`, `@next`, `@previous`
```
iteration:@current
iteration:@previous..@current
iteration:<@current
```

### Operators

**Comparison**: `>`, `>=`, `<`, `<=`
```
priority:>1
date:>=2024-01-01
points:<=10
```

**Range**: `..` (inclusive)
```
priority:1..3
date:2024-01-01..2024-12-31
points:*..10          # wildcard for "anything up to"
```

### Presence Checks

```
has:assignee          no:assignee
has:label             no:label
has:FIELD             no:FIELD
```

### State and Type

```
is:open    is:closed    is:merged
is:issue   is:pr        is:draft
reason:completed        reason:"not planned"
```

### Text and Wildcards

```
title:"Bug fix"       # exact match (quotes for spaces)
label:*bug*           # contains "bug"
title:API*            # starts with "API"
API                   # searches title and text fields
```

Note: General text search matches word beginnings only, not mid-word.

## CLI Equivalent Operations

Since views are web UI only, here's how to achieve similar results via CLI:

### Table-like listing

```bash
# Get all items with fields
gh project item-list 4 --owner ricon-family --format json
```

### Board-like grouping

```bash
# Group by Status field
gh project item-list 4 --owner ricon-family --format json \
  --jq '.items | group_by(.fields.Status) | .[] | {status: .[0].fields.Status, items: [.[].title]}'
```

### Roadmap-like ordering

```bash
# Sort by date field
gh project item-list 4 --owner ricon-family --format json \
  --jq '.items | sort_by(.fields.TargetDate) | .[] | {title, date: .fields.TargetDate}'
```

## Managing Views

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/managing-your-views

All view management is **web UI only**:

| Operation | How |
|-----------|-----|
| Create | Click "New view" tab |
| Duplicate | View menu → Duplicate view |
| Rename | View menu → Rename view |
| Reorder | Drag view tabs |
| Delete | View menu → Delete view |
| Save changes | View menu → Save changes |

**Note**: Unsaved view changes remain private - you can experiment without affecting other users until you save.

## CLI Support Status

| Operation | CLI Support | Notes |
|-----------|-------------|-------|
| List items (raw data) | `gh project item-list` | Full support |
| Create view | Web UI only | |
| Duplicate view | Web UI only | |
| Rename view | Web UI only | |
| Edit view layout | Web UI only | |
| Set view filters | Web UI only | |
| Set view grouping | Web UI only | |
| Set view sorting | Web UI only | |
| Delete view | Web UI only | |

## GraphQL Access

Views are **read-only** via GraphQL - can query but not create/update/delete.

```bash
gh api graphql -f query='
query {
  organization(login: "ricon-family") {
    projectV2(number: 4) {
      views(first: 10) {
        nodes {
          id
          name
          layout
          filter
          groupByFields(first: 5) { nodes { ... on ProjectV2Field { name } } }
          sortByFields(first: 5) { nodes { field { ... on ProjectV2Field { name } } direction } }
        }
      }
    }
  }
}'
```

Available fields on `ProjectV2View`:
- `id`, `name`, `number`
- `layout` (TABLE_LAYOUT, BOARD_LAYOUT, ROADMAP_LAYOUT)
- `filter` (the filter string)
- `groupByFields`, `sortByFields`, `verticalGroupByFields`
- `fields` (visible fields)
- `createdAt`, `updatedAt`

No mutations exist for views - all configuration is web UI only.

