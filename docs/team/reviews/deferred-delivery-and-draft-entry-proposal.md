# deferred-delivery-and-draft-entry · PM proposal review

```
change:  deferred-delivery-and-draft-entry   phase:  propose   task: P5 (agent: dev2)
reviewer: pm                               verdict: **ACCEPTED**
```

## Commands run (real output, not a promise)

```console
$ openspec validate --all --strict
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 11 spec file(s), 57 requirement(s), 112 scenario(s) under openspec
  (8 base + 3 delta files; 45+12 requirements; 77+35 scenarios — arithmetic checks out)
$ # scratch copy, then:
$ openspec archive -y deferred-delivery-and-draft-entry
  Applying changes to openspec/specs/watchdog/spec.md: ~ 1 modified   (…)
  Totals: + 9, ~ 3, - 0 — Specs updated successfully.
$ ls openspec/specs/ | grep delivery
  delivery-guard                                              # the new capability is created by archive
```

## Findings, one line per checklist item

1. **Matches the approved exploration (D21, option B)** — guard + outbox + drain + draft entry, queue format as the
   interface, C deferred. The proposal's Why quotes D20 verbatim.
2. **Observable** — 35 scenarios, all with commands/observable state; the known detector hole (**whitespace-only
   draft**) is written into the spec twice (the limitation note and a dedicated scenario "is the documented …") —
   the honest treatment D21 required, not a silent wrong.
3. **Coverage closed** — tasks §0–§7 map to every requirement; the flip fixture is task 0.1 (defect-fix evidence
   first: reproduce the glue on a fixture pane, then the guard turns it green).
4. **Boundaries explicit** — which paths defer (`say`/`notify`/nudge/extension) and which don't (human's own
   `say --now`), UNKNOWN-pane policy stated (deliver as today, one warning line, no queue entry).
5. **Acceptance commands** — verbatim, plus the scratch archive probe I re-ran myself (result above).
6. **Flip** — the glued-draft reproduction is the red, the guarded delivery the green; the verify attack list (E3
   §5.4) is carried into the scenarios.
7. **No conflict with existing specs** — the three MODIFIED deltas restate every base scenario with zero drops
   (verified against base: watchdog 2→3, notify-and-inbox 1→2 and 2→3, all additive); the new capability does not
   collide with any existing requirement name.
8. **Granularity** — one apply brief; tasks ordered (flip → guard → queue → drain → rewiring → draft entry →
   tests/isolation → evidence); the **isolation item (7.2) is explicit** (sandbox repo, `env -u TEAM_*`, `team paths`
   assertion, before/after hashes of the real inbox/state — the M7.2 lesson).

## Conditions binding the apply task (P6)

- **Ordering**: C1's apply (P4) goes first (it was accepted first; both touch `tests/smoke.sh`, so serialization
  avoids an avoidable rebase). P6 dispatches to `dev` after P4 merges.
- The guard function and drain must land as the single functions the design names (no partial rewrites of the send
  paths), and the extension's enqueue must carry its dedup key into the queue entry (E3 §4.3).
- `TEAM_DEFER_TTL` default 300s is accepted as proposed; the hold/escape behaviour (inbox line + `HOLDING.log`,
  never typed) is part of the spec, not an option.

## Next phase

Apply (phase 3): task **P6**, agent **dev**, after P4 merges. Verify: an independent `verify` agent with E3 §5.4's
seven attack surfaces as its charge.
