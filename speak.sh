#!/bin/bash
# claude-speak: macOS TTS via Claude Code Stop hook

SPEECH_FILE="/tmp/claude-speak-text.txt"
LAST_UUID_FILE="$HOME/.claude-speak-last-uuid"

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

LAST_UUID=$(cat "$LAST_UUID_FILE" 2>/dev/null || echo "")

python3 - "$TRANSCRIPT" "$LAST_UUID" "$SPEECH_FILE" << 'PYEOF'
import sys, json, re

transcript_path = sys.argv[1]
last_uuid = sys.argv[2] if len(sys.argv) > 2 else ""
speech_file = sys.argv[3]

with open(transcript_path) as f:
    lines = [l.strip() for l in f if l.strip()]

entries = []
for line in lines:
    try:
        entries.append(json.loads(line))
    except:
        continue

# Walk backwards to find last assistant text message
for entry in reversed(entries):
    if entry.get('type') != 'assistant':
        continue

    uuid = entry.get('uuid', '')

    # Already spoke this — stop
    if uuid and uuid == last_uuid:
        break

    content = entry.get('message', {}).get('content', [])
    text = ' '.join(b['text'] for b in content if b.get('type') == 'text')
    if not text.strip():
        continue  # No text, keep looking

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

    sentences = re.split(r'(?<=[.!?])\s+', text)
    sentences = [s.strip() for s in sentences if len(s.strip()) > 8]
    result = ' '.join(sentences[:2]) if sentences else text
    result = result[:300]

    with open(speech_file, 'w') as f:
        f.write(uuid + '\n' + result)
    break
PYEOF

if [ ! -f "$SPEECH_FILE" ]; then
  exit 0
fi

UUID=$(head -1 "$SPEECH_FILE")
SPEECH=$(tail -n +2 "$SPEECH_FILE")
rm -f "$SPEECH_FILE"

if [ -z "$SPEECH" ]; then
  exit 0
fi

echo "$UUID" > "$LAST_UUID_FILE"
killall say 2>/dev/null
osascript -e "say \"$SPEECH\""

exit 0
