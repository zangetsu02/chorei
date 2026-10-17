# konkyo 根拠

**The grounds for what you say.** A stand-up assembler that gathers the evidence of your
day — your git work, your coding-agent sessions, your tickets — so that every line you
say to your team survives one question: *how do you know?*

Everything runs on your machine. Nothing is uploaded, no API key is needed, and the
collectors make no network calls at all except the optional Jira one.

## It does not write your stand-up

Tools that generate a paragraph from your commits exist, and nobody reads them aloud.
`konkyo` does the opposite: it puts the **evidence** in front of you, grouped by thread,
each item carrying its source. The summary is yours to say, in your own words, in the
ninety seconds you have.

What it refuses to do is the point:

- a drafted message counts as *prepared*, never as *sent*
- no number is computed, only quoted
- an empty source is declared, never filled in with context
- the window is the day before the stand-up, always — no "resume from last time"

## What it collects

| Script | Source | What it gives you |
|---|---|---|
| `sessions.sh` | Claude Code transcripts | what *you* wrote, in the window — reviews, analysis and calls leave no commits |
| `collect.sh` | every git checkout under your roots | your commits, work in progress, unpushed branches, ticket keys |
| `tickets-jira.sh` | Jira (optional) | status and title of the tickets you touched |

All three are read-only. `collect.sh` never fetches, pulls or checks anything out.

## Install

As a Claude Code skill:

```sh
git clone https://github.com/<you>/konkyo ~/.claude/skills/konkyo
```

Then say *"I have standup soon"* and the skill runs. Or call the scripts directly —
they are plain bash and print to stdout.

Requires `bash`, `git`, `jq`, and `curl` only if you use Jira.

## Configure

Nothing is mandatory: without configuration it finds your repositories in the usual
places and takes the git author from `git config user.email`.

| Variable | Default | What it is |
|---|---|---|
| `STANDUP_WS` | first existing of `~/Workspaces`, `~/workspace`, `~/code`, `~/src`, `~/projects`, `~/dev` | where your repositories live, colon-separated for several roots |
| `STANDUP_GIT_AUTHOR` | `git config user.email` | which commits are yours |
| `STANDUP_TICKET_PREFIX` | *(off)* | ticket prefixes, e.g. `PROJ` or `PROJ\|OPS` |
| `STANDUP_DIR` | `~/standup` | where the stand-up files are written |
| `STANDUP_PROJECTS` | `~/.claude/projects` | where your agent keeps its transcripts |
| `STANDUP_MAX_LINES` | `60` | prompts shown before truncating |
| `STANDUP_MAX_CHARS` | `200` | characters per prompt; raise it to read a draft in full |
| `STANDUP_JIRA_BASE` | *(off)* | e.g. `https://jira.example.com` |
| `STANDUP_JIRA_USER` | `$USER` | Jira username |
| `STANDUP_JIRA_DAYS` | `2` | how far back to look for tickets assigned to you |

The Jira password lives in the system keyring, never in a file or an argument:

```sh
secret-tool store --label='Standup Jira' service standup-jira username <you>
```

On Jira Cloud use an API token as the password. On Jira Server a burst of failed logins
trips the CAPTCHA on your account, so a 401 is terminal here: `konkyo` never retries.

## The output

```
Window: 2026-10-16 00:00 → 2026-10-17 00:00

## Done            max 4 bullets, one per thread
## Today           max 3, proposed — you confirm them
## Blockers        max 2, only what waits on someone else
## To check        your open commitments from the previous stand-up
## Provenance      one line per bullet: where it came from. Not read to the team.
```

Sections 1-5 stay under 180 words, because ninety seconds is ninety seconds.

## Licence

MIT.
