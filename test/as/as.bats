#!/usr/bin/env bats
load helpers

@test "activation emits the chosen identity and exactly six signed Git settings, without selecting a home" {
  activate
  [ "$(< "$STDERR")" = '' ]
  source "$STDOUT"
  [ "$GIT_AUTHOR_NAME" = Alice ]
  [ "$GIT_COMMITTER_EMAIL" = alice@example.test ]
  [ "$GH_TOKEN" = synthetic-token ]
  [ "$GH_HOST" = github.com ]
  [ "$GIT_CONFIG_COUNT" = 6 ]
  [ "$GIT_CONFIG_KEY_2" = user.signingkey ]
  [ "$GIT_CONFIG_VALUE_3" = openpgp ]
  [ "$GIT_CONFIG_VALUE_4" = true ]
  [ "$GIT_CONFIG_VALUE_5" = true ]
  [ "$AGENT_HOME" = /caller/selected/home ]
  [[ "$(< "$STDOUT")" != *AGENT_HOME* ]]
  [[ "$SHIMMER_PERSONA_STATE" != *synthetic-token* ]]
  printf '%s' "$SHIMMER_PERSONA_STATE" | jq -e '.variables.GH_TOKEN | test("^[a-f0-9]{64}$")'
}

@test "complete switching removes omitted optional credentials and does not grow the Git list" {
  apply_activation
  bundle Bob
  apply_activation
  [ "$GIT_AUTHOR_NAME" = Bob ]
  [ "${GH_TOKEN+x}" != x ]
  [ "$GIT_CONFIG_COUNT" = 6 ]
  [ "$GIT_CONFIG_VALUE_0" = Bob ]
}

@test "invalid configuration emits nothing and leaves the existing persona unchanged" {
  apply_activation
  printf '{}' > "$MOCK_BUNDLE_FILE"

  ! activate

  [ ! -s "$STDOUT" ]
  [ "$GH_TOKEN" = synthetic-token ]
}

@test "missing signer emits nothing and leaves the existing persona unchanged" {
  apply_activation
  bundle Bob replacement-secret
  key BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
  ! activate
  [ ! -s "$STDOUT" ]
  [ "$GIT_AUTHOR_NAME" = Alice ]
  [[ "$(< "$STDERR")" != *replacement-secret* ]]
}

@test "edited and unmanaged variables require value-free state-bound consent" {
  apply_activation
  export GH_TOKEN=operator-secret
  bundle Bob replacement-secret
  # No controlling terminal in the BATS subprocess.
  ! activate </dev/null
  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'GH_TOKEN: replace'* ]]
  [[ "$(< "$STDERR")" != *operator-secret* ]]
  [[ "$(< "$STDERR")" != *replacement-secret* ]]

  local digest
  digest=$(approval)
  [ "${#digest}" -eq 64 ]

  activate "$digest"
  source "$STDOUT"

  [ "$GH_TOKEN" = replacement-secret ]
  [ "$GIT_AUTHOR_NAME" = Bob ]
}

@test "approval becomes invalid when the inspected caller state changes" {
  export GH_TOKEN=operator-secret
  ! activate
  local digest
  digest=$(approval)
  export GH_TOKEN=changed-secret
  ! activate "$digest"
  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'does not match'* ]]
}

@test "approval also becomes invalid when the requested persona changes" {
  export GH_TOKEN=operator-secret
  ! activate
  local digest
  digest=$(approval)
  bundle Bob replacement-secret
  ! activate "$digest"
  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'does not match'* ]]
}

@test "same-value unmanaged assignments need no consent and unrelated selectors remain untouched" {
  export GH_TOKEN=synthetic-token
  export EMAILS_CONFIG=/caller/mail HIMALAYA_CONFIG=/caller/himalaya

  apply_activation

  [ "$EMAILS_CONFIG" = /caller/mail ]
  [ "$HIMALAYA_CONFIG" = /caller/himalaya ]
}

@test "previously owned renamed variables are removed but edited removals require consent" {
  apply_activation
  export EMAILS_CONFIG=/old/config
  local hash
  hash=$(printf '%s' "$EMAILS_CONFIG" | persona_digest)
  SHIMMER_PERSONA_STATE=$(
    printf '%s' "$SHIMMER_PERSONA_STATE" |
      jq -c --arg hash "$hash" '.variables.EMAILS_CONFIG = $hash'
  )
  export SHIMMER_PERSONA_STATE
  apply_activation
  [ "${EMAILS_CONFIG+x}" != x ]

  export EMAILS_CONFIG=/changed/config
  SHIMMER_PERSONA_STATE=$(
    printf '%s' "$SHIMMER_PERSONA_STATE" |
      jq -c --arg hash "$hash" '.variables.EMAILS_CONFIG = $hash'
  )

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'EMAILS_CONFIG: remove'* ]]
}

@test "shared Git settings survive compaction and owned entries can move without losing ownership" {
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.editor GIT_CONFIG_VALUE_0=zed
  apply_activation
  [ "$GIT_CONFIG_COUNT" = 7 ]
  # Move the unrelated entry from the beginning to the end.
  local i next
  for i in 0 1 2 3 4 5; do
    next=$((i + 1))
    eval "export GIT_CONFIG_KEY_$i=\"\$GIT_CONFIG_KEY_$next\""
    eval "export GIT_CONFIG_VALUE_$i=\"\$GIT_CONFIG_VALUE_$next\""
  done
  export GIT_CONFIG_KEY_6=core.editor GIT_CONFIG_VALUE_6=zed
  bundle Bob
  apply_activation
  [ "$GIT_CONFIG_COUNT" = 7 ]
  [ "$GIT_CONFIG_KEY_0" = core.editor ]
  [ "$GIT_CONFIG_VALUE_0" = zed ]
  [ "$GIT_CONFIG_VALUE_1" = Bob ]
}

@test "edited owned Git entry requires consent before replacement" {
  apply_activation
  export GIT_CONFIG_VALUE_0=operator-name

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'replace edited owned entry'* ]]

  activate "$(approval)"
  source "$STDOUT"
  [ "$GIT_CONFIG_VALUE_0" = Alice ]
}

@test "competing identity setting requires consent even when persona settings would shadow it" {
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=user.email GIT_CONFIG_VALUE_0=operator@example.test

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'retain competing Git setting'* ]]
}

@test "a disappeared owned Git entry cannot claim a previously unrelated competing entry" {
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=operator-name
  ! activate
  activate "$(approval)"
  source "$STDOUT"
  # Remove owned slot 1, leaving the previously unrelated user.name intact.
  local i next
  for i in 1 2 3 4 5; do
    next=$((i + 1))
    eval "export GIT_CONFIG_KEY_$i=\"\$GIT_CONFIG_KEY_$next\""
    eval "export GIT_CONFIG_VALUE_$i=\"\$GIT_CONFIG_VALUE_$next\""
  done
  unset GIT_CONFIG_KEY_6 GIT_CONFIG_VALUE_6
  export GIT_CONFIG_COUNT=6
  ! activate
  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'ownership is ambiguous'* ]]
}

@test "duplicate matching Git entries make ownership ambiguous" {
  apply_activation
  export GIT_CONFIG_KEY_6=user.name GIT_CONFIG_VALUE_6=Alice GIT_CONFIG_COUNT=7

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'ownership is ambiguous'* ]]
}

@test "alternate Git parameters must be resolved before activation" {
  export GIT_CONFIG_PARAMETERS="'user.name=other'"

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'GIT_CONFIG_PARAMETERS must be resolved'* ]]
}

@test "Git slots outside the declared list fail closed" {
  export GIT_CONFIG_VALUE_9=orphan

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'orphaned Git config variables'* ]]
}

@test "ownership metadata cannot claim the caller's home selector" {
  export SHIMMER_PERSONA_STATE='{
    "version": 1,
    "variables": {
      "AGENT_HOME": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    "git": []
  }'

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'invalid ownership manifest'* ]]
}

@test "all email and blob accounts map independently and shell quoting preserves credential bytes" {
  configure_accounts
  apply_activation
  [ "$EMAIL_DEFAULT_ACCOUNT" = shared ]
  [ "$EMAIL_PERSONAL_IMAP_PASSWORD" = $'quoted \' $(false)\n\n' ]
  [ "$EMAIL_SHARED_SMTP_USERNAME" = shared ]
  [ "$BLOBS_PERSONAL_BUCKET" = personal ]
  [ "$BLOBS_SHARED_APPLICATION_KEY" = synthetic-key ]
  [ "${B2_BUCKET+x}" != x ]
}

@test "switching away from configured integrations removes all owned account credentials only" {
  configure_accounts
  export EMAIL_UNMANAGED=caller-value
  apply_activation
  bundle Bob
  apply_activation
  [ "${EMAIL_PERSONAL_IMAP_PASSWORD+x}" != x ]
  [ "${EMAIL_SHARED_SMTP_PASSWORD+x}" != x ]
  [ "${BLOBS_SHARED_APPLICATION_KEY+x}" != x ]
  [ "${EMAIL_ACCOUNTS+x}" != x ]
  [ "${BLOBS_DEFAULT_ACCOUNT+x}" != x ]
  [ "$EMAIL_UNMANAGED" = caller-value ]
}

@test "working credentials stay private even when caller exports collide with helper local names" {
  export bundle=ambient data=ambient object=ambient value=ambient
  export old=ambient current=ambient wanted=ambient current_values=ambient
  export desired=ambient plan=ambient approval_digest=ambient
  export PERSONA_DATA=ambient PERSONA_DESIRED=ambient PERSONA_PLAN=ambient
  export MOCK_LEAKS="$BATS_TEST_TMPDIR/leaks"

  # Inspect the actual child environment, not Bash dynamic local visibility.
  # shellcheck disable=SC2329
  jq() {
    if command jq -en '
      env | any(to_entries[];
        (.key | startswith("BASH_FUNC_") | not)
        and (.value | contains("synthetic-token"))
      )
    ' >/dev/null; then
      printf 'credential inherited\n' >> "$MOCK_LEAKS"
    fi
    command jq "$@"
  }
  export -f jq
  activate
  [ ! -s "$MOCK_LEAKS" ]
}

@test "public Mise task emits activation without caller home tasks or legacy secrets" {
  shimmer as alice > "$STDOUT" 2> "$STDERR"
  source "$STDOUT"
  [ "$GIT_AUTHOR_NAME" = Alice ]
  [ "$AGENT_HOME" = /caller/selected/home ]
  [ "$(grep -c '^export --provider sops --prefix alice/$' "$MOCK_CALLS")" -eq 1 ]
  [ "$(wc -l < "$MOCK_CALLS" | tr -d ' ')" -eq 2 ]
}

@test "public approval flag accepts only the reviewed conflict state" {
  export GH_TOKEN=operator-secret
  ! without_terminal bash -c 'shimmer as alice' > "$STDOUT" 2> "$STDERR"
  [ ! -s "$STDOUT" ]
  local digest
  digest=$(approval)
  [ "${#digest}" -eq 64 ]
  without_terminal bash -c 'shimmer as alice --approve "$1"' _ "$digest" \
    > "$STDOUT" 2> "$STDERR"
  source "$STDOUT"
  [ "$GH_TOKEN" = synthetic-token ]
}

@test "whoami tolerates an activated persona without an optional GitHub token" {
  bundle Alice
  apply_activation
  gh() {
    printf 'Logged in as synthetic-account\n'
  }
  export -f gh
  shimmer whoami > "$STDOUT" 2> "$STDERR"
  grep -F 'Alice <alice@example.test>' "$STDOUT"
  grep -F 'GH_TOKEN not set' "$STDOUT"
}

@test "public provider failure emits zero commands" {
  export MOCK_SECRETS_STATUS=1

  ! shimmer as alice > "$STDOUT" 2> "$STDERR"

  [ ! -s "$STDOUT" ]
}

@test "macOS compatibility Bash executes the same activation" {
  /bin/bash -c '
    source "$1/lib/persona/activate.sh"
    persona_activate alice
  ' _ "$REPO_DIR" > "$STDOUT" 2> "$STDERR"

  source "$STDOUT"

  [ "$GIT_CONFIG_COUNT" = 6 ]
}
