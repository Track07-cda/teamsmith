# E1 · Explore: the spec backfill (`spec-backfill-m6-m8`)

```
task:   E1
agent:  dev2
phase:  explore
deps:   v1.27.0
```

> This is the **explore** phase of the OpenSpec pipeline described in `skills/teamsmith/references/openspec.md`
> (§1 phase 1). Its only output is an **exploration report** for the PM to accept or reject. It does **not** create a
> change, does not touch specs, and does not touch code — those are later phases with different owners.

## The question to explore

`openspec/specs/` carries 8 capabilities (45 requirements, 77 scenarios) written in M5.2, at a moment when the tool
was at v1.19.0. Since then three batches landed **without** updating the specs:

- **M6** — the 29 findings from the V4.0 adversarial verification (state honesty, review-evidence integrity, proven
  liveness, dispatch/notify/boundary fixes, digest/version/meeting);
- **M7** — the migration guide, the watchdog `starting` state, the English-only doc invariant as a test, the
  test-isolation rule;
- **M8** — the PM-side adapter (`TEAM_PM_CMD` and friends) and the worker-side bare-name resolution plus launch
  evidence.

Nobody has ever run a change through OpenSpec in this repository (`openspec list` → no changes, archive empty), so we
also do not know whether the change workflow itself works in practice.

**Explore how to close that gap**, not the closing itself.

## Deliverable — one report, `docs/team/reports/E1-dev2.md`

1. **Inventory of gaps** (a table). For each behavior that changed in M6/M7/M8 and is *not* reflected in a spec:
   - the behavior in one line;
   - where it lives now (code path + a commit or tag; cite the evidence you actually looked at);
   - which capability spec should carry it (`dispatch`, `verification`, `board-and-status`, `watchdog`,
     `notify-and-inbox`, `meeting`, `memory-and-deps`, `boundary` — or a new capability, say which and why);
   - whether it can be expressed as a **falsifiable** scenario (a command whose failure is observable) or whether it
     belongs in `references/` prose instead — for the latter, say why it cannot be made observable.
   Start from the code/docs side (grep for the keys, states, files and commands that M6–M8 introduced) and check each
   against the specs; do not assume a spec already covers it.
2. **Options** for how to split the work, with the trade-offs: e.g. one big change for everything; one change per
   capability; one change per batch (M6/M7/M8); or only the highest-value subset. For each option: scope, number and
   size of tasks, what the verification phase would have to check, and what could go wrong (specs turning into
   unverifiable boilerplate, duplicating `references/`, or a scenario that cannot fail).
3. **A recommendation** with the reasoning, and the task split you would use if the PM accepts it (phase per task,
   suggested owner, dependencies).
4. **Risks and unknowns**, including anything you could not determine (say so plainly rather than guessing).
5. **Explicitly out of scope for this report**: creating `openspec/changes/**`, editing specs, writing code.

## Boundaries

- You may read everything. You may write **only** `docs/team/reports/E1-dev2.md` (plus the thread if you need to ask
  the PM something). Do not modify specs, code, templates or the ledger.
- Do not dispatch anyone. Do not open a change.

## Acceptance

```sh
openspec list --specs                       # paste the output you based the inventory on
openspec list                               # confirm: still no changes (this phase creates none)
git status --porcelain                      # only your report file appears
```

Paste the commands you used to establish each gap (the grep / `git log` lines), not just conclusions.
