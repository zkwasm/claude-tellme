#!/bin/bash
# Usage: bash install.sh <your-bark-key>
KEY="$1"
[ -n "$KEY" ] || { echo "Usage: bash install.sh <your-bark-key>"; exit 1; }
command -v jq >/dev/null || { echo "jq is required: brew install jq"; exit 1; }
command -v node >/dev/null || { echo "node is required"; exit 1; }
set -e
mkdir -p ~/.claude/bark/state ~/.claude/skills/tellme
rm -f ~/.claude/bark/global

cat > ~/.claude/bark/notify.sh <<EOF
#!/bin/bash
# Claude Code Stop hook: push a Bark notification when a task finishes.
INPUT=\$(cat)
command -v jq >/dev/null || exit 0
SID=\$(echo "\$INPUT" | jq -r '.session_id // empty')
AGENT=\$(echo "\$INPUT" | jq -r '.agent_id // empty')
[ -n "\$SID" ] && [ -z "\$AGENT" ] || exit 0          # ignore subagent stops
DIR="\$HOME/.claude/bark/state"; STATE="\$DIR/\$SID"; PENDING="\$DIR/pending"
# The /tellme turn itself: bind pending -> this session, don't notify yet
if [ -f "\$PENDING" ]; then mv -f "\$PENDING" "\$STATE"; exit 0; fi
GLOBAL_OFF="\$HOME/.claude/bark/global-off"   # created by: tellme.sh global off
if [ -f "\$STATE" ]; then MODE=\$(cat "\$STATE"); elif [ ! -f "\$GLOBAL_OFF" ]; then MODE=global; else exit 0; fi
# Muted session: refresh mtime so the 7-day cleanup never un-mutes a long-running session
[ "\$MODE" = off ] && { touch "\$STATE"; exit 0; }
CWD=\$(echo "\$INPUT" | jq -r '.cwd // empty'); PROJECT=\$(basename "\${CWD:-\$PWD}")
MSG=\$(echo "\$INPUT" | jq -r '.last_assistant_message // empty' | tr '\n' ' ' | cut -c1-200)
[ -n "\$MSG" ] || MSG="Task finished"
curl -s -m 10 -G "https://api.day.app/$KEY/" \\
  --data-urlencode "title=Claude Code · \$PROJECT" \\
  --data-urlencode "body=\$MSG" \\
  --data-urlencode "group=claude" >/dev/null 2>&1 || true
# Also show a local macOS notification when available
if command -v osascript >/dev/null 2>&1; then
  LC_ALL=en_US.UTF-8 osascript \\
    -e 'on run argv' \\
    -e 'display notification (item 1 of argv) with title (item 2 of argv) sound name "Glass"' \\
    -e 'end run' "\$MSG" "Claude Code · \$PROJECT" >/dev/null 2>&1 || true
fi
case "\$MODE" in once) rm -f "\$STATE";; always) touch "\$STATE";; esac
exit 0
EOF

cat > ~/.claude/bark/tellme.sh <<'EOF'
#!/bin/bash
# Usage: tellme.sh [always|once|off|stop|status|global on|global off]   (default: always)
ACTION="${1:-always}"; DIR="$HOME/.claude/bark/state"; mkdir -p "$DIR"; GLOBAL_OFF="$HOME/.claude/bark/global-off"
ACTIVE=$(grep -lxE 'once|always' "$DIR"/* 2>/dev/null | grep -v '/pending$' | wc -l | tr -d ' ')
MUTED=$(grep -lx off "$DIR"/* 2>/dev/null | grep -v '/pending$' | wc -l | tr -d ' ')
PEND=$( [ -f "$DIR/pending" ] && cat "$DIR/pending" || echo "" )
case "$ACTION" in
  once)   echo once > "$DIR/pending";   echo "🔔 Armed: you'll get one push when your next task finishes, then it turns off automatically.";;
  always) echo always > "$DIR/pending"; echo "🔔 On: starting with your next task, every turn in this session will push. /tellme off to mute this session.";;
  off|stop) echo off > "$DIR/pending"; echo "🔕 Muted this session only — other sessions still push. /tellme to turn it back on.";;
  status) echo "Global: $( [ -f "$GLOBAL_OFF" ] && echo off || echo on ); pending: ${PEND:-none}; sessions explicitly on: $ACTIVE; muted: $MUTED";;
  global) case "$2" in
            on)  rm -f "$GLOBAL_OFF"; echo "🌐 Global mode ON: every session pushes unless muted with /tellme off.";;
            off) touch "$GLOBAL_OFF"; echo "🌐 Global mode OFF: only sessions that ran /tellme will push.";;
            *)   echo "❌ Use: global on|off"; exit 1;;
          esac;;
  *) echo "❌ Unknown argument '$ACTION'. Use: (none = on)|once|off|status|global on|off"; exit 1;;
esac
find "$DIR" -type f -mtime +7 -delete 2>/dev/null
EOF

cat > ~/.claude/skills/tellme/SKILL.md <<'EOF'
---
name: tellme
description: Push a Bark notification to your phone when the current session's task finishes. On for every session by default. /tellme off = mute this session; /tellme = turn this session back on; /tellme once = next task only; /tellme status = show state.
---
Do exactly one thing: run the Bash command below, then relay its output to the user verbatim (no additions, nothing else).

```bash
bash ~/.claude/bark/tellme.sh "$ARGUMENTS"
```
EOF
cat > ~/.claude/bark/carry.sh <<'EOF'
#!/bin/bash
# SessionEnd/SessionStart hook: carry /tellme state across /clear (which starts a new session_id).
INPUT=$(cat)
command -v jq >/dev/null || exit 0
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
SID=$(echo "$INPUT" | jq -r '.session_id // empty')
DIR="$HOME/.claude/bark/state"; CARRY="$DIR/carry"
[ -n "$SID" ] || exit 0
case "$EVENT" in
  SessionEnd)
    [ "$(echo "$INPUT" | jq -r '.reason // empty')" = clear ] && [ -f "$DIR/$SID" ] && mv -f "$DIR/$SID" "$CARRY";;
  SessionStart)
    [ "$(echo "$INPUT" | jq -r '.source // empty')" = clear ] && [ -f "$CARRY" ] && mv -f "$CARRY" "$DIR/$SID";;
esac
exit 0
EOF
chmod +x ~/.claude/bark/*.sh

S=~/.claude/settings.json; [ -f "$S" ] || echo '{}' > "$S"
node -e '
const fs=require("fs"),p=process.argv[1];const s=JSON.parse(fs.readFileSync(p));
s.hooks??={};
const add=(ev,cmd)=>{
  s.hooks[ev]??=[];
  // drop any existing copies of our command (also cleans up duplicates from older installers)
  s.hooks[ev]=s.hooks[ev].map(g=>({...g,hooks:(g.hooks||[]).filter(h=>h.command!==cmd)})).filter(g=>g.hooks.length);
  s.hooks[ev].push({hooks:[{type:"command",command:cmd,timeout:10}]});
};
add("Stop","bash \"$HOME/.claude/bark/notify.sh\"");
add("SessionEnd","bash \"$HOME/.claude/bark/carry.sh\"");
add("SessionStart","bash \"$HOME/.claude/bark/carry.sh\"");
fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n");' "$S"

curl -s -m 10 -G "https://api.day.app/$KEY/" --data-urlencode "title=Claude Code" --data-urlencode "body=Installed ✅" >/dev/null || true
echo "✅ Installed. Your phone should have received a test push. No restart needed — just type /tellme in Claude Code."
