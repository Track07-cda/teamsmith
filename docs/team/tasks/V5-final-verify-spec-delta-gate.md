# V5 · Final verify: `spec-delta-gate` after P2.5 (walk roots + dot entries)

```
task:   V5
agent:  verify
phase:  verify
change: spec-delta-gate
deps:   V4 (round four), P2.5 (tip 43f5653 on task/P2.5-apply-rework-5-contain-walk-)
note:   this is the round whose result decides whether the change goes to the user for archive.
        The D17 exit criterion: **zero reachable disagreements** with `openspec archive`.
```

## Charge

1. **F-V4-A/B closure** with your own shapes: symlinked `changes/`, `changes/archive/`, base `specs/` roots;
   dot-named change dirs (bad content and legitimate content); through validate/gate/archive. (The PM's probes:
   root link → `delta-walk-root-escape` rc=1 with validate green; `.hidden/` checked by content; a leftover
   change-dir symlink from probe surgery was also caught live.)
2. **Attack the new surface**: the roots are now resolved once — nested symlinked roots (changes/ → dir → link),
   `changes` as a symlink to an in-repo dir (does archive accept it? the gate must agree), a dot-named *specs/*
   entry, `changes/.archive/`, case variants (`.Hidden` vs `.hidden`), and a change dir that is a symlink to a
   *file*.
3. **The whole net, final**: your V4 package (`pkg/run.sh` covers the restored nets) against `43f5653`; diff vs
   V4's tables. The line that matters: **reachable disagreements = N** and for any N>0 row, which arbiter sees it
   first.
4. **Unchanged claims**: contract/exit codes, `openspec/specs/**` untouched, `TEAM_GATES` unchanged, §16
   guard-not-theatre.
5. **Record**: `team review V5 --dir <checkout> --strong` on `43f5653` + `docs/team/reports/V5-verify.md`.

## Boundaries

Read-only on the delivered branch; scratch copies for probes; never `openspec/**`; do not push `main`.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
