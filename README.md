# claude-speak

A Claude Code skill that reads Claude's responses aloud using macOS built-in text-to-speech. Fully local, no API keys, no data leaves your machine.

## How it works

Claude Code has a `Stop` hook that fires every time Claude finishes a response. This project wires that hook to a shell script that:

1. Reads the last assistant message from Claude's session transcript
2. Strips markdown formatting
3. Passes the clean text to macOS `say`

A `/speak` skill lets you toggle voice on or off from inside any Claude Code session.

## Requirements

- macOS
- [Claude Code](https://claude.ai/code) CLI installed
- `gh` CLI (only needed for installation from GitHub)

## Install

```bash
git clone https://github.com/George01/claude-speak
cd claude-speak
./install.sh
```

That's it. Restart Claude Code if it's already running, then type `/speak` to toggle voice on or off.

## Usage

| Command | Effect |
|---------|--------|
| `/speak` | Toggle voice on or off |

Voice is **enabled by default** after install.

## Changing the voice

The script uses your macOS system voice. To change it:

**System Settings → Accessibility → Spoken Content → System Voice**

To preview available voices from Terminal:

```bash
say -v '?'
```

## Uninstall

1. Remove the `hooks` block from `~/.claude/settings.json`
2. Delete `~/.claude/skills/speak.md`
3. Delete `~/.claude-speak-enabled` if it exists
4. Delete this folder

## Privacy

All processing is local. Your conversation text is never sent anywhere — `say` runs entirely on your machine.

## License

MIT
