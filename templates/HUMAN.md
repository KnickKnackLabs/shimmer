<!--
     .
    /|\
   / | \
  |  o  |
   \   /
    | |       Laurel
   /| |\
  / | | \
    | |
   _| |_
  |_____|
-->
# HUMAN

Async scratchpad for human-agent conversations.

> [!info]- How this works
> 1. Human writes raw thoughts anywhere in this file (no format needed)
> 2. Agents restructure into sections, ask follow-up questions
> 3. Human replies inline — discussion goes until human signals "agree" or "resolved"
> 4. Agents condense resolved discussions to bullets, distill into issues, mark resolved
>
> **Conversation format:** Conversations use Obsidian collapsible callouts.
> Human can start threads with a simple code block — agents convert to callouts when they reply.
>
> - `[!note]-` — regular thread (collapsed by default)
> - `[!warning]- 👈` — thread that needs human's attention (yellow accent, stands out)
> - `[!success]-` — resolved thread (green, collapsed)
>
> Each message starts with `**[Name]**` (bold) — separated by `> ---` dividers for visual clarity.
> When condensing a resolved thread, sign the summary: `**[Name]** Summary text here.`
>
> **Keep conversations concise.** If a response needs detailed analysis, tables, or proposals,
> write it up in a separate file and link to it from the conversation thread.
> This keeps HUMAN.md scannable and saves tokens.
>
> **Thread management tasks:**
> - `shimmer human:threads:list` — list threads with "Waiting on" column
> - `shimmer human:threads:status` — one-line summary
> - `shimmer human:threads:sort` — reorder: warning → note → success
> - `shimmer human:threads:tidy` — convert raw codeblocks to callout threads
> - `shimmer human:threads:archive` — move resolved threads to HUMAN.archive.md

*Raw thoughts welcome anywhere — agents will restructure on next pass.*

--- HEADER END ---
