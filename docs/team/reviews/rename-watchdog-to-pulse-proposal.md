# rename-watchdog-to-pulse · PM proposal review

```
change:  rename-watchdog-to-pulse   phase:  propose   task: P7 (agent: dev2)
reviewer: pm                        verdict: **ACCEPTED**
```

## Commands run (real output, not a promise)

```console
$ openspec validate --all --strict
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 9 spec file(s), 55 requirement(s), 95 scenario(s) under openspec
$ # MODIFIED 一致性（我逐条与 base 比对）：
  · One backend, inside the team's tmux session      base=2 delta=2 丢失=无
  · Pending work is defined, and no work means no…   base=2 delta=2 丢失=无
  · Repeated reminders … rate limited                base=1 delta=1 丢失=无
  · Standby stops the wake-ups …                     base=1 delta=2 丢失=无
  · Restart quota and capacity logging               base=2 delta=2 丢失=无
  · (第六条走 RENAMED，见下)
$ # scratch 副本上：
$ openspec archive -y rename-watchdog-to-pulse
  Totals: + 4, ~ 6, - 0, → 1 renamed — Specs updated successfully.
```

The RENAMED delta is explicit (`FROM: The watchdog never manages tmux layout…` → `TO: The pulse never manages…`),
and archive applies exactly the promised `+4 / ~6 / →1`.

## Findings, one line per checklist item

1. **Matches D22** — the name is the user's pick (`pulse`); the change lands ahead of D19 so the TUI rewrite starts
   from the new names.
2. **Observable** — 18 scenarios over 10 requirements; alias behaviour, deprecation line, window name, legacy env
   vars, and the migration fixture are all command-level falsifiable.
3. **Coverage** — the inventory is grep-backed; tasks.md is ordered.
4. **Boundaries** — `TEAM_MONITOR_*` untouched, state file names kept during the alias period (two patrols cannot
   collide), the alias-drop change is a follow-up; capability name stays `watchdog` (strategy a), with the tested
   alternative (new capability + `retire_capabilities`) recorded in design.md and rejected for stated reasons.
5. **Acceptance commands** — verbatim; the archive probe above is my own run.
6. **Flip** — rename, not a defect fix; the migration fixture (old config + old-named window in a sandbox session)
   is the red/green.
7. **No spec conflicts** — five MODIFIED restate every base scenario (zero drops, verified); one RENAMED; four ADDED
   inside the same capability; nothing created or deleted.
8. **Granularity** — one apply cycle; the alias-drop is explicitly a separate later change.

## Conditions binding the apply task (P8)

- Sequencing: **P4 (C1 backfill) → P6 (D20 deferred delivery) → P8 (this rename)**. The rename then also covers
  D20's fresh surface, and D19 starts from the final names.
- The deprecation line and the alias behaviour must appear in the same release that introduces `pulse` (no release
  where the old name is gone without the alias).
- The alias period ends at v2.0.0 as proposed; the alias-drop change is its own pipeline cycle.

## Next phase

Apply: task **P8**, agent **dev** (after P6 merges).
