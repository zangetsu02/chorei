#!/usr/bin/env bash
# Extracts what YOU wrote from your Claude Code transcripts, inside a time window.
# Git only shows what was committed; reviews, analysis and calls live here.
# READ-ONLY. No network. It never prints the assistant's replies: those are Claude's
# guesses, not your facts, and mixing the two is how a stand-up becomes fiction.
# Usage: sessions.sh "<start>" ["<end>"]    default start: "yesterday 00:00"
# The end is optional and exclusive; without it the window runs to "now".
set -uo pipefail

# Optional config file. See config.example for the form it uses.
CHOREI_CONFIG="${CHOREI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/chorei/config}"
# shellcheck disable=SC1090
[ -r "$CHOREI_CONFIG" ] && . "$CHOREI_CONFIG"

# shortcut: GNU date and stat only, BSD flags differ. Upgrade when someone
# needs macOS without coreutils.
DATE=date; command -v gdate >/dev/null 2>&1 && DATE=gdate
STAT=stat; command -v gstat >/dev/null 2>&1 && STAT=gstat
if ! "$DATE" -d @0 >/dev/null 2>&1; then
  echo "ERROR: GNU date is required. On macOS: brew install coreutils" >&2
  exit 2
fi

FROM="${1:-yesterday 00:00}"
if ! cutoff=$("$DATE" -d "$FROM" +%s 2>/dev/null); then
  echo "ERROR: cannot parse date: $FROM" >&2
  exit 2
fi
TO="${2:-}"
if [ -n "$TO" ]; then
  if ! until_ts=$("$DATE" -d "$TO" +%s 2>/dev/null); then
    echo "ERROR: cannot parse date: $TO" >&2
    exit 2
  fi
else
  until_ts=$(date +%s)
fi

PROJ="${STANDUP_PROJECTS:-$HOME/.claude/projects}"
MAXLINES="${STANDUP_MAX_LINES:-60}"
MAXCHARS="${STANDUP_MAX_CHARS:-200}"   # raise it to read a drafted message in full

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }

# A missing transcript directory is an empty source, not a failure: someone who
# only wants the git side, or who keeps transcripts elsewhere, still gets a
# stand-up. Saying so is the whole point; stopping here would not be.
if [ ! -d "$PROJ" ]; then
  echo "(no transcript directory at $PROJ)"
  echo "WARNING: empty source. Set STANDUP_PROJECTS if your agent keeps its sessions elsewhere."
  exit 0
fi

echo "# Your prompts in Claude Code sessions, $("$DATE" -d "$FROM" '+%d/%m %H:%M') to $("$DATE" -d "@$until_ts" '+%d/%m %H:%M')"
echo "# (your messages only, truncated; times are local)"
echo

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT

# Note: no `find -newermt` here. On bfs (the default find on Arch) it rejects dates
# written in natural language. The mtime filter is done with stat instead.
for f in "$PROJ"/*/*.jsonl; do
  [ -f "$f" ] || continue
  m=$("$STAT" -c %Y "$f" 2>/dev/null) || continue
  [ "$m" -lt "$cutoff" ] && continue

  jq -r --argjson cutoff "$cutoff" --argjson until "$until_ts" --argjson maxchars "$MAXCHARS" '
    select(.type=="user" and (.isMeta // false | not) and (.isSidechain // false | not))
    | (.timestamp // "" | sub("\\.[0-9]+Z$";"Z")) as $iso
    | select($iso != "")
    | ($iso | fromdateiso8601) as $ep
    | select($ep >= $cutoff and $ep < $until)
    | (if (.message.content|type)=="string" then .message.content
       else [(.message.content[]? | select(.type=="text") | .text)] | join(" ") end) as $c
    | select($c != null and ($c|length) > 1)
    # Drop the machine noise: command output, notifications, images, interruptions.
    # What is left is what you typed.
    | select($c | test("system-reminder|<command-name>|tool_use_id|Caveat:|\\[Request interrupted|<local-command-|<bash-input>|<bash-stdout>|<bash-stderr>|<task-notification>|^\\[Image #") | not)
    | ($c | gsub("\\s+";" ")) as $clean
    # Two path segments, not one: a bare basename labels work in $HOME with the
    # account name, and collapses every worktree of a repo onto the same label.
    | ((.cwd // "?") | split("/") | if length > 1 then .[-2:] | join("/") else .[-1] end) as $where
    | [$ep, ($ep|strflocaltime("%d/%m %H:%M")), $where, ($clean|.[0:$maxchars]), (($clean|length) - $maxchars)]
    | @tsv' "$f" 2>/dev/null >> "$tmp"
done

if [ ! -s "$tmp" ]; then
  echo "(no prompts of yours in this window)"
  echo "WARNING: empty source. Do not conclude you did nothing, and do not invent."
  exit 0
fi

# A cut prompt says so, with how much is missing: you cannot tell that a
# truncated line was hiding a drafted message unless the gap is visible.
sort -n -u "$tmp" | cut -f2- \
  | awk -F'\t' '{ if ($4 > 0) printf "%s [%s] %s[...+%d chars]\n", $1, $2, $3, $4;
                  else printf "%s [%s] %s\n", $1, $2, $3 }' \
  | head -n "$MAXLINES"

lines=$(sort -n -u "$tmp" | wc -l)
if [ "$lines" -gt "$MAXLINES" ]; then
  echo
  echo "(truncated: $lines prompts total, showing the first $MAXLINES - raise STANDUP_MAX_LINES)"
fi
exit 0
