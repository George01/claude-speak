---
name: wrap
description: Summarize the current session and save key facts to memory before closing
---

The user is ending their work session. Do the following in order:

1. Review the full conversation and identify what's worth remembering:
   - Decisions made (architectural, product, workflow)
   - Problems solved and how
   - Current state of any in-progress work
   - Anything the user explicitly said they want to remember
   - Preferences or feedback the user expressed

2. Write memory files to `/Users/base/.claude/projects/-Users-base-Development-Chat-4-0/memory/` using this format:
   - One file per topic (e.g. `session_2026-04-09.md`, or update an existing relevant memory file)
   - Use the standard frontmatter format:
     ```
     ---
     name: <name>
     description: <one-line description>
     type: <user|feedback|project|reference>
     ---
     <content>
     ```
   - Update `MEMORY.md` index if you create new files

3. Give the user a short spoken-friendly summary of what you saved — 2-3 sentences max.

4. Wish them a good rest of their day.
