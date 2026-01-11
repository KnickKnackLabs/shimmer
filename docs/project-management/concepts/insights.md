# GitHub Projects Insights

## Overview

Insights provides charts and visualizations for project data. Useful for tracking progress, identifying bottlenecks, and stakeholder reporting.

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/viewing-insights-from-your-project/about-insights-for-projects

**CLI Support**: None - web UI only.

## Chart Types

### Current Charts

Real-time snapshots of project state:
- Items by assignee
- Items by iteration
- Items by status
- Items by any custom field

### Historical Charts

Track changes over time (X-axis = Time):
- **Burn-up** - Work completed vs remaining over time
- Open items (open issues + PRs)
- Completed items (closed issues + merged PRs)
- Closed PRs
- Not planned items

## Creating Charts

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/viewing-insights-from-your-project/creating-charts

1. Click insights icon (graph) in project top-right
2. Click "New chart" in left menu
3. Rename by clicking dropdown → type name → Enter
4. Add filters above chart
5. Click "Save changes"

## Configuring Charts

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/viewing-insights-from-your-project/configuring-charts

Click "Configure" to open settings panel:

| Setting | Options |
|---------|---------|
| Layout | Chart type (bar, column, line, stacked area, etc.) |
| X-axis | Any field, or "Time" for historical |
| Y-axis | Number field aggregation: sum, average, min, max |
| Group by | Secondary grouping (current charts only) |
| Filters | Same syntax as view filters |

### Common Configurations

**Burn-up chart**: X-axis = Time, shows completion over time

**Items by assignee**: X-axis = Assignee, Y-axis = Count

**Story points by status**: X-axis = Status, Y-axis = Sum of Estimate field

**Velocity by iteration**: X-axis = Iteration, Y-axis = Sum of completed points

## Limitations

- **Archived/deleted items not tracked** - only active items appear in insights
- **No programmatic access** - web UI only, no CLI, REST API, or GraphQL support for insights/charts

## Sharing

Charts are visible to anyone with project view access. No per-chart permissions.

