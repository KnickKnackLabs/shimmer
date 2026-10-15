#!/usr/bin/env bash
# Persona activation orchestration. Secret-bearing working JSON stays unexported.
PERSONA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PERSONA_LIB_DIR/../persona.sh"

persona_error() {
  printf 'ERROR: %s\n' "$1" >&2
}

persona_digest() {
  local +x digest
  digest=$(shasum -a 256) || {
    persona_error 'SHA-256 hashing is unavailable.'
    return 1
  }
  digest=${digest%% *}
  if [[ ! "$digest" =~ ^[a-f0-9]{64}$ ]]; then
    persona_error 'SHA-256 hashing returned an invalid digest.'
    return 1
  fi
  printf '%s\n' "$digest"
}

# jq cannot hash. Hash stdin values without exposing them in process arguments.
# The sentinel preserves trailing newlines when capturing a JSON string in Bash.
persona_hash_values() {
  local +x object="$1" name value hash names result='{}'
  names=$(printf '%s' "$object" | jq -r 'keys[]') || return 1

  while IFS= read -r name; do
    [ -n "$name" ] || continue

    value=$(
      printf '%s' "$object" |
        jq -jr --arg name "$name" '.[$name], "."'
    ) || return 1
    value=${value%.}
    hash=$(printf '%s' "$value" | persona_digest) || return 1

    result=$(
      printf '%s' "$result" |
        jq -c --arg name "$name" --arg hash "$hash" '. + {($name): $hash}'
    ) || return 1
  done <<< "$names"

  printf '%s' "$result"
}

persona_check_signers() {
  local +x desired="$1" listing available fingerprint fingerprints
  # GnuPG only lists metadata here: no signing, importing, unlock, or network.
  listing=$(
    gpg --batch --no-tty \
      --with-colons --with-fingerprint --with-subkey-fingerprint \
      --list-secret-keys 2>/dev/null
  ) || {
    persona_error 'could not inspect secret signing keys.'
    return 1
  }
  available=$(printf '%s\n' "$listing" | awk -F: -v now="$(date +%s)" '
    function usable(validity, expiry, capabilities) {
      return validity !~ /[redi]/ && capabilities !~ /D/ &&
        (expiry == "" || expiry == "0" || expiry > now)
    }

    $1 == "sec" || $1 == "ssb" {
      key_ok = usable($2, $7, $12)
      if ($1 == "sec") primary_ok = key_ok
      else key_ok = primary_ok && key_ok

      # Lowercase s belongs to this key; uppercase S may describe a subkey.
      # Field 15 is # when the secret key is unavailable.
      signing = key_ok && $12 ~ /s/ && $15 != "#"
      next
    }
    $1 == "fpr" {
      if (signing) print toupper($10)
      signing = 0
    }
  ') || return 1

  fingerprints=$(printf '%s' "$desired" | jq -r '.signers[]') || return 1
  while IFS= read -r fingerprint; do
    if ! printf '%s\n' "$available" | grep -Fx "$fingerprint" >/dev/null; then
      persona_error 'a configured signer lacks a valid signing-capable secret key.'
      return 1
    fi
  done <<< "$fingerprints"
}

persona_build_plan() {
  local +x desired="$1" plan
  local +x old current wanted current_values wanted_hashes current_hashes reason
  old=${SHIMMER_PERSONA_STATE:-'{"version":1,"variables":{},"git":[]}'}

  if ! printf '%s' "$old" | jq -e 'type == "object"' >/dev/null 2>&1; then
    persona_error 'invalid ownership manifest.'
    return 1
  fi
  current=$(jq -cn 'env') || return 1
  wanted=$(printf '%s' "$desired" | jq -c '
    .variables + (
      reduce .git[] as $entry ({};
        . + {("git:" + $entry.key): $entry.value}
      )
    )
  ') || return 1
  wanted_hashes=$(persona_hash_values "$wanted") || return 1

  # Hash only inspected state. Unrelated environment changes do not invalidate
  # consent; presence and contents of every relevant variable do.
  current_values=$(printf '%s\n' "$desired" "$old" "$current" | jq -cs '
    .[0].variables as $desired
    | .[1].variables as $owned
    | .[2]
    | with_entries(
        select(
          .key as $name
          | ($desired | has($name))
            or ($owned | has($name))
            or ($name | test("^GIT_CONFIG_(COUNT|PARAMETERS|KEY_[0-9]+|VALUE_[0-9]+)$"))
        )
      )
  ' 2>/dev/null) || {
    persona_error 'invalid ownership manifest.'
    return 1
  }
  current_hashes=$(persona_hash_values "$current_values") || return 1

  if ! plan=$(
    printf '%s\n' "$desired" "$old" "$current" "$wanted_hashes" "$current_hashes" |
      jq -cse -f "$PERSONA_LIB_DIR/switch.jq" 2>/dev/null
  ); then
    persona_error 'cannot safely reconcile ownership or the shared Git config list; inspect their names and structure.'
    return 1
  fi
  reason=$(printf '%s' "$plan" | jq -r '.error // empty') || return 1
  if [ -n "$reason" ]; then
    persona_error "$reason"
    return 1
  fi
  printf '%s' "$plan"
}

persona_approve() {
  local +x plan="$1" approval_digest="$2" supplied="${3:-}" response
  if [ -n "$supplied" ] && [ "$supplied" != "$approval_digest" ]; then
    persona_error 'approval does not match the current persona and inspected state.'
    return 1
  fi
  if [ "$(printf '%s' "$plan" | jq '.conflicts | length')" -eq 0 ]; then
    return 0
  fi

  printf 'Persona switch requires approval (names and actions only):\n' >&2
  printf '%s' "$plan" | jq -r '.conflicts[] | "  \(.name): \(.action)"' >&2
  if [ "$supplied" = "$approval_digest" ]; then
    return 0
  fi
  if { exec 3<>/dev/tty; } 2>/dev/null; then
    printf 'Apply this complete switch? [y/N] ' >&3
    IFS= read -r response <&3 || response=''
    exec 3>&-
    case "$response" in y|Y|yes|YES) return 0 ;; esac
    persona_error 'persona switch declined; no commands emitted.'
  else
    printf 'Retry with the same handle and --approve %s after reviewing this plan.\n' "$approval_digest" >&2
    persona_error 'confirmation required; no commands emitted.'
  fi
  return 1
}

persona_emit() {
  local +x plan="$1"
  # Everything above must succeed before even the first shell command appears.
  printf '%s' "$plan" | jq -r '
    (.unset[] | "unset " + . + ";"),
    (.set | to_entries[] | "export " + .key + "=" + (.value | @sh) + ";"),
    ("export SHIMMER_PERSONA_STATE=" + (.state | tojson | @sh) + ";")
  '
}

persona_activate() {
  set +x
  set +v
  # +x prevents locals from inheriting a caller variable's export attribute.
  local +x handle="${1:-}" approval="${2:-}"
  local +x PERSONA_DATA desired plan approval_digest

  case "$handle" in
    ''|*[!a-zA-Z0-9_-]*)
      persona_error 'specify one persona handle (letters, digits, underscore, hyphen).'
      return 1
      ;;
  esac

  persona_load "$handle" || return 1
  if ! desired=$(
    printf '%s' "$PERSONA_DATA" |
      jq -ce -f "$PERSONA_LIB_DIR/config.jq" 2>/dev/null
  ); then
    persona_error 'incomplete or invalid persona configuration.'
    return 1
  fi

  persona_check_signers "$desired" || return 1
  plan=$(persona_build_plan "$desired") || return 1
  approval_digest=$(printf '%s' "$plan" | jq -cS '.binding' | persona_digest) || return 1

  persona_approve "$plan" "$approval_digest" "$approval" || return 1
  persona_emit "$plan"
}
