#!/usr/bin/env nu
# Detect trusted, non-quoted agent mentions in issue comments.

def csv-env [name: string, default: string] {
  $env
  | get -o $name
  | default $default
  | split row ","
  | each {|item| $item | str trim | str downcase }
  | where {|item| $item != "" }
}

def write-output [name: string, value: string] {
  let output_path = ($env | get -o GITHUB_OUTPUT | default "")
  if $output_path == "" {
    print $"($name)=($value)"
    return
  }

  if ($value | str contains "\n") {
    let delimiter = $"EOF_(random uuid | str replace --all '-' '')"
    $"($name)<<($delimiter)\n($value)\n($delimiter)\n" | save --append $output_path
  } else {
    $"($name)=($value)\n" | save --append $output_path
  }
}

def set-no-wake [reason: string, roster: list<string>] {
  write-output should_wake "false"
  write-output reason $reason
  write-output matched_agents "[]"
  for agent in $roster {
    write-output $"agent_($agent | str replace --all '-' '_')" "false"
  }
  write-output message ""
}

def strip-inline-code [line: string] {
  mut stripped = ""
  mut index = 0
  let length = ($line | str length)

  while $index < $length {
    let char = ($line | str substring $index..$index)
    if $char != "`" {
      $stripped = $stripped + $char
      $index = $index + 1
      continue
    }

    mut end = $index + 1
    while $end < $length and (($line | str substring $end..$end) == "`") {
      $end = $end + 1
    }

    let delimiter = ($line | str substring $index..($end - 1))
    let close = ($line | str index-of $delimiter --range $end..)
    if $close == -1 {
      $stripped = $stripped + $delimiter
      $index = $end
    } else {
      $index = $close + ($delimiter | str length)
    }
  }

  $stripped
}

def strip-non-waking-text [body: string] {
  mut lines = []
  mut in_fence = false

  for line in ($body | split row "\n") {
    if ($line | str trim | str starts-with "```") or ($line | str trim | str starts-with "~~~") {
      $in_fence = not $in_fence
      continue
    }
    if $in_fence {
      continue
    }
    if ($line | str trim --left | str starts-with ">") {
      continue
    }
    $lines = ($lines | append (strip-inline-code $line))
  }

  $lines | str join "\n"
}

def mention-records [body: string] {
  $body
  | parse --regex '(^|[^\w/.-])@(?P<mention>[A-Za-z0-9][A-Za-z0-9-]*(/[A-Za-z0-9][A-Za-z0-9-]*)?)'
  | get mention
  | each {|mention| $mention | str downcase }
}

def build-message [event: record, matched_agents: list<string>, matched_mentions: list<string>] {
  let repo = $event.repository.full_name
  let issue = $event.issue
  let comment = $event.comment
  let thread_kind = if ("pull_request" in $issue) { "pull request" } else { "issue" }
  let author = $comment.user.login
  let association = ($comment.author_association? | default "UNKNOWN")
  let body = ($comment.body? | default "")
  let mention_text = ($matched_mentions | each {|mention| $"@($mention)" } | str join ", ")
  let agent_text = ($matched_agents | str join ", ")

  $"GitHub mention wake: ($repo)#($issue.number) \(($thread_kind)\)
Thread: ($issue.html_url? | default "")
Comment: ($comment.html_url? | default "")
Author: @($author) \(($association)\)
Mentions: ($mention_text)
Agents: ($agent_text)

Inspect the thread yourself before responding. Reply on GitHub if useful.

Comment body:
---
($body)
---"
}

let event_path = ($env | get -o GITHUB_EVENT_PATH | default "")
if $event_path == "" {
  print --stderr "GITHUB_EVENT_PATH is required"
  exit 2
}

let event = (open --raw $event_path | from json)
let roster = (csv-env AGENT_ROSTER "")
let aliases = (csv-env TEAM_ALIASES "")
let handle_suffix = ($env | get -o AGENT_HANDLE_SUFFIX | default "-ricon" | str trim | str downcase)
let allowed_associations = (csv-env ALLOWED_ASSOCIATIONS "OWNER,MEMBER" | each {|item| $item | str upcase })

if ($roster | is-empty) {
  set-no-wake "agent roster is empty" []
  exit 0
}

let association = ($event.comment.author_association? | default "UNKNOWN" | str upcase)
if not ($association in $allowed_associations) {
  set-no-wake $"comment author association ($association) is not allowed" $roster
  exit 0
}

let body = ($event.comment.body? | default "")
let stripped_body = (strip-non-waking-text $body)
let mentions = (mention-records $stripped_body)
let agent_mentions = ($roster | each {|agent| {mention: $"($agent)($handle_suffix)", agent: $agent} })

mut matched_agents = []
mut matched_mentions = []
for mention in $mentions {
  let matched_agent = ($agent_mentions | where mention == $mention | get -o 0.agent)
  if $matched_agent != null {
    if not ($matched_agent in $matched_agents) {
      $matched_agents = ($matched_agents | append $matched_agent)
    }
    $matched_mentions = ($matched_mentions | append $mention)
  } else if $mention in $aliases {
    for agent in $roster {
      if not ($agent in $matched_agents) {
        $matched_agents = ($matched_agents | append $agent)
      }
    }
    $matched_mentions = ($matched_mentions | append $mention)
  }
}

let ordered_agents = ($roster | where {|agent| $agent in $matched_agents })
if ($ordered_agents | is-empty) {
  set-no-wake "no agent mention found outside quotes/code" $roster
  exit 0
}

for agent in $roster {
  write-output $"agent_($agent | str replace --all '-' '_')" (if $agent in $matched_agents { "true" } else { "false" })
}

write-output should_wake "true"
write-output reason "matched agent mention"
write-output matched_agents ($ordered_agents | to json --raw)
write-output message (build-message $event $ordered_agents $matched_mentions)
