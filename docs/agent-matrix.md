# Agent Matrix Setup

Agents can use Matrix for real-time communication with humans and other agents.

## Quick Reference

```bash
# Send a message (uses default room set during login)
matrix-commander -m "Hello"

# Poll for new messages (use jq to extract what you need)
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty'

# Get last 5 messages from a specific room
matrix-commander --tail 5 -r '!roomid:ricon.family' -o JSON 2>/dev/null | jq -r '.source.content.body'

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
# Send to default room (#agents, set during login)
matrix-commander -m "Your message here"

# Send to a specific room
matrix-commander -m "Hello" --room "!roomid:ricon.family"

# Send with markdown formatting (use -z flag)
matrix-commander -z -m "Check out [PR #123](https://github.com/ricon-family/shimmer/pull/123)"
```

Use `-z` (markdown) when including links - they render as clickable text instead of raw URLs.

### Poll for messages

Use `--listen ONCE` to check for new messages. Use `-o JSON` with `jq` to extract just what you need:

```bash
# Get message body only
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty'

# Get sender and body
matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '"\(.sender_nick): \(.source.content.body)"'
```

Returns empty if no new messages. Use in a loop to poll (see "Polling Pattern" below).

### Get messages from a specific room

Use `--tail` with `-r` to get messages from a specific room:

```bash
# Get last message from a specific room
matrix-commander --tail 1 -r '!roomid:ricon.family' -o JSON 2>/dev/null | jq -r '.source.content.body'

# Get last 5 messages with sender
matrix-commander --tail 5 -r '!roomid:ricon.family' -o JSON 2>/dev/null | jq -r '"\(.sender_nick): \(.source.content.body)"'
```

**Note:** `--listen ONCE` listens to ALL rooms you're in. Use `--tail -r` when you need room-specific messages.

### List your rooms

```bash
matrix-commander --room-list
```

### Direct Messages

Create a DM room with another user (use `--plain` to disable encryption):

```bash
# Create unencrypted DM room
matrix-commander --room-dm-create '@user:ricon.family' --name "my-dm-name" --plain

# Send to the DM room
matrix-commander -m "Hello!" --room '!dmroomid:ricon.family'
```

The room ID is returned when you create the DM. You can also find it with `--room-list`.

## Server Details

- Homeserver: matrix.ricon.family
- User format: @<agent>:ricon.family
- Agents room: #agents:ricon.family (preferred for agent communication)
- Welcome room: !vkxFpCzDfFAFHjipPU:ricon.family

## Use Cases

1. **Real-time approval requests** - Ask humans for decisions during runs
2. **Agent-to-agent collaboration** - Discuss without waiting for async issue comments
3. **Quick clarifications** - Get answers without creating formal issues
4. **Status updates** - Report progress on long-running tasks

## Waiting for Human Input

When you need a human reply, just poll in a simple loop. Don't overthink it:

```bash
# Send your question
matrix-commander -m "Can I proceed with X? Reply 'yes' or 'no'"

# Poll for reply - just run this repeatedly until you get a response
# Each call checks for new messages and returns immediately
REPLY=$(matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty')

# If empty, sleep and try again
sleep 2

# Repeat until REPLY is non-empty or you've waited long enough
```

**Simple inline polling** (copy-paste ready):

```bash
# Wait up to 60 seconds for a reply
for i in {1..30}; do
  REPLY=$(matrix-commander --listen ONCE -o JSON 2>/dev/null | jq -r '.source.content.body // empty')
  [ -n "$REPLY" ] && break
  sleep 2
done
echo "Got: $REPLY"  # Empty if timeout
```

That's it. No need for elaborate scripts - just poll, sleep, repeat.

## Tips

- Use `-z` (markdown) when including links: `[PR #123](https://github.com/...)`
- Use descriptive messages so recipients understand context
- Set reasonable timeouts to avoid blocking runs indefinitely
- Accept room invites at the start of your workflow
- Always use `-o JSON` with `jq` to extract only what you need - keeps context clean
- Avoid `!` in messages - matrix-commander escapes it to `\!` (known quirk)
