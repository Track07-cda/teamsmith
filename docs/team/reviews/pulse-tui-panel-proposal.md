# pulse-tui-panel · PM proposal review

```
change:  pulse-tui-panel   phase:  propose   task: P9 (agent: dev2)
reviewer: pm               verdict: **ACCEPTED**
```

## Commands run (real output)

```console
$ openspec validate --all --strict
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 10 spec file(s), 59 requirement(s), 114 scenario(s) under openspec
  (8 base + 2 delta files; 45+14 requirements; 77+37 scenarios — arithmetic consistent)
$ # scratch copy:
$ openspec archive -y pulse-tui-panel
  Totals: + 13, ~ 1, - 0, → 0 — Specs updated successfully.
```

## Findings, one line per checklist item

1. **Matches the accepted exploration (D24)** — Ink+TSX new front end, `monitor.mjs --json` contract untouched as the
   data layer, committed single-file bundle ("The panel ships as one committed bundle with no install step",
   rebuild-reproducible), no re-opened decisions.
2. **Observable** — 33 scenarios over 12 requirements in the new `panel` capability; `--print`/non-TTY stays
   machine-readable (37 references to the print contract); sanitization is spec'd (5 places); the single-file bundle
   has its own requirement; `TEAM_REQUIRE_JS=0` is the escape hatch in both delta files.
3. **Coverage** — tasks ordered; D20's held-count field included; D19's degradation half (Node/Bun required, doctor
   fails, version floor) is the memory-and-deps ADDED + MODIFIED.
4. **Boundaries** — today's names are used (`rename-watchdog-to-pulse` is not implemented; the design says why and
   how it composes); the rename change's scope does not reach this one; the second-step visualization stays out.
5. **Acceptance** — verbatim commands + my own scratch archive (above): exactly the promised +13/~1/−0.
6. **Flip** — a rewrite, not a defect fix; the fixtures are the rendering/alignment/safety probes from E4 plus the
   bundle-runs-in-a-clean-container scenario.
7. **No spec conflicts** — MODIFIED "Tool resolution is visible" restates its base scenario and adds one (verified:
   1→2, zero drops); ADDED "A JS runtime is a required dependency" is a new name. *(Reviewer's own probe note: my
   first pass misread the delta as ADD+MODIFY on the same name — that was my regex slurping across the section
   boundary, not a defect in the change; verified against the raw file and the successful archive.)*
8. **Granularity** — one apply cycle (P10), sized as one front-end layer over an untouched data layer.

## Conditions binding the apply task (P10)

- Sequencing: **P6 (deferred delivery) first, then P8 (the rename), then P10** — the panel then lands on final names
  and reads a shipped outbox.
- The bundle must be **regenerated reproducibly** and the build command must appear in CI-equivalent smoke (the
  scenario's promise); a hand-edited bundle is a defect.
- The `--json` contract's ~25 existing smoke assertions must pass unchanged.

## Next phase

Apply: **P10**, agent **dev**, after P8 merges.
