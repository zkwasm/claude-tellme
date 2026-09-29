# tellme — Claude Code → phone push via Bark

Walk away from a long-running Claude Code task and get a push notification on your iPhone — plus a native macOS notification on your Mac — the moment it finishes.

| Command | What it does |
|---|---|
| `/tellme` | Push after every turn in this session until you stop it (same as `/tellme always`) |
| `/tellme once` | Push once when the **next** task you send finishes, then auto-disable |
| `/tellme stop` | Disable everything (one-shot and always-on) |
| `/tellme status` | Show current state |

The `/tellme` turn itself never pushes — **send `/tellme` first, then send the task**.

## 1. Phone: install Bark

1. Install **Bark** from the App Store (by Fin) and allow notifications.
2. The home screen shows your push URL, e.g. `https://api.day.app/XXXXXXXXXXXXXXXXXXXXXX/`. The middle part is your **key**.
3. Sanity check: open `https://api.day.app/<key>/hello` in Safari — your phone should buzz.

## 2. Computer: one-line install

Requires macOS/Linux with Claude Code, `jq` (`brew install jq`) and `node`.

```bash
git clone https://github.com/zkwasm/claude-tellme.git && bash claude-tellme/install.sh <your-bark-key>
```

You'll get an "Installed ✅" push. **No Claude Code restart needed** — hooks and skills hot-reload. Type `/tellme` in any session.

## How it works

`/tellme` just writes a tiny state file. A global Claude Code `Stop` hook (`~/.claude/bark/notify.sh`) runs after every turn, checks the state for the current session, and calls the Bark HTTP API with `curl` (and shows a native macOS notification via `osascript` when available). In `once` mode the state deletes itself after the first push. State is per-session; subagent stops are ignored; `curl` has a 10 s timeout and never blocks Claude.

Files installed:
- `~/.claude/bark/notify.sh` — the Stop hook
- `~/.claude/bark/tellme.sh` — the command behind the skill
- `~/.claude/bark/carry.sh` — SessionEnd/SessionStart hook that keeps `/tellme` armed across `/clear`
- `~/.claude/skills/tellme/SKILL.md` — the `/tellme` skill
- hook entries in `hooks.Stop`, `hooks.SessionEnd` and `hooks.SessionStart` in `~/.claude/settings.json`

## Uninstall

```bash
rm -rf ~/.claude/bark ~/.claude/skills/tellme
```
then remove the `notify.sh` / `carry.sh` entries from `hooks` in `~/.claude/settings.json`.

## License

MIT
