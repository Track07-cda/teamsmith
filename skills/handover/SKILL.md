---
name: handover
description: Hand over a long-running session to a fresh one without losing the project — write a pointer-only HANDOVER.md (pointers, never copied specs), record the questions the user asked and never got answered and the side effects the agent caused, then stand the old session down so the document cannot go stale. Triggered by the user saying handover or 交接.
license: MIT
metadata:
  version: "0.1.0"
---

# handover · cut over the session, do not copy it

The user decides when this happens; do not propose a handover on your own. When it does, the job is a
**cut-over, not a summary** — a new session is the only thing that gives a fresh shape, so the document must be
short, must point at what already exists on disk, and the old session must stop the moment it is written.

## Step 1 · Land the state (this is the gate)

Before writing anything, put everything that currently lives only in the conversation onto the disk:

- board statuses for anything started, finished, or blocked;
- a report or review record for every delivery that has none;
- instructions already given to worker seats (their threads), so the successor's instructions are continuous;
- open decisions → `docs/team/OPEN-ITEMS.md` (create it if absent);
- **every question the user asked that has not been answered, verbatim**, together with what was already verified.

If that state cannot be reconstructed from the disk, the handover will not work — fix the disk first.

## Step 2 · Write `docs/team/HANDOVER.md` from commands, never from memory

Fixed filename, overwritten, committed. Budget: **60 lines**. Template:

```
# Handover · <date time Z>
> Trust the disk and your own re-derivation, not the previous session's prose.
> Every line says where it lives if it is not here.

Header: main tip / released version / session (model · id) / why this handover happened (the user's words)

## 1 State            — 3..6 lines, each value followed by the command that re-derives it
## 2 In flight        — ID · phase · branch@tip · what it is blocked on ; details → BOARD
## 3 Asked and unanswered  ← the main course
    user's words verbatim / what I verified (file:line) / what you must give me: a decision or information /
    what I will do once answered / whether it is irreversible
## 4 Waiting on the user anyway   — pointers → OPEN-ITEMS.md, three most blocking + the ordering rule
## 5 Side effects I caused        — production values I changed, secrets I printed, uncommitted edits that
                                    are not mine, artefacts I left on disk
## 6 Next three commands
## 7 What this session learned that no file contains   ← the only free-text section
    one line each, each ending with "belongs in: <file>"
## 8 Read: AGENTS.md → BOARD.md → OPEN-ITEMS.md → this file
    Do not read: reports/ detail, threads/, previous handovers
```

**The pointer test, applied to every line:** *if this line were not here, where does it live?*
If it lives in a spec, board, review, runbook, decision log or memory — write the pointer, not the content.
Only three kinds of content have no home elsewhere: unanswered user questions, side effects I caused, and the
next three commands.

Things that are therefore **not** allowed in the document: a list of what was delivered this session, a table of
deployment results, copied commands that already live in a runbook, credentials or passwords (write where they
live), a summary of the conversation, and any history of a defect that is already fixed.

## Step 3 · Self-check the three questions

A successor must be able to answer, from the document alone: what is in flight, what is waiting on the user, what
is the next command. If any of the three is missing, the document is defective — fix it before standing down.

## Step 4 · Stand down (do not skip this)

After step 3 the old session **stops**: no commits, no dispatches, no decisions, no replies unless the user asks a
direct question. Anything done after this point makes the document false within seconds. The last thing the old
session says is that a new session may be opened in the same directory.

## Step 5 · Take over (the successor's first move)

The successor reads `AGENTS.md`, then `HANDOVER.md`, then `OPEN-ITEMS.md`, then re-derives two or three numbers
itself (`git rev-parse`, version, board counts). It replies in three lines — in flight, waiting on the user, next
command — **plus any divergence between the document and the disk, naming both values**. The disk wins; never
quietly adopt the document's number.

Then it works. Anything it had to dig for that the handover should have told it goes into section 7 in one commit:
that is the only mechanism that makes the next handover better.

## What each side says (prompt text, used at handover time — not resident)

Old session, on the trigger:

```
handover: land state, write docs/team/HANDOVER.md (≤60 lines, pointers only), self-check the three
questions, then stand down and tell the user to open a new session in this directory.
```

Successor, at session start:

```
Taking over. Read AGENTS.md, docs/team/HANDOVER.md, docs/team/OPEN-ITEMS.md. Re-derive two or three
numbers yourself; the disk wins over the document. Reply in three lines (in flight / waiting on the
user / next command) plus any divergence, then work.
```

## Boundaries

- Workers are unaffected: their seats keep running, their deliveries land in the inbox, the successor picks them
  up with `team digest`. The patrol keeps running.
- The handover never carries credentials, and never copies text out of `openspec/`, the board, reviews or runbooks.
- One file, overwritten each time. Dated handover files accumulate and become a second ledger — history belongs in
  git.
- Language: the prompts are English; the document body follows the project's own ledger language (keep it in one
  language with `AGENTS.md` so the successor reads one register, not two).

## Failure modes worth recognising

| Symptom | Cause |
|---|---|
| The successor asks questions the document should answer | pointer test skipped — content was summarised instead of located, or step 1 was skipped |
| The document is stale within a day | step 4 skipped: the old session kept working after writing it |
| Two different numbers for the same fact | content was copied instead of pointed at, and the original moved on |
| The successor trusts the document and gets it wrong | the successor re-derived nothing; step 5's divergence check is not optional |
