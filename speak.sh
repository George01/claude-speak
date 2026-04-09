#!/bin/bash
# claude-speak: macOS TTS via Claude Code Stop hook

SPEECH_FILE="/tmp/claude-speak-text.txt"

# Only run if enabled
if [ ! -f "$HOME/.claude-speak-enabled" ]; then
  exit 0
fi

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path', ''))" 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

python3 - "$TRANSCRIPT" "$SPEECH_FILE" << 'PYEOF'
import sys, json, re

transcript_path = sys.argv[1]
speech_file = sys.argv[2]

with open(transcript_path) as f:
    lines = [l.strip() for l in f if l.strip()]

for line in reversed(lines):
    try:
        entry = json.loads(line)
        if entry.get('type') != 'assistant':
            continue

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
        text = text.replace('"', '').replace('\\', '').replace("'", '')

        # First 2 sentences, max 300 chars
        sentences = re.split(r'(?<=[.!?])\s+', text)
        sentences = [s.strip() for s in sentences if len(s.strip()) > 8]
        result = ' '.join(sentences[:2]) if sentences else text
        result = result[:300]

        with open(speech_file, 'w') as f:
            f.write(result)
        break
    except Exception:
        continue
PYEOF

if [ ! -f "$SPEECH_FILE" ]; then
  exit 0
fi

SPEECH=$(cat "$SPEECH_FILE")
rm -f "$SPEECH_FILE"

if [ -z "$SPEECH" ]; then
  exit 0
fi

killall say 2>/dev/null
osascript -e "say \"$SPEECH\""

exit 0
