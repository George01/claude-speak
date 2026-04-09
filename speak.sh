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
import sys, json, re
from datetime import datetime, timezone

with open(sys.argv[1]) as f:
    lines = [l.strip() for l in f if l.strip()]

import time
now = time.time()

for line in reversed(lines):
    try:
        entry = json.loads(line)
        if entry.get('type') != 'assistant':
            continue

        # Only speak recent messages
        ts_str = entry.get('timestamp', '')
        try:
            ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00')).timestamp()
        except:
            ts = 0
        if ts and (now - ts) > 5:
            break

        content = entry.get('message', {}).get('content', [])
        text = ' '.join(b['text'] for b in content if b.get('type') == 'text')
        if not text.strip():
            continue

        # Strip markdown and code
        text = re.sub(r'```[\s\S]*?```', '', text)
        text = re.sub(r'`[^`]+`', '', text)
        text = re.sub(r'#{1,6}\s+', '', text)
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
        text = re.sub(r'\*(.+?)\*', r'\1', text)
        text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
        text = re.sub(r'^\s*[-*+\d.]+\s+', '', text, flags=re.MULTILINE)
        text = re.sub(r'\n+', ' ', text)
        text = re.sub(r'\s+', ' ', text).strip()

        # Split into sentences
        sentences = re.split(r'(?<=[.!?])\s+', text)
        sentences = [s.strip() for s in sentences if len(s.strip()) > 8]

        if not sentences:
            print(text[:300])
            break

        # Score each sentence — higher = more important
        def score(s):
            s_lower = s.lower()
            pts = 0
            # Prefer direct answers and actions
            if s_lower.startswith(('done', 'yes', 'no', 'sure', 'okay', 'fixed', 'updated', 'added', 'removed', 'created', 'installed')):
                pts += 4
            # Prefer sentences with concrete outcomes
            if any(w in s_lower for w in ['now', 'will', 'can', 'ready', 'works', 'done', 'fixed', 'updated', 'pushed', 'committed']):
                pts += 2
            # Prefer shorter sentences (more direct)
            if len(s) < 80:
                pts += 2
            elif len(s) < 150:
                pts += 1
            # Penalize sentences that are questions
            if s.endswith('?'):
                pts -= 2
            # Slight bonus for first sentence (usually the lede)
            return pts

        scored = [(score(s), i, s) for i, s in enumerate(sentences)]
        scored.sort(key=lambda x: (-x[0], x[1]))  # highest score, then earliest

        best = scored[0][2]
        print(best[:300])
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
