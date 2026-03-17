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
>
> **Arrow notation (chain of custody):** When someone rewrites or summarizes
> another person's message, use `**[Original → Editor]**`. This means "Original's
> words, as written/clarified by Editor." Chains extend: `**[A → B → C]**` means
> C most recently touched what A originally wrote. If someone disagrees with a
> rewrite, they can overwrite it: `**[A → B → A]**`.
>
> **Closing threads:** When condensing a thread to `[!success]`, summarize each
> participant's contribution using arrow notation, then add your own summary
> last (without an arrow — it's your own words). Example:
>
> ```
> **[Or → x1f9]** Summary of Or's contribution.
> **[junior → x1f9]** Summary of junior's contribution.
> **[x1f9]** Thread summary and outcome.
> ```
>
> The closing agent's entry comes last, so `shimmer human:threads:list`
> naturally shows who closed the thread via the `*` (last sender) marker.
>
> **Coherence rewrites:** When engaging with a thread, feel free to rewrite the human's
> raw messages for clarity — preserving intent, improving scannability. Use arrow notation
> (`**[Or → agent]**`) to mark the rewrite.
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
