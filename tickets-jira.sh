#!/usr/bin/env bash
# Queries Jira with ONE authenticated call. The password comes from the system
# keyring, never from arguments or a plaintext file.
#
# Usage: tickets-jira.sh [PROJ-1645 PROJ-1646 ...]
# Exit:  0 data ok | 3 not configured | 4 auth refused | 5 HTTP/network error
#
# WARNING: on Jira Server a burst of 401s trips the CAPTCHA on the account, and from
# then on REST basic auth is refused until you log in from a browser. That is why
# this script NEVER retries: a 401 is terminal.
set -uo pipefail

BASE="${STANDUP_JIRA_BASE:-}"
USERNAME="${STANDUP_JIRA_USER:-$USER}"
DAYS="${STANDUP_JIRA_DAYS:-2}"
SERVICE="${STANDUP_JIRA_KEYRING_SERVICE:-standup-jira}"

if [ -z "$BASE" ]; then
  echo "JIRA: not configured - set STANDUP_JIRA_BASE (e.g. https://jira.example.com)."
  echo "The standup continues without ticket status and titles."
  exit 3
fi

command -v secret-tool >/dev/null || { echo "JIRA: secret-tool not installed; skipping."; exit 3; }

PASS=$(secret-tool lookup service "$SERVICE" username "$USERNAME" 2>/dev/null)
if [ -z "$PASS" ]; then
  cat <<MSG
JIRA: not configured - no password in the keyring.
To enable it, run once:
  secret-tool store --label='Standup Jira' service $SERVICE username $USERNAME
On Jira Cloud use an API token as the password.
The standup continues without ticket status and titles.
MSG
  exit 3
fi

# The keys from branches and commits, plus tickets assigned to you and moved
# recently: one query.
if [ "$#" -gt 0 ]; then
  list=$(printf '%s,' "$@" | sed 's/,$//')
  JQL="(key in ($list)) OR (assignee = currentUser() AND updated >= -${DAYS}d) ORDER BY updated DESC"
else
  JQL="assignee = currentUser() AND updated >= -${DAYS}d ORDER BY updated DESC"
fi

hdr=$(mktemp) ; body=$(mktemp)
trap 'rm -f "$hdr" "$body"' EXIT

# -K - reads the credentials from stdin: they appear neither in ps nor in history.
code=$(printf 'user = "%s:%s"\n' "$USERNAME" "$PASS" | curl -sS -K - \
  --max-time 25 --get \
  --data-urlencode "jql=$JQL" \
  --data-urlencode "fields=summary,status,assignee,updated" \
  --data-urlencode "maxResults=30" \
  -D "$hdr" -o "$body" -w '%{http_code}' \
  "$BASE/rest/api/2/search" 2>/dev/null)

case "$code" in
  200) : ;;
  401|403)
    reason=$(grep -i '^X-Authentication-Denied-Reason' "$hdr" | tr -d '\r')
    echo "JIRA: authentication refused (HTTP $code) - NOT retrying, to avoid making it worse."
    if printf '%s' "$reason" | grep -qi captcha; then
      echo "Cause: CAPTCHA is active on the account ($reason)."
      echo "Fix: open $BASE in a browser, log in solving the CAPTCHA, then try again."
    else
      echo "Likely cause: the keyring password is no longer valid (expired or changed)."
      echo "Fix: secret-tool store --label='Standup Jira' service $SERVICE username $USERNAME"
    fi
    exit 4 ;;
  000)
    echo "JIRA: no response from $BASE (network or DNS). The standup continues without Jira."
    exit 5 ;;
  *)
    echo "JIRA: unexpected HTTP $code from $BASE. The standup continues without Jira."
    head -c 300 "$body"
    exit 5 ;;
esac

total=$(jq -r '.total // 0' "$body")
echo "# Jira $BASE - JQL: $JQL"
echo "# tickets found: $total"
jq -r '.issues[]? | "\(.key) | \(.fields.status.name) | assignee: \(.fields.assignee.displayName // "none") | upd. \(.fields.updated[0:16]) | \(.fields.summary)"' "$body"
[ "${total:-0}" -eq 0 ] && echo "(no tickets: do not infer a status Jira did not confirm)"
exit 0
