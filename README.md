# tellme — Claude Code → phone push via Bark

Walk away from a long-running Claude Code task and get a push notification on your iPhone — plus a native macOS notification on your Mac — the moment it finishes.

**On by default**: after install, every Claude Code session pushes when a turn finishes — nothing to type, nothing added to your context. Mute the sessions you don't care about.

| Command (inside a session) | What it does |
|---|---|
| `/tellme off` (or `/tellme stop`) | Mute **this session only**; other sessions keep pushing. Survives `/clear` |
| `/tellme` | Turn this session back on (every turn pushes) |
| `/tellme once` | Push once when the **next** task finishes, then fall back to the default |
| `/tellme status` | Show global state and how many sessions are on / muted |

The `/tellme` turn itself never pushes.

### Global switch (from a terminal)

```bash
bash ~/.claude/bark/tellme.sh global off   # only sessions that ran /tellme will push
bash ~/.claude/bark/tellme.sh global on    # back to the default: every session pushes
```

Tip: `alias tellme='bash ~/.claude/bark/tellme.sh'` in your shell rc, then `tellme global off`.

## 1. Phone: install Bark

1. Install **Bark** from the App Store (by Fin) and allow notifications.
2. The home screen shows your push URL, e.g. `https://api.day.app/XXXXXXXXXXXXXXXXXXXXXX/`. The middle part is your **key**.
3. Sanity check: open `https://api.day.app/<key>/hello` in Safari — your phone should buzz.

## 2. Computer: one-line install

Requires macOS/Linux with Claude Code, `jq` (`brew install jq`) and `node`.

```bash
git clone https://github.com/zkwasm/claude-tellme.git && bash claude-tellme/install.sh <your-bark-key>
```

You'll get an "Installed ✅" push. **No Claude Code restart needed** — hooks and skills hot-reload, and every session starts pushing right away.

**Upgrading:** `cd claude-tellme && git pull && bash install.sh <your-bark-key>` (safe to re-run; it never duplicates hooks).

**Mac notifications disappear too fast?** System Settings → Notifications → **Script Editor** → set Alert Style to **Persistent**. They'll stay on screen until you dismiss them.

## How it works

A global Claude Code `Stop` hook (`~/.claude/bark/notify.sh`) runs after every turn and calls the Bark HTTP API with `curl` (plus a native macOS notification via `osascript` when available). It pushes unless the current session is muted or global mode is off. `/tellme` only writes a tiny per-session state file (`on`, `once` or `off`) under `~/.claude/bark/state/`; a session with no state follows the global switch. Subagent stops are ignored; `curl` has a 10 s timeout and never blocks Claude.

Files installed:
- `~/.claude/bark/notify.sh` — the Stop hook
- `~/.claude/bark/tellme.sh` — the command behind the skill
- `~/.claude/bark/carry.sh` — SessionEnd/SessionStart hook that carries a session's state across `/clear`
- `~/.claude/skills/tellme/SKILL.md` — the `/tellme` skill
- hook entries in `hooks.Stop`, `hooks.SessionEnd` and `hooks.SessionStart` in `~/.claude/settings.json`

## Uninstall

```bash
rm -rf ~/.claude/bark ~/.claude/skills/tellme
```
then remove the `notify.sh` / `carry.sh` entries from `hooks` in `~/.claude/settings.json`.

## License

MIT
