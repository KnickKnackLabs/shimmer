#!/usr/bin/env bats

setup() {
  load helpers
  OS_AGENT=$(id -un)
  setup_test_home "$OS_AGENT"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/dedicated.gitconfig"
  git config --global user.name "$OS_AGENT"
  git config --global user.email "$OS_AGENT@ricon.family"
  git config --global user.signingkey DEDICATED-KEY
  mock_secrets_binary "$OS_AGENT/github-pat=ghp_fixture"
  mock_shimmer
}

@test "as: dedicated OS user uses its matching global signer without private layout" {
  rm -rf "$TEST_AGENTS_ROOT/$OS_AGENT"
  export GIT_CONFIG_COUNT=3
  export GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=other-agent
  export GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1=other-agent@ricon.family
  export GIT_CONFIG_KEY_2=user.signingkey GIT_CONFIG_VALUE_2=STALE-KEY

  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"

  [ "$(git -C "$TEST_HOME" config user.name)" = "$OS_AGENT" ]
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = DEDICATED-KEY ]
  [ "$(git -C "$TEST_HOME" config commit.gpgsign)" = true ]
  [ "$(git -C "$TEST_HOME" config tag.gpgsign)" = true ]
  [ "$GIT_CONFIG_COUNT" = 8 ]
}

@test "as: agent private signing config takes precedence over dedicated global config" {
  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "TESTKEY-$OS_AGENT" ]
}

@test "as: dedicated fallback rejects a different configured name" {
  rm -rf "$TEST_AGENTS_ROOT/$OS_AGENT"
  git config --global user.name other-agent

  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "" ]
  [ "$(git -C "$TEST_HOME" config commit.gpgsign)" = false ]
}

@test "as: dedicated fallback rejects a different configured email despite transient overrides" {
  rm -rf "$TEST_AGENTS_ROOT/$OS_AGENT"
  git config --global user.email other-agent@ricon.family
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=user.email GIT_CONFIG_VALUE_0="$OS_AGENT@ricon.family"

  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "" ]
  [ "$(git -C "$TEST_HOME" config commit.gpgsign)" = false ]
}

@test "as: shared OS account cannot use global signer for another agent even with forged USER" {
  local other="${OS_AGENT}-other"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$other" > "$TEST_HOME/.mise/tasks/agent/list"
  git config --global user.name "$other"
  git config --global user.email "$other@ricon.family"
  mock_secrets_binary "$other/github-pat=ghp_fixture"
  export USER="$other" LOGNAME="$other" GIT_AUTHOR_NAME="$other"

  eval "$(shimmer as "$other" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "" ]
  [ "$(git -C "$TEST_HOME" config commit.gpgsign)" = false ]
}

@test "as: missing dedicated global signer disables signing" {
  rm -rf "$TEST_AGENTS_ROOT/$OS_AGENT"
  git config --global --unset user.signingkey

  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "" ]
  [ "$(git -C "$TEST_HOME" config tag.gpgsign)" = false ]
}

@test "as: dedicated fallback does not follow a global include to another signer" {
  rm -rf "$TEST_AGENTS_ROOT/$OS_AGENT"
  git config --global --unset user.signingkey
  git config --file "$BATS_TEST_TMPDIR/included.gitconfig" user.signingkey INCLUDED-KEY
  git config --global include.path "$BATS_TEST_TMPDIR/included.gitconfig"

  eval "$(shimmer as "$OS_AGENT" 2>/dev/null)"
  [ "$(git -C "$TEST_HOME" config user.signingkey)" = "" ]
  [ "$(git -C "$TEST_HOME" config commit.gpgsign)" = false ]
}
