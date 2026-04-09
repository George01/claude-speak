---
name: speak
description: Toggle Claude voice responses on or off using local TTS
---

Toggle voice output for Claude responses. Use the Bash tool to:

1. Kill any currently playing audio: `kill $(cat ~/.claude-speak.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude-speak.pid`
2. Check if `~/.claude-speak-enabled` exists:
   - If it does NOT exist → `touch ~/.claude-speak-enabled` → confirm voice is now **ON**
   - If it DOES exist → `rm ~/.claude-speak-enabled` → confirm voice is now **OFF**

Keep your confirmation to one short sentence.
