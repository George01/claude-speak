#!/bin/bash
# claude-speak: macOS TTS via Claude Code Stop hook

PID_FILE="$HOME/.claude-speak.pid"

# Kill any currently playing audio
killall say 2>/dev/null
rm -f "$PID_FILE"

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
import sys, json, re, time, os

with open(sys.argv[1]) as f:
    lines = [l.strip() for l in f if l.strip()]

now = time.time()

for line in reversed(lines):
    try:
        entry = json.loads(line)
        if entry.get('type') == 'assistant':
            # Only speak messages written in the last 10 seconds
            ts_str = entry.get("timestamp", "")
            try:
                from datetime import datetime, timezone
                ts = datetime.fromisoformat(ts_str.replace("Z","+00:00")).timestamp()
            except:
                ts = 0
            if ts and (now - ts) > 10:
                break  # Too old, stop looking

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

            sentences = re.split(r'(?<=[.!?])\s+', text)
            sentences = [s for s in sentences if len(s) > 8]
            result = ' '.join(sentences[:2]) if sentences else text
            print(result[:350])
            break
    except Exception:
        continue
PYEOF
)

if [ -z "$TEXT" ]; then
  exit 0
fi

nohup say -r 195 "$TEXT" > /dev/null 2>&1 &
disown
echo $! > "$PID_FILE"

exit 0
