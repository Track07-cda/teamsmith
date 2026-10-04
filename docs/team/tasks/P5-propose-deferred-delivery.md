# P5 · Propose: `deferred-delivery-and-draft-entry` (D20, option B)

```
task:   P5
agent:  dev2
phase:  propose
change: deferred-delivery-and-draft-entry
deps:   E3 (accepted: DECISIONS D21)
```

> Phase 2. You hold the context from E3; D21 records the acceptance (option B; C deferred). **Planning artifacts
> only** — no code, no `openspec/specs/**`. The PM reviews the artifacts before any apply task exists.

## What the change is

One change covering D20's two halves:

1. **The delivery guard + outbox**: every automated send path that today types into the PM's pane (`team say`,
   `team notify`'s pane delivery, the watchdog nudge, and the extension's `send-keys` at `team-notify.ts:343-344`)
   first checks the input region (E3's v2 detector; v3 upgrade when a baseline exists) and, when the box is
   non-empty, enqueues to `state/outbox/` instead of typing. Drain has three callers (bounded sender retry, watchdog
   tick, explicit `team outbox flush`); TTL with a documented escape (hold past `TEAM_DEFER_TTL` → inbox line +
   `HOLDING.log`, never typed). Queued sends return "queued" **before** the pane-fingerprint loop, and the
   fingerprint verification moves into the drain. `status`/`digest`/`ps` show the held count. The extension enqueues
   via the same command and carries its dedup key into the queue entry.
2. **The draft entry**: `team draft pm` opens `$EDITOR` on `state/draft-pm.md` in a dedicated `teamsmith:draft`
   window; on save the content is delivered through the guarded path (multi-line via `load-buffer` + `paste-buffer`,
   bracketed paste per E3 §3.2), with a visible acknowledgement.

## Binding conditions from D21

- The whitespace-only-draft detector hole must be **documented in the spec text and docs**, not silently wrong.
- The queue file format is the interface (so the future PM-side extension channel can plug in); guard = one function,
  drain = one function.
- Which paths defer and which don't is stated explicitly (a human's own `team say` gets `--now`).
- The delta spec: a new capability (name it — e.g. `delivery-guard`) with falsifiable scenarios (the verify attack
  list in E3 §5.4 is your scenario material: glue reproduction, detector edges, TTL/hold, dedup/ordering, no
  regression on clean-box `say --verify` and `TEAM_NOTIFY_TMUX=0`, race honesty re-check before Enter).
- tasks.md: ordered; the smoke-isolation requirement (M7.2 lesson: fixtures must not write the real inbox/state) is
  its own task item.

## Evidence for the PM review

- `openspec change show`, `openspec validate --all --strict`, `spec-lint.sh` (all green with the change present);
  a scratch `openspec archive -y` showing the promised operations apply.
- `docs/team/reports/P5-dev2.md`: requirement → scenario → falsifier mapping, what you left out (why), and the
  decisions the PM must take before apply.

## Boundaries

Only `openspec/changes/deferred-delivery-and-draft-entry/**` + your report. Never `openspec/specs/**`, no code, no
ledger. Do not dispatch, do not archive.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
git status --porcelain   # only the change dir + your report
```
