---
name: standup
description: Use when the user is preparing or reviewing what to say at their daily stand-up, or asks for a report of what they did. Typical triggers - "I have standup soon", "daily standup", "what do I tell the team", "what did I do yesterday", "summary of my activity", "team meeting", "standup".
---

# Daily stand-up

A stand-up lasts **90 seconds** and is spoken aloud to the team: **every sentence must
survive "how do you know?"**. A sentence invented here is not a typo, it is a false
thing said to colleagues.

You assemble evidence. You do not write a speech.

## Step 0 - The window is the last day the user worked. Always.

A stand-up tells **one full day**, from `00:00` to `00:00`. It is not a chain to follow,
nor an instant to resume from: it is **a date on the calendar**.

1. **Which day is the next stand-up?** The current time decides:
   - before 12:00 → the stand-up is **this morning** → stand-up day = **today**
   - from 12:00 on → the stand-up is **tomorrow morning** → stand-up day = **tomorrow**
2. **If that day is a Saturday or a Sunday, there is no stand-up.** Move it to the
   following Monday.

**The clock only picks the candidate day. Steps 2 and 3 then override it**, and they
win. A Friday-afternoon run, a Saturday run and a Sunday run all report **Friday**. Read
the afternoon paragraph below as describing a working day, because on a weekend it has
already been overruled.
3. **The window is the last working day before the stand-up day**, `00:00` to `00:00`.
   Stand-up on Thursday 2026-10-08 → window `2026-10-07 00:00 → 2026-10-08 00:00`.
   Stand-up on Monday → the window is **Friday**, not Sunday: see below.

**The window always ends in the past.** Never pass an end in the future, and never let
it run to "now". An afternoon run prepares *tomorrow's* stand-up, so the window is
**today**, which is still open: collect it anyway, say in Provenance that the window
ends at midnight and the day is not finished, and expect to re-run.

A morning run prepares *this morning's* stand-up, so the window is **yesterday**, and
this morning's work does not belong in it. You will tell that tomorrow.

**Monday.** The last working day is Friday, and Saturday and Sunday are almost always
empty. Collect **Friday** `00:00 → Saturday 00:00`. If a stand-up file already exists
for a day after Friday, Friday has been told: **ask** before telling it again.

**Re-running for the same stand-up.** The window does **not** change: it is the same
day. Update the file, do not open a new window. On an afternoon re-run more of the day
exists than the first time, which is the point.

**The previous stand-up file** is read for `To check` and for the ticket keys the user
named in it. Nothing else in it is evidence: it does not decide the window, and a claim
that appears only there was written by you, not observed.

`STANDUP_DIR`, `STANDUP_WRITE` and `STANDUP_COMMIT` are read by **you**, not by any
script. Nothing enforces them; they are settings for the person following these
instructions. `STANDUP_DIR` has no default anywhere, so export one in Step 1 before you
use it.

If that directory is a git repository, `pull --ff-only` before reading, so `To check`
starts from the last stand-up actually written, including from another machine. If the
pull fails, carry on with what is on disk and say so: it is a read, and nothing here is
worth stopping a stand-up for.

Pass start and end to the scripts in exactly this format: **`"YYYY-MM-DD HH:MM"`**. It
is the only one `git --since/--until` and `date -d` read the same way.

Put the window on the **first line** of the output.

## Step 1 - Collect, in this order

The three scripts live in the same directory as this file. Your working directory may
reset between commands, so resolve that directory once, keep it in a variable, and call
the scripts through it rather than relying on a `cd` that may not survive:

```bash
SKILL_DIR=<the directory this SKILL.md was loaded from>   # e.g. ~/.claude/skills/standup
```

**Before the first run, export the ticket prefix**, or no ticket key will ever be
found. `export` matters: the scripts are child processes, and a plain shell variable
never reaches them. The `: "${VAR:=value}"` form belongs in the config file, which the
scripts source, and nowhere else.

```bash
export STANDUP_TICKET_PREFIX="${STANDUP_TICKET_PREFIX:-PROJ}"  # theirs, e.g. SNRC; several: "PROJ|OPS"
export STANDUP_DIR="${STANDUP_DIR:-$HOME/standup}"
```

Ask them for the prefix if you cannot see it in their branch names.

```bash
"$SKILL_DIR/sessions.sh" "<start>" "<end>"   # what THEY wrote: the most faithful source
"$SKILL_DIR/collect.sh"  "<start>" "<end>"   # git: commits, dated WIP, unpushed, ticket keys
"$SKILL_DIR/tickets-jira.sh" PROJ-1 PROJ-2   # optional: keys space separated, run it even with none
cat "$(ls -t "$STANDUP_DIR"/*.md 2>/dev/null | head -1)" 2>/dev/null \
  || echo "(no previous stand-up)"
```

`sessions.sh` goes first: reviews, analysis and calls leave no commits. It truncates at
200 characters and marks what it cut as `[...+N chars]`. **Any line carrying that mark
may be hiding a drafted message**, so before you write "prepared" anywhere, re-run it
with `STANDUP_MAX_CHARS=800` and read those lines whole.

`collect.sh` prints two groups. What is under the repository headings happened inside
the window. What is under **`## parked, nothing inside the window`** did not, and never
belongs in the stand-up: a branch sitting on a ticket name is where the repository was
left, not work, and uncommitted files carry the date they were last touched.

**Run `tickets-jira.sh` even when `collect.sh` found no keys.** With no arguments it
asks a different question, "what of mine moved in the last two days", and the answer is
what Step 2's rule about dropping Jira tickets is written for.

It exits `3` when Jira was never configured, prints that on stderr, and prints nothing
on stdout. That is a normal state, not a failure: say nothing about it. Exits `4` and
`5` mean it was configured and broke; those go in Provenance.

## Step 2 - The output is this, in this order, and nothing else

1. `Window: YYYY-MM-DD 00:00 → YYYY-MM-DD 00:00` — the full day fixed in Step 0. It
   tells tomorrow's reader what was looked at; it is **not** an anchor for the next
   window, which is recomputed from the calendar
2. `## Yesterday` — **prose, not bullets**: a short paragraph, at most **four threads**,
   under **120 words**. It is read aloud, so it has to sound like someone talking
3. `## To check` — checkboxes of **their** open commitments, from the previous stand-up
   and from this window. On the first run the previous file does not exist: write that,
   do not leave the section mute
4. `## Provenance` — one line per claim: the source (commit / their 09:36 sentence /
   Jira), plus notes about the tools when one of them actually broke (e.g.
   "tickets-jira.sh exited 4: Jira refused the login, statuses not verified"), and
   the threads dropped. **Not** read to the team: it exists so they can defend every
   sentence.

**What this does not do.** It does not say what they will do today, and it does not list
their blockers. Nothing in the data knows either: today is a decision, and a blocker is
a judgement about who has to move. They say those two from their own head, in their own
words. This tells them the one part that can be sourced — what actually happened.

### Prose, with the discipline the bullets used to carry

Prose is where this kind of tool usually goes soft, so the caps move rather than vanish:

- **One sentence per thread.** If a thread has commits, uncommitted work and a drafted
  message, it stays one sentence: join them. Three sentences about one topic eat the
  whole paragraph. Join only what `collect.sh` put inside the window: uncommitted work
  it dated before the window, or listed as parked, is not part of the day and joining
  it would date it by association.
- **Four threads, 120 words, no exceptions.** That is about forty-five seconds, which
  leaves room for the today and the blockers they say themselves.
- **First person, past tense, and the verb carries the outcome.** They are saying this
  about themselves: "I released billing, search and invoicing to staging", not "Release
  to staging of three services". A telegraphic noun phrase reads like a ticket title and
  sounds wrong out loud. Name the things rather than count them: a count is a number you
  worked out, and Step 3 does not allow those.
- **Ban the empty verbs.** "I worked on", "I dealt with", "I handled", "I followed up on"
  say nothing and eat the budget. The verb has to be the thing that happened: released,
  fixed, merged, pushed, drafted, renamed. If no such verb exists, the thread probably
  does not deserve a sentence.
- **No linking waffle.** No "besides", "regarding", "as mentioned". A stand-up is a list
  spoken out loud, not an essay.
- **The ticket key goes inline**, where it is said: `PROJ-1487 moved to READY TO QA`.

**If there are more than four threads**, the priority order is: (1) what produced
commits or was delivered to someone, (2) what is waiting on an answer from others,
(3) what is open but stalled. The dropped ones go in Provenance, not in the text.

**Which key counts:** the one *they* name — and the previous stand-up counts as their
word, not as second-hand. Commits land on whatever branch was open at the time, which
may carry another job's key: when the branch name carries a different key from the one
they named, write theirs and note the branch in Provenance.

**What to drop from Jira:** the tickets the script adds because they are assigned and
recently moved count only if a local source ties them to the window.

**Write in the language of their own prompts**, as `sessions.sh` prints them, not the
language whoever started this session happens to be using. They will say this out loud
to their own team; a stand-up translated into English is one they have to translate
back while the meeting waits.

**The three headings stay in English**, exactly as written above: tomorrow's run reads
`To check` out of today's file, and a translated heading quietly breaks that.
Everything under them is in their language.

Cutting is your job, not theirs.

## Step 3 - Provenance: the rules that are not negotiable

- **A draft is not a fact.** If a session contains the text of a message or a ticket
  comment, the most you may write is "prepared", never "sent" or "notified", unless
  explicitly confirmed.
- **No number computed by you.** Report only figures read from a source, as they stand.
  Do not add up, do not round, do not derive percentages.
- **No opinion put in their mouth.** If a sentence is not in their messages or commits,
  it does not go in the first person. They make the proposals.
- **A contradicted fact is dead.** If later in the same session a count was overturned,
  the last version holds; if the first one already circulated, say so.
- **Workstation work stays out** (VMs, VPN, drivers, IDE, and the tools they build for
  themselves), unless it stopped the work: then it is one clause inside the thread it
  stopped. Something that got in the way and was solved is not worth a word.
- **When this rule drops a thread that produced commits, say so and let them decide.**
  A tool built for other people may well be work their team wants to hear about, and
  that call is theirs. Name the dropped threads in Provenance, always. If the rule
  empties the window entirely, which is what the first run looks like for most people
  because that window contains them installing this very tool, do not report an empty
  day: write one sentence saying where the day went and that it fell outside the team's
  work.
- **An empty source is declared.** "No commits yesterday" is a legitimate sentence to
  say at a stand-up. Filling the void with context is the worst thing you can do here.

### Rationalizations to watch for

| Thought | Reality |
|---|---|
| "They must have sent that message" | The draft only proves it was written. Write "prepared". |
| "This number follows by adding up" | Your sum is a new number, not a fact. Cite the addends or nothing. |
| "It is implicit that they think so" | If they did not write it, it does not exist. |
| "Git is empty, I will fill with context" | An empty source is declared, not compensated for. |
| "Better too much, they can cut" | 900 words do not fit in 90 seconds. You cut. |
| "The window is ambiguous, I will ask" | Step 0 is a date on the calendar. The only thing it asks about is widening past Friday. |
| "I will resume where the last one ended" | **No.** The window is the last working day, recomputed every time. |
| "It is afternoon, so I will stop at now" | The window ends at midnight. Say the day is still open; do not shorten it. |
| "It is morning, I will add this morning too" | A morning run tells yesterday. This morning is told tomorrow. |

### Red flags - stop and verify

- you are writing "I notified", "I sent", "I closed" without a confirmation
- you are doing arithmetic
- you are past four threads or 120 words
- you are writing a second sentence about a thread you have already told
- you are writing what they will do today, or calling something a blocker

## Step 4 - Show the draft before writing

Everything in the output comes from a source, so there is nothing here for them to
supply. Show the draft anyway and give them the chance to correct a fact or cut a
thread: they were there, the sources were not.

Then write it, according to Step 5.

## Step 5 - Write the file, if you are allowed to

Two settings decide this, and **both default to `ask`**. A tool that writes files and
pushes to someone's repository the first time they run it has not earned that yet.

| Variable | Values | Default |
|---|---|---|
| `STANDUP_WRITE` | `ask` / `yes` / `no` | `ask` |
| `STANDUP_COMMIT` | `ask` / `yes` / `no` | `ask` |

- `ask` - show the draft, then ask once. The answer holds for this stand-up, not forever.
- `yes` - write without asking. What someone sets once they trust it.
- `no` - never write. The stand-up is delivered in the conversation and that is all.

With `STANDUP_WRITE=no`, say plainly what is lost: `To check` can never carry anything
forward, because it is read from the previous file. Say it once, not every day.

When you do write: `$STANDUP_DIR/YYYY-MM-DD.md`, dated with **the day the stand-up will
be said**, not the day it is prepared - the evening of the 8th for the 9th's meeting is
`2026-09-09.md`. Create the directory if missing; if the file exists, **update it**
(never two files for one stand-up). Do not drop the `Window:` line: it is what makes
tomorrow's window right.

## Step 6 - Commit and push, if you are allowed to

Only when the file was written, `$STANDUP_DIR` is a git repository, and `STANDUP_COMMIT`
is not `no`. Nothing here creates a repository or adds a remote.

A stand-up left only on disk is not saved: tomorrow Step 0 may start from a file the
other machines do not have, and the window slides back without anyone noticing. That is
the reason to turn this on - not a reason to turn it on for someone.

If the push fails, **tell the user** with the error: it is not a detail to swallow in
silence.
