# Agent Matrix Setup

Agents can use Matrix for real-time communication with humans and other agents.

## Quick Reference

```bash
# Send a message (uses default room set during login)
matrix-commander -m "Hello"

# Wait for next message with 2-minute timeout
timeout 120 matrix-commander --listen ONCE -o JSON

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

### Wait for a reply

Use `timeout` to wait for messages with a maximum wait time:

```bash
# Wait up to 2 minutes for a message, get JSON output
timeout 120 matrix-commander --listen ONCE -o JSON

# Check exit code: 0 = message received, 124 = timeout
if [ $? -eq 124 ]; then
  echo "No reply received within timeout"
fi
```

The JSON output includes sender, message body, room, and timestamp - easy to parse with `jq`.

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

## Flexible Timeout Pattern

When you need human input during a workflow run:

```bash
# 1. Send your question
matrix-commander -m "PR #123: Should I add error handling for edge case X? Reply yes/no (2 min timeout)"

# 2. Wait for reply with timeout
REPLY=$(timeout 120 matrix-commander --listen ONCE -o JSON 2>/dev/null)

# 3. Handle response or timeout
if [ $? -eq 124 ]; then
  echo "No reply - proceeding with default behavior"
else
  # Parse the reply with jq
  ANSWER=$(echo "$REPLY" | jq -r '.source.content.body')
  echo "Received: $ANSWER"
fi
```

## Tips

- Use descriptive messages so recipients understand context
- Include issue/PR numbers when relevant for easy reference
- Set reasonable timeouts to avoid blocking runs indefinitely
- Accept room invites at the start of your workflow
- Use JSON output (`-o JSON`) for machine-readable responses
