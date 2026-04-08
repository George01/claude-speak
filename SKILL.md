---
name: speak
description: Toggle Claude voice responses on or off using local TTS
---

Toggle voice output for Claude responses. Check if `~/.claude-speak-enabled` exists to determine current state, then either create or remove it to toggle. Use the Bash tool to do this, then confirm the new state to the user in one short sentence.

- If the file does NOT exist → create it with `touch ~/.claude-speak-enabled` → confirm voice is now ON
- If the file DOES exist → delete it with `rm ~/.claude-speak-enabled` → confirm voice is now OFF
