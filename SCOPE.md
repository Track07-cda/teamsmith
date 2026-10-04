# Scope of this project

<this-repo> is a **reusable skill repository**. This file draws the line around what an agent on this project should
and should not do, so effort does not leak into other projects and nobody edits someone else's state by accident.

## What I own (the only work surface)

> **Repository: `<this-repo>/`**
> **Deliverable: the skills under `skills/` (currently `teamsmith`) — code, templates, docs, tests, examples, install scripts.**

- The behaviour of the skill: `skills/*/scripts/**`, `skills/*/extension/**`
- The contract and documentation of the skill: `SKILL.md`, `references/**`, `templates/**`
- The quality of the skill: `skills/*/tests/**` (touch anything there and run the smoke suite; only all-green counts as done)
- This repository's docs and commits: `README.md`, `docs/**`, git commits
- Versioning: `metadata.version` in `SKILL.md` stays in sync with `TEAM_VERSION` in `scripts/lib/common.sh`

## What I do not do (other people's work surface)

| Not done | Why |
|---|---|
| Read or change another project's **repository contents** (code, `docs/**`, `.pi/team/**`) | that is that side's PM and agents' work surface |
| Read another project's **Pi session files** (`~/.pi/agent/sessions/…`) | sessions belong to that agent; information should come through the PM or the user |
| Touch another project's **tmux windows/panes**, message another PM | dispatching and waking agents is that side's PM's job; cross-project chatter breaks the boundary |
| Change another project's **code, merge its PR/MRs, change its remote state** | needs authorization from that side, and is not a deliverable of this repository |
| **Guess** another project's requirements in the name of the skill | feedback must arrive through the user, or be written by that side's PM to the user |

## How feedback arrives (the only channels)

1. Relayed by the user (verbatim is best; if it is truncated I ask the user instead of going and looking in the other project myself).
2. A file path the user names (e.g. "read `<some repo>/docs/…`") — **read only when the user names it**.

How feedback is handled: **change the skill and add a regression test in this repository only**, then hand the
conclusion back to the user; the parts that need the other project's cooperation (e.g. "that side has to restart its
watchdog") are spelled out and relayed by the user.

## Exception

When the user explicitly instructs it ("go look at X in some project", "reply to that PM"), crossing the boundary for
**that one** action is allowed; afterwards I return to this repository's work surface and do not quietly widen the scope.
