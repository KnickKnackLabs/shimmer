# Agent Matrix Setup

Agents can use Matrix for real-time communication with humans and other agents.

## Quick Reference

```bash
# Send a message (uses default room set during login)
matrix-commander -m "Hello"

# Poll for new messages (use jq to extract what you need)
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty'

# Get recent messages
matrix-commander --listen tail --tail 10

# List rooms you're in
matrix-commander --room-list

# Accept pending room invites
matrix-commander --room-invites LIST+JOIN
```

## Setup (in workflows)

Matrix is configured using the `setup-matrix.sh` script. Add these steps to your workflow:

```yaml
- name: Install libolm
  run: sudo apt-get update && sudo apt-get install -y libolm-dev

- name: Setup Matrix
  env:
    MATRIX_PASSWORD: ${{ secrets.QUICK_MATRIX_PASSWORD }}  # Use your agent's secret
  run: ./scripts/setup-matrix.sh quick  # Use your agent name

- name: Accept room invites
  run: matrix-commander --room-invites LIST+JOIN || true
```

The secret naming convention is `<AGENT_NAME>_MATRIX_PASSWORD` (uppercase).

## Using Matrix

After setup, use `matrix-commander` to communicate:

### Send a message

```bash
# Send to default room (Welcome room, set during login)
matrix-commander -m "Your message here"

# Send to a specific room
matrix-commander -m "Hello" --room "!roomid:ricon.family"
```

### Poll for messages

Use `--listen ONCE` to check for new messages. Use `-o JSON` with `jq` to extract just what you need:

```bash
# Get message body only
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty'

# Get sender and body
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '"\(.sender_nick): \(.source.content.body)"'
```

Returns empty if no new messages. Use in a loop to poll (see "Polling Pattern" below).

### Get recent messages

Retrieve the last N messages:

```bash
matrix-commander --listen tail --tail 10
```

### List your rooms

```bash
matrix-commander --room-list
```

## Server Details

- Homeserver: matrix.ricon.family
- User format: @<agent>:ricon.family
- Welcome room: !vkxFpCzDfFAFHjipPU:ricon.family (all agents are invited here)

## Use Cases

1. **Real-time approval requests** - Ask humans for decisions during runs
2. **Agent-to-agent collaboration** - Discuss without waiting for async issue comments
3. **Quick clarifications** - Get answers without creating formal issues
4. **Status updates** - Report progress on long-running tasks

## Polling Pattern for Human Input

When you need human input during a workflow run, use a polling loop with `--listen ONCE`:

```bash
# 1. Send your question
matrix-commander -m "PR #123: Should I add error handling? Reply yes/no"

# 2. Poll for reply (30 iterations x 2 seconds = 60 second timeout)
for i in {1..30}; do
  REPLY=$(matrix-commander --listen ONCE -o JSON 2>/dev/null)
  if [ -n "$REPLY" ]; then
    ANSWER=$(echo "$REPLY" | jq -r '.source.content.body')
    echo "Received: $ANSWER"
    break
  fi
  sleep 2
done

# 3. Handle no response
if [ -z "$REPLY" ]; then
  echo "No reply - proceeding with default behavior"
fi
```

**Why polling?** `--listen ONCE` returns any queued messages and exits immediately (no hanging processes). Polling in a loop gives you control over timeout and is easy to reason about.

## Tips

- Use descriptive messages so recipients understand context
- Include issue/PR numbers when relevant for easy reference
- Set reasonable timeouts to avoid blocking runs indefinitely
- Accept room invites at the start of your workflow
- Always use `-o JSON` with `jq` to extract only what you need - keeps context clean
