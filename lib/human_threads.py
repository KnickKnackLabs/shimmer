"""Shared parser for HUMAN.md thread management.

Parses Obsidian-style callout threads ([!note], [!warning], [!success])
from HUMAN.md files. Used by shimmer human:threads:* tasks.

Note: [!info] callouts are intentionally excluded — they're used for
the instruction block in the HUMAN.md header, not for conversation threads.
"""

import re

HEADER_MARKER = "--- HEADER END ---"

CALLOUT_OPENER = re.compile(r"^> \[!(note|warning|success)\][+-]?\s*")
NAME_PAT = re.compile(r"^(?:\*\*)?\[([A-Za-z][A-Za-z -]*?)\](?:\*\*)?")


def split_header_body(content):
    """Split content at the header marker.

    Returns (header, body) where header includes the marker line.
    If no marker found, returns (None, content).
    """
    idx = content.find(HEADER_MARKER)
    if idx < 0:
        return None, content
    end = idx + len(HEADER_MARKER)
    return content[:end], content[end:]


def parse_threads(body):
    """Parse callout threads from the body of a HUMAN.md file.

    Uses a line-by-line walker with blank-line lookahead to correctly
    handle threads separated by blank lines.

    Returns (preamble_lines, threads) where threads is a list of
    (kind, lines) tuples. kind is 'note', 'warning', or 'success'.
    """
    lines = body.split("\n")
    preamble_lines = []
    threads = []
    current_kind = None
    current_lines = []

    i = 0
    while i < len(lines):
        line = lines[i]
        m = CALLOUT_OPENER.match(line)

        if m:
            # Save previous thread if any
            if current_kind is not None:
                while current_lines and current_lines[-1].strip() == "":
                    current_lines.pop()
                threads.append((current_kind, list(current_lines)))

            current_kind = m.group(1)
            current_lines = [line]
            i += 1

        elif current_kind is not None:
            stripped = line.rstrip()
            if stripped.startswith("> ") or stripped == ">":
                current_lines.append(line)
                i += 1
            elif stripped == "":
                # Peek ahead: if next non-blank is a callout continuation
                # ("> " but NOT a new opener), include the blank.
                j = i + 1
                while j < len(lines) and lines[j].strip() == "":
                    j += 1
                if j < len(lines):
                    next_line = lines[j]
                    next_is_continuation = (
                        (next_line.startswith("> ") or next_line.rstrip() == ">")
                        and not CALLOUT_OPENER.match(next_line)
                    )
                    if next_is_continuation:
                        current_lines.append(line)
                        i += 1
                    else:
                        i += 1
                        while current_lines and current_lines[-1].strip() == "":
                            current_lines.pop()
                        threads.append((current_kind, list(current_lines)))
                        current_kind = None
                        current_lines = []
                else:
                    i += 1
            else:
                while current_lines and current_lines[-1].strip() == "":
                    current_lines.pop()
                threads.append((current_kind, list(current_lines)))
                current_kind = None
                current_lines = []
        else:
            preamble_lines.append(line)
            i += 1

    # Flush last thread
    if current_kind is not None:
        while current_lines and current_lines[-1].strip() == "":
            current_lines.pop()
        threads.append((current_kind, list(current_lines)))

    return preamble_lines, threads


def extract_thread_body(thread_lines):
    """Extract the body lines from a thread's raw lines.

    Strips the callout prefix ("> ") from each line.
    Skips the opener line (first line).
    """
    body_lines = []
    for line in thread_lines[1:]:
        stripped = line.rstrip()
        if stripped.startswith("> "):
            body_lines.append(stripped[2:])
        elif stripped == ">":
            body_lines.append("")
    return body_lines


def extract_authors(body_lines):
    """Extract [Name] or **[Name]** markers from body lines, in order."""
    authors = []
    for line in body_lines:
        m = NAME_PAT.match(line)
        if m:
            authors.append(m.group(1))
    return authors


def thread_title(opener_line):
    """Extract and clean the title from a callout opener line."""
    m = CALLOUT_OPENER.match(opener_line)
    if not m:
        return ""
    title = opener_line[m.end():].strip()
    # Strip pointing hand emoji
    title = re.sub("\U0001f448\\s*", "", title).strip()
    return title


def thread_waiting_on(kind, authors):
    """Determine who the thread is waiting on.

    Returns 'resolved', 'agent', 'Or', or '\u2014'.
    # TODO: "Or" is hardcoded as the human name. Generalize when
    # multiple humans or configurable names are needed.
    """
    if kind == "success":
        return "resolved"
    if not authors:
        return "\u2014"
    if authors[-1] == "Or":
        return "agent"
    return "Or"
