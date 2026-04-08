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

## Install

```bash
git clone https://github.com/George01/claude-speak
cd claude-speak
./install.sh
```

Restart Claude Code if it's already running, then type `/speak` to toggle voice on or off.

## Usage

| Command | Effect |
|---------|--------|
| `/speak` | Toggle voice on or off |

Voice is **enabled by default** after install.

## Getting the best voice

For the most natural-sounding output, use a **Siri voice**:

1. Open **System Settings → Accessibility → Spoken Content**
2. Click the **System Voice** dropdown
3. Select a **Siri** voice (Voice 2 is a good choice)

Siri voices are free, run entirely on your Mac, and sound significantly more human than the default voices. The script automatically uses whatever you set as your system voice — no code changes needed.

To preview all voices available on your machine:

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
