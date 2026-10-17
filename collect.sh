#!/usr/bin/env bash
# Collects the state of your local work across every git checkout under your
# workspace roots: your commits in the window, work in progress, unpushed branches,
# and the ticket keys your branches and messages mention.
# READ-ONLY: no fetch, no pull, no checkout, no commit. No network.
# Usage: collect.sh "<start>" ["<end>"]   e.g. collect.sh "2026-10-07 00:00" "2026-10-08 00:00"
# The end is optional; without it the window runs to "now".
set -uo pipefail

# Optional config file, so these settings do not have to live in your shell
# profile. Assign inside it with `: "${VAR:=value}"`, so a variable you set for
# a single run still wins over the file.
CHOREI_CONFIG="${CHOREI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/chorei/config}"
# shellcheck disable=SC1090
[ -r "$CHOREI_CONFIG" ] && . "$CHOREI_CONFIG"

# Workspace roots, colon-separated. Without configuration, the first of the usual
# suspects that exists is used, so the tool works before it is configured.
if [ -n "${STANDUP_WS:-}" ]; then
  ROOTS="$STANDUP_WS"
else
  ROOTS=""
  for guess in "$HOME/Workspaces" "$HOME/workspace" "$HOME/code" "$HOME/src" "$HOME/projects" "$HOME/dev"; do
    [ -d "$guess" ] && { ROOTS="$guess"; break; }
  done
  if [ -z "$ROOTS" ]; then
    echo "ERROR: no workspace root found. Set STANDUP_WS to where your repositories live," >&2
    echo "       colon-separated for several, e.g. STANDUP_WS=\"\$HOME/work:\$HOME/oss\"" >&2
    exit 2
  fi
fi

AUTHOR="${STANDUP_GIT_AUTHOR:-$(git config --get user.email 2>/dev/null)}"
if [ -z "$AUTHOR" ]; then
  echo "ERROR: no git author. Set STANDUP_GIT_AUTHOR, or set git's user.email." >&2
  exit 2
fi

# Jira-style ticket prefixes, separated by | for several (e.g. "PROJ|OPS").
# Empty means no ticket extraction: an empty prefix in the regex would match every
# number in every branch name, which is worse than extracting nothing.
PREFIX="${STANDUP_TICKET_PREFIX:-}"
SINCE="${1:-yesterday 00:00}"
UNTIL="${2:-}"   # exclusive: a standup tells a closed day, not "up to now"

echo "# git collection - roots: $ROOTS"
if [ -n "$UNTIL" ]; then
  echo "# author: $AUTHOR | window: '$SINCE' to '$UNTIL' | read at $(date '+%Y-%m-%d %H:%M')"
else
  echo "# author: $AUTHOR | window: '$SINCE' to now | $(date '+%Y-%m-%d %H:%M')"
fi
echo "# NB: 'unpushed' is based on local remote-refs, without fetching: it can be stale."
echo

CHECKOUTS=()
IFS=':' read -r -a root_list <<< "$ROOTS"
for root in "${root_list[@]}"; do
  [ -d "$root" ] || { echo "# WARNING: root not found, skipped: $root"; continue; }
  while IFS= read -r line; do CHECKOUTS+=("$line"); done \
    < <(find "$root" -maxdepth 6 -name .git -printf '%h\n' 2>/dev/null | sort)
done

declare -A seen_commits      # one repository shared by several worktrees has the same commits
total=0; active=0; keys=""

extract_keys() {
  [ -z "$PREFIX" ] && { cat >/dev/null; return; }
  grep -oiE "(${PREFIX})[ _-]?[0-9]{1,6}" \
    | tr '[:lower:]' '[:upper:]' | tr ' _' '--' | sort -u | tr '\n' ' '
}

for repo in "${CHECKOUTS[@]}"; do
  total=$((total+1))
  name="$repo"
  for root in "${root_list[@]}"; do name="${name#"$root"/}"; done
  branch=$(git -C "$repo" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch="(detached HEAD)"

  # Worktrees share the object store and refs with the main repository: attribute the
  # commits once, but keep branch and work-in-progress for every checkout.
  common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  commits=""
  if [ -z "${seen_commits[$common]:-}" ]; then
    seen_commits[$common]=1
    # --source + %S: every commit carries the ref it is reachable from. Without it,
    # with worktrees the commits landed under the wrong checkout's branch.
    until_arg=(); [ -n "$UNTIL" ] && until_arg=(--until="$UNTIL")
    # %cd, not %ad: --since/--until filter the commit date, so showing the author
    # date makes a rebased commit look like it landed days before the window.
    commits=$(git -C "$repo" log --all --source --author="$AUTHOR" --since="$SINCE" \
               "${until_arg[@]}" \
               --format='  commit %cd [%S] %s' --date=format:'%d/%m %H:%M' 2>/dev/null \
               | sed 's#refs/heads/##; s#refs/remotes/##' | sort -u)
  fi

  dirty=$(git -C "$repo" status --porcelain 2>/dev/null | grep -cv '^??')
  untracked=$(git -C "$repo" status --porcelain 2>/dev/null | grep -c '^??')

  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  ahead=""
  if [ -n "$upstream" ]; then
    n=$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] && ahead="  unpushed: $n commit(s) on $branch (upstream $upstream)"
  elif [ "$branch" != "(detached HEAD)" ]; then
    ahead="  unpushed: branch '$branch' has no upstream (never pushed?)"
  fi

  # A checkout is interesting if it has your commits, work in progress (even only new
  # files), something unpushed, or a branch naming a ticket: a worktree holding only
  # untracked files is still open work and belongs in the standup.
  names_ticket=0
  [ -n "$PREFIX" ] && names_ticket=$(printf '%s' "$branch" | grep -ciE "(${PREFIX})[ _-]?[0-9]{1,6}")
  if [ -n "$commits" ] || [ "${dirty:-0}" -gt 0 ] || [ "${untracked:-0}" -gt 0 ] \
     || [ -n "$ahead" ] || [ "${names_ticket:-0}" -gt 0 ]; then
    active=$((active+1))
    echo "## $name  [on branch: $branch]"
    [ -n "$commits" ] && echo "$commits"
    [ -n "$ahead" ] && echo "$ahead"
    if [ "${dirty:-0}" -gt 0 ] || [ "${untracked:-0}" -gt 0 ]; then
      echo "  work-in-progress: ${dirty:-0} modified, ${untracked:-0} untracked"
      git -C "$repo" status --porcelain 2>/dev/null | grep -v '^??' | head -5 \
        | sed 's/^/    touched: /'
    fi
    echo
    keys="$keys $(printf '%s\n%s\n' "$branch" "$commits" | extract_keys)"
  fi
done

if [ -n "$PREFIX" ]; then
  echo "## ticket keys found (prefix: $PREFIX)"
  ck=$(printf '%s' "$keys" | tr ' ' '\n' | grep -E '^[A-Z]+-[0-9]+$' | sort -u | tr '\n' ' ')
  if [ -n "$ck" ]; then echo "$ck"; else echo "(none: no branch or message names a $PREFIX ticket)"; fi
else
  echo "## ticket keys: disabled (set STANDUP_TICKET_PREFIX, e.g. PROJ or 'PROJ|OPS')"
fi
echo
echo "## coverage"
echo "checkouts scanned: $total | with activity or work in progress: $active"
if [ "$active" -eq 0 ]; then
  echo "WARNING: no activity in this window. Do not invent: say so."
fi
exit 0
