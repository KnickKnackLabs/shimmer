#!/usr/bin/env bats

# Tests for the shared Python parser (lib/human_threads.py).
# Covers edge cases in thread parsing that the task-level tests don't reach:
# arrow chain authorship, blank-line lookahead, multi-paragraph content.

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# Helper: run Python parser directly against HUMAN_PATH
# Returns threads with both authors (effective editors) and senders (original authors)
run_parser() {
  PYTHONPATH="$SHIMMER_DIR/lib" python3 -c "
import os, sys, json
from human_threads import (
    split_header_body, parse_threads, extract_thread_body,
    extract_authors, extract_message_senders, thread_title, thread_waiting_on,
    parse_author_chain,
)
content = open('$HUMAN_PATH').read()
header, body = split_header_body(content)
_, threads = parse_threads(body)
result = []
for kind, lines in threads:
    title = thread_title(lines[0])
    body_lines = extract_thread_body(lines)
    authors = extract_authors(body_lines)
    senders = extract_message_senders(body_lines)
    result.append({
        'kind': kind,
        'title': title,
        'authors': authors,
        'senders': senders,
        'waiting': thread_waiting_on(kind, senders),
        'body_line_count': len(body_lines),
    })
print(json.dumps(result))
"
}

# ============ Arrow chain authorship ============

@test "parser: arrow chain — authors returns editor, senders returns original" {
  write_threads "$THREAD_ARROW_CHAIN"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# authors: effective editors (last in chain)
assert threads[0]['authors'] == ['x1f9', 'junior'], f'authors: got {threads[0][\"authors\"]}'
# senders: original authors (first in chain)
assert threads[0]['senders'] == ['Or', 'junior'], f'senders: got {threads[0][\"senders\"]}'
"
}

@test "parser: arrow chain — waiting on Or when agent spoke last" {
  write_threads "$THREAD_ARROW_CHAIN"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# junior (agent) is the last sender, so waiting on Or
assert threads[0]['waiting'] == 'Or', f'got {threads[0][\"waiting\"]}'
"
}

@test "parser: multi-hop arrow chain" {
  write_threads "$THREAD_MULTI_ARROW"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# authors: brownie is the effective editor (last in Or → x1f9 → brownie)
assert threads[0]['authors'] == ['brownie'], f'authors: got {threads[0][\"authors\"]}'
# senders: Or is the original sender (first in chain)
assert threads[0]['senders'] == ['Or'], f'senders: got {threads[0][\"senders\"]}'
"
}

@test "parser: rewritten message — sender is original author, not editor" {
  write_threads "$THREAD_OR_REWRITTEN_BY_AGENT"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# Message 1: [Or → Zeke] — Or sent it, Zeke edited
# Message 2: [Zeke] — Zeke sent it
assert threads[0]['authors'] == ['Zeke', 'Zeke'], f'authors: got {threads[0][\"authors\"]}'
assert threads[0]['senders'] == ['Or', 'Zeke'], f'senders: got {threads[0][\"senders\"]}'
# Zeke (agent) spoke last → waiting on Or
assert threads[0]['waiting'] == 'Or', f'waiting: got {threads[0][\"waiting\"]}'
"
}

@test "parser: Or's rewritten message as last — waiting on agent" {
  write_threads "$THREAD_OR_REWRITTEN_LAST"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# Message 1: [Zeke] — Zeke sent it
# Message 2: [Or → Zeke] — Or sent it, Zeke edited
assert threads[0]['senders'] == ['Zeke', 'Or'], f'senders: got {threads[0][\"senders\"]}'
# Or sent the last message → waiting on agent
assert threads[0]['waiting'] == 'agent', f'waiting: got {threads[0][\"waiting\"]}'
"
}

@test "parser: parse_author_chain splits correctly" {
  PYTHONPATH="$SHIMMER_DIR/lib" python3 -c "
from human_threads import parse_author_chain
assert parse_author_chain('Or') == ['Or']
assert parse_author_chain('Or \u2192 x1f9') == ['Or', 'x1f9']
assert parse_author_chain('Or \u2192 x1f9 \u2192 brownie') == ['Or', 'x1f9', 'brownie']
"
}

# ============ Blank-line lookahead / multi-paragraph ============

@test "parser: multi-paragraph content stays in one thread" {
  write_threads "$THREAD_MULTI_PARAGRAPH"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
assert len(threads) == 1, f'expected 1 thread, got {len(threads)}'
assert threads[0]['title'] == 'Long discussion (Mar 15)'
"
}

@test "parser: multi-paragraph preserves all body lines" {
  write_threads "$THREAD_MULTI_PARAGRAPH"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
# Should have both authors' paragraphs
assert threads[0]['authors'] == ['Or', 'junior']
# Body should include the inner blank lines and continuation text
assert threads[0]['body_line_count'] >= 8, f'got {threads[0][\"body_line_count\"]} lines'
"
}

@test "parser: adjacent threads separated by blank line" {
  write_threads "$THREAD_ADJACENT_A" "$THREAD_ADJACENT_B"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
assert len(threads) == 2, f'expected 2 threads, got {len(threads)}'
assert threads[0]['title'] == 'Thread A'
assert threads[1]['title'] == 'Thread B'
"
}

@test "parser: multi-paragraph followed by another thread" {
  write_threads "$THREAD_MULTI_PARAGRAPH" "$THREAD_NOTE"
  output=$(run_parser)
  echo "$output" | python3 -c "
import sys, json
threads = json.loads(sys.stdin.read())
assert len(threads) == 2, f'expected 2 threads, got {len(threads)}'
assert threads[0]['title'] == 'Long discussion (Mar 15)'
assert threads[1]['title'] == 'Test thread (Mar 15)'
"
}

# ============ Status with arrow chains ============

@test "status: arrow chain author counted correctly" {
  write_threads "$THREAD_ARROW_CHAIN"
  run run_task status
  [ "$status" -eq 0 ]
  # junior (agent) spoke last, so waiting on Or
  echo "$output" | grep -q "1 waiting on Or"
}

# ============ Sort with multi-paragraph ============

@test "sort: preserves multi-paragraph content" {
  write_threads "$THREAD_MULTI_PARAGRAPH" "$THREAD_WARNING"
  run_task sort
  # Warning should be first
  grep -q "Urgent thing" "$HUMAN_PATH"
  # Multi-paragraph content should be intact
  grep -q "Second paragraph continues here" "$HUMAN_PATH"
  grep -q "Third paragraph with more detail" "$HUMAN_PATH"
}

# ============ Archive with arrow chains ============

@test "archive: arrow chain thread archived correctly" {
  local arrow_success='> [!success]- Resolved arrow thread
> **[Or → junior]** Resolved summary.'
  write_threads "$THREAD_NOTE" "$arrow_success"
  run run_task archive
  echo "$output" | grep -q "Archived 1"
  grep -q "Resolved arrow thread" "$ARCHIVE_PATH"
}
