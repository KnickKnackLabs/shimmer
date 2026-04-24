#!/usr/bin/env bash
# Shared check functions for shimmer welcome
#
# Sourced by the welcome task and by tests.
# Expects: AGENT, MISE_PROJECT_ROOT (when _task is used)

# Helper for consistent formatting
# Usage: print_status "Label" "✓|✗" "status text" ["hint"]
print_status() {
  local label="$1"
  local check="$2"
  local status="$3"
  local hint="${4:-}"

  if [ -n "$hint" ]; then
    printf "  %-10s %s %-30s %s\n" "$label" "$check" "$status" "→ $hint"
  else
    printf "  %-10s %s %s\n" "$label" "$check" "$status"
  fi
}

# Call a sibling shimmer task
# Usage: _task email:quota
#        _task --timeout 5 email:quota
_task() {
  local timeout_val=""
  if [ "$1" = "--timeout" ]; then
    timeout_val="$2"
    shift 2
  fi
  if [ -n "$timeout_val" ]; then
    timeout "$timeout_val" mise -C "$MISE_PROJECT_ROOT" run -q "$@"
  else
    mise -C "$MISE_PROJECT_ROOT" run -q "$@"
  fi
}

# Check email configuration and status
# Expects: AGENT
check_email() {
  local config="${HIMALAYA_CONFIG:-$HOME/.config/himalaya/config.toml}"
  if ! [ -f "$config" ] || ! grep -q "accounts.$AGENT" "$config" 2>/dev/null; then
    print_status "Email" "✗" "not configured" "emails setup $AGENT"
    return
  fi

  local quota_output rc=0
  quota_output=$(timeout 5 emails quota 2>/dev/null) || rc=$?
  if [ "$rc" -eq 124 ]; then
    print_status "Email" "✗" "timed out after 5s" "emails welcome"
    return
  elif [ "$rc" -ne 0 ]; then
    print_status "Email" "✗" "check failed" "emails welcome"
    return
  fi

  local quota_percent unread_count status_text
  quota_percent=$(echo "$quota_output" | grep -oE '[0-9]+%' | tr -d '%')
  # Fallback is safe: if the server were unreachable, quota would have timed out
  # above and we'd have already returned. We only reach here when the server responded.
  unread_count=$(timeout 5 emails list --unread --count 2>/dev/null || echo "0")

  if [ -n "$unread_count" ] && [ "$unread_count" -gt 0 ]; then
    status_text="${unread_count} unread"
  else
    status_text="0 unread"
  fi
  [ -n "$quota_percent" ] && status_text="${status_text} (quota ${quota_percent}%)"

  if [ -n "$quota_percent" ] && [ "$quota_percent" -ge 95 ]; then
    print_status "Email" "✗" "$status_text" "emails purge"
  elif [ -n "$quota_percent" ] && [ "$quota_percent" -ge 80 ]; then
    print_status "Email" "⚠" "$status_text" "emails welcome"
  else
    print_status "Email" "✓" "$status_text" "emails welcome"
  fi
}
