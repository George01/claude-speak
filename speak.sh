#!/bin/bash
# claude-speak: macOS TTS via Claude Code Stop hook

PID_FILE="$HOME/.claude-speak.pid"
LAST_UUID_FILE="$HOME/.claude-speak-last-uuid"

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

LAST_UUID=$(cat "$LAST_UUID_FILE" 2>/dev/null || echo "")

RESULT=$(python3 - "$TRANSCRIPT" "$LAST_UUID" << 'PYEOF'
import sys, json, re

transcript_path = sys.argv[1]
last_uuid = sys.argv[2] if len(sys.argv) > 2 else ""

with open(transcript_path) as f:
    lines = [l.strip() for l in f if l.strip()]

for line in reversed(lines):
    try:
        entry = json.loads(line)
        if entry.get('type') != 'assistant':
            continue

        uuid = entry.get('uuid', '')
        if uuid and uuid == last_uuid:
            break

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
        sentences = [s.strip() for s in sentences if len(s.strip()) > 8]

        if not sentences:
            print(uuid + '|||' + text[:300])
            break

        def score(s):
            s_lower = s.lower()
            pts = 0
            if s_lower.startswith(('done', 'yes', 'no', 'sure', 'okay', 'fixed', 'updated', 'added', 'removed', 'created', 'installed')):
                pts += 4
            if any(w in s_lower for w in ['now', 'will', 'can', 'ready', 'works', 'done', 'fixed', 'updated', 'pushed', 'committed']):
                pts += 2
            if len(s) < 80:
                pts += 2
            elif len(s) < 150:
                pts += 1
            if s.endswith('?'):
                pts -= 2
            return pts

        scored = sorted([(score(s), i, s) for i, s in enumerate(sentences)], key=lambda x: (-x[0], x[1]))
        print(uuid + '|||' + scored[0][2][:300])
        break
    except Exception:
        continue
PYEOF
)

if [ -z "$RESULT" ]; then
  exit 0
fi

UUID=$(echo "$RESULT" | cut -d'|' -f1)
SPEECH=$(echo "$RESULT" | sed 's/^[^|]*|||//')

if [ -z "$SPEECH" ]; then
  exit 0
fi

echo "$UUID" > "$LAST_UUID_FILE"

# Use osascript — runs in user session with guaranteed audio access
osascript -e "say \"$(echo "$SPEECH" | sed 's/"/\\"/g')\"" &
disown
echo $! > "$PID_FILE"

exit 0
