#!/bin/bash
# claude-speak installer
# Adds voice output to Claude Code using macOS built-in TTS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEAK_SCRIPT="$SCRIPT_DIR/speak.sh"
SETTINGS="$HOME/.claude/settings.json"
SKILL_DIR="$HOME/.claude/skills"

# Ensure speak.sh is executable
chmod +x "$SPEAK_SCRIPT"

# Install skill
mkdir -p "$SKILL_DIR"
mkdir -p "$SKILL_DIR/speak"
 cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/speak/SKILL.md"
 mkdir -p "$SKILL_DIR/wrap"
 cp "$SCRIPT_DIR/skills/wrap/SKILL.md" "$SKILL_DIR/wrap/SKILL.md"
echo "✓ Skill installed → /speak to toggle voice on/off"

# Add Stop hook to ~/.claude/settings.json
python3 - "$SPEAK_SCRIPT" "$SETTINGS" << 'PYEOF'
import sys, json, os

speak_script = sys.argv[1]
settings_path = sys.argv[2]

# Load existing settings or start fresh
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    settings = {}

# Add Stop hook (avoid duplicates)
settings.setdefault('hooks', {}).setdefault('Stop', [])
hook_entry = {
    "type": "command",
    "command": speak_script,
    "timeout": 30,
    "async": True
}
matcher_block = {"matcher": "", "hooks": [hook_entry]}

# Check if already installed
already = any(
    any(h.get('command') == speak_script for h in block.get('hooks', []))
    for block in settings['hooks']['Stop']
)

if not already:
    settings['hooks']['Stop'].append(matcher_block)

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF

echo "✓ Stop hook registered in $SETTINGS"

# Enable voice by default
touch "$HOME/.claude-speak-enabled"
echo "✓ Voice enabled (use /speak in Claude Code to toggle)"

echo ""
echo "claude-speak installed. Restart Claude Code if it's already running."
