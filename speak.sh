#!/bin/bash
# claude-speak: macOS TTS via Claude Code Stop hook
# Toggle with: touch ~/.claude-speak-enabled / rm ~/.claude-speak-enabled

PID_FILE="$HOME/.claude-speak.pid"
CLAUDE_BIN=$(which claude 2>/dev/null || echo "/Users/base/.nvm/versions/node/v22.14.0/bin/claude")

# Kill any currently playing audio
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null
  rm -f "$PID_FILE"
fi

# Only run if enabled
if [ ! -f "$HOME/.claude-speak-enabled" ]; then
  exit 0
fi

INPUT=$(cat)

# Avoid infinite loop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path', ''))" 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

TEXT=$(python3 - "$TRANSCRIPT" << 'PYEOF'
import sys, json, re

with open(sys.argv[1]) as f:
    lines = [l.strip() for l in f if l.strip()]

for line in reversed(lines):
    try:
        entry = json.loads(line)
        if entry.get('type') == 'assistant':
            content = entry.get('message', {}).get('content', [])
            text = ' '.join(b['text'] for b in content if b.get('type') == 'text')
            if not text.strip():
                continue
            text = re.sub(r'```[\s\S]*?```', '', text)
            text = re.sub(r'`[^`]+`', '', text)
            text = re.sub(r'#{1,6}\s+', '', text)
            text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
            text = re.sub(r'\*(.+?)\*', r'\1', text)
            text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
            text = re.sub(r'^\s*[-*+\d.]+\s+', '', text, flags=re.MULTILINE)
            text = re.sub(r'\n+', ' ', text)
            text = re.sub(r'\s+', ' ', text).strip()
            print(text[:500])
            break
    except Exception:
        continue
PYEOF
)

if [ -z "$TEXT" ]; then
  exit 0
fi

# Short responses don't need summarization — speak directly
if [ ${#TEXT} -lt 150 ]; then
  SUMMARY="$TEXT"
else
  # Summarize via Claude Haiku for a natural spoken sentence
  SUMMARY=$(echo "Summarize in one short spoken sentence, no markdown: $TEXT" | "$CLAUDE_BIN" --print --model claude-haiku-4-5-20251001 2>/dev/null)

  # Fall back to first sentence if Haiku fails
  if [ -z "$SUMMARY" ]; then
    SUMMARY=$(echo "$TEXT" | python3 -c "
import sys, re
text = sys.stdin.read()
sentences = re.split(r'(?<=[.!?])\s+', text)
sentences = [s for s in sentences if len(s) > 10]
print(sentences[0][:300] if sentences else text[:300])
")
  fi
fi

# Speak using system default voice (set in System Settings → Accessibility → Spoken Content)
say -r 195 "$SUMMARY" &
echo $! > "$PID_FILE"

exit 0
