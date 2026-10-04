# Contributing to teamsmith

Thanks for looking. teamsmith gives one agent real ownership of a project: it plans, writes
task briefs, dispatches worker agents into their own tmux windows and git worktrees, verifies
their work on an independent checkout, merges, and keeps an auditable ledger.

## Getting set up

```bash
npm install -g teamsmith          # puts `team` on your PATH
cd /path/to/your/project
team init                         # installs the skills into .pi/skills/ and writes the config
team bootstrap                    # config + docs skeleton + worktrees + pulse window
```

Pi is the only supported agent runtime. The skill detects the Pi version and the installed
plugin packages during `team init`; see `README.md` for the versions this release was tested
against.

## Running the gates

Everything the project promises is checked by the suite that ships with it:

```bash
openspec validate --all --strict          # the contract library
bash skills/teamsmith/tests/smoke.sh      # the full suite (long; it drives real tmux windows)
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh   # the fast subset
```

The suite is deliberately strict and it is the same suite CI runs. A change that reddens it is
not ready, and a test that cannot judge says so rather than passing.

## Changing the contract

Behaviour that the project promises lives in `openspec/specs/**` as requirements with
scenarios, and every change starts as a proposal under `openspec/changes/<id>/`:

1. **propose** — a proposal, a design note, tasks, and a delta against the spec it touches;
2. **apply** — the implementation plus the tests that make the delta falsifiable;
3. **verify** — someone other than the author re-derives the evidence on an independent checkout;
4. **archive** — the delta moves into the spec library.

`skills/teamsmith/references/openspec.md` describes the phases in full, and
`openspec/changes/archive/**` holds the reasoning behind every decision taken so far — that
record is part of the documentation on purpose, so a reader can see *why* a rule exists, not
just what it is.

## Sending a patch

Open an issue or a pull request. Because the maintainers' ledger (task briefs, verification
reports, decisions) lives outside this repository, an external patch is **ported** into their
working tree, credited with `Co-authored-by:` in the commit, and travels out with the next
release. Your commits will not appear as separate entries in this repository's history, and
that is the one cost of this arrangement — the credit is in the commit message.

## What the project asks of a change

- a claim is worth what its evidence is worth: prefer a check that can fail over a sentence
  that says it passes;
- guards fail closed: when a rule cannot be judged, say so visibly instead of reporting green;
- destructive operations name their target; nothing ever acts on "everything that matches";
- the gates are the contract's teeth — if a rule matters, there is a test that reddens when the
  rule is broken.
