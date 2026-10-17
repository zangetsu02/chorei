<p align="center">
  <img src="assets/banner.png" alt="chorei: what you did yesterday, with its sources" width="760">
</p>

# chorei 朝礼

*Chōrei* is the morning assembly a Japanese workplace opens the day with. This one
assembles the evidence of yours: your git work, your coding-agent sessions, your
tickets, so that every line you say to your team survives one question, *how do you
know?*

Everything runs on your machine. Nothing is uploaded, no API key is needed, and the
collectors make no network calls except the optional Jira one.

## What it adds to your commit log

[`git-standup`](https://github.com/nilbuild/git-standup) shows you what you committed.
`chorei` also shows what the commits leave out: the reviews, the analysis, the calls,
the message you drafted but have not sent, the work still uncommitted on a branch.

It stops at the evidence, grouped by thread, each item carrying its source. The summary
is yours to say, in your own words, in the ninety seconds you have.

Most of its rules are about what it will not say:

- a drafted message counts as *prepared*, never as *sent*
- no number is computed, only quoted
- an empty source is declared, never filled in with context
- the window is the day before the stand-up, recomputed from the calendar every time

## What it collects

| Script | Source | What it gives you |
|---|---|---|
| `sessions.sh` | Claude Code transcripts | what *you* wrote, in the window; reviews, analysis and calls leave no commits |
| `collect.sh` | every git checkout under your roots | your commits, work in progress, unpushed branches, ticket keys |
| `tickets-jira.sh` | Jira (optional) | status and title of the tickets you touched |

All three are read-only. `collect.sh` never fetches, pulls or checks anything out.

## Install

As a Claude Code skill:

```sh
git clone https://github.com/<you>/chorei ~/.claude/skills/standup
```

The repository is `chorei`; the skill it installs is called `standup`, because that is
the word you will type. Then say *"I have standup soon"* and it runs. You can also call
the scripts directly: they are plain bash and print to stdout.

Requires `bash`, `git`, `jq`, and `curl` only if you use Jira.

## Configure

Nothing is mandatory. Without configuration it finds your repositories in the usual
places and takes the git author from `git config user.email`.

| Variable | Default | What it is |
|---|---|---|
| `STANDUP_WS` | first existing of `~/Workspaces`, `~/workspace`, `~/code`, `~/src`, `~/projects`, `~/dev` | where your repositories live, colon-separated for several roots |
| `STANDUP_GIT_AUTHOR` | `git config user.email` | which commits are yours |
| `STANDUP_TICKET_PREFIX` | *(off)* | ticket prefixes, e.g. `PROJ` or `PROJ\|OPS` |
| `STANDUP_WRITE` | `ask` | write the stand-up to a file: `ask`, `yes` or `no` |
| `STANDUP_COMMIT` | `ask` | if `STANDUP_DIR` is a git repository, commit and push it: `ask`, `yes` or `no` |
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
trips the CAPTCHA on your account, so a 401 is terminal here: `chorei` never retries.

## The output

```
Window: 2026-10-16 00:00 → 2026-10-17 00:00

## Yesterday      prose, at most four threads, under 120 words
## To check       your open commitments, still unanswered
## Provenance     one line per claim: where it came from. Not read to the team.
```

Four threads and 120 words is about forty-five seconds. The rest of your ninety is what
you will do today and what is blocking you, and `chorei` says neither: your git history
does not know what you have decided to do next, and whether something counts as a
blocker depends on who has to move.

By default nothing is written anywhere. You are asked once, and nothing is committed or
pushed unless you say so. If you keep your stand-ups in a git repository and want that
automatic, set `STANDUP_WRITE=yes` and `STANDUP_COMMIT=yes`.

Keeping the files has one use: `To check` carries your open commitments from one
stand-up to the next, and it reads them from yesterday's file. With `STANDUP_WRITE=no`
that section is always empty.

## Licence

MIT.
