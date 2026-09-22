# ledger-and-gate-noise · proposal

## Why

Three measured defects make the ledger and the correctness gate report a state the project is not in; each red
side already exists in this tree.

1. **The self-test's host fingerprint counts transient clients** (D34): its only red was `M28 容器自检`
   (`前 2dc577da… ≠ 后 9c2754d9…`) while a rerun exited 0 with a third value `3b1f7842…`.
   `host_tmux_fingerprint()` (`tests/container-tmux.sh:102`) folds a whole `ps` sweep into the hash, so a
   teammate's `team status` paints a green isolation proof red.
2. **It never looks at agent worktrees** (M31 + P36): `team_untracked_records()` (`scripts/lib/cmd-status.sh:497`)
   scans only the main checkout, so an untracked record inside `.worktrees/dev` is invisible to digest [4] —
   exactly the bytes a squash merge drops (P36's package survived by a manual re-commit).
3. **`team config list --json` emits illegal JSON for an empty seat override** (M74 finding, pre-existing): with
   `TEAM_AGENT_MODELS="dev="` the read emits `…"override":},…]` — the empty model shifts the tab-parsed columns,
   `"配置"` pollutes `models.known`, the parse fails, and `team ps` shows `0·配置`.

## What Changes

- **ADDED — `verification`**: the fingerprint becomes stable per-socket host state — no transient client can
  move it, a server's death still must. `container-tmux.sh` gains `--fingerprint`/`--fingerprint-check`; smoke
  §31c runs the two-sided fixture (full gate) beside a FAST-visible structural pin.
- **MODIFIED — `board-and-status`**: the reminder scans the main checkout and every worktree under the worktrees
  directory, names each untracked record as `<agent>: <path>`, keeps the records-path filter (a dirty non-record
  file stays silent), stays reminder-only, and the counting fixture gains a worktree-side record while the ≤50
  git-call budget still holds.
- **MODIFIED — `memory-and-deps`**: a seat row is read field-safely; `override` is always a JSON boolean; `dev=`
  is a present override whose model falls back to `TEAM_DEFAULT_MODEL` — the value `team ps`, the read and the
  dispatch renderer share — and no label leaks into `known`.
- **ADDED — `memory-and-deps`**: every JSON exit parses under a real parser, and a field with no value is `""`,
  never valueless and never `null`.

## Capabilities

Modified `board-and-status`, `memory-and-deps`; added `verification`.

## Impact

`tests/{container-tmux,smoke,config-cli}.sh`; `scripts/lib/{cmd-status,cmd-config,common}.sh` (PM-owned — the
apply brief must grant them). Out of scope: the writer, M31's staged/modified findings, the pulse's pending
definition, the lint, the panel.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/config-cli.sh list models seats json
bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## What flips

- **Fingerprint**: a client storm moves the hash today (`1477ba9e…` → `a55a6516…`) and leaves it byte-identical
  after the fix; killing an in-scope server still changes it.
- **Ledger**: today a worktree-side review record is unnamed; after the fix `dev: docs/team/reviews/…` and a
  package file are named while `junk.txt` stays silent.
- **JSON**: today `python3 -m json.tool` fails at byte 35532 on `"dev="`; after the fix every JSON exit parses and
  `team ps` shows the default model.

## Evidence the report must carry

Real commands and tails: both fingerprint directions, digest [4] before/after, the git-call count cache-on/off,
the JSON parse walk on the empty-override contract, `team ps`/`dispatch --print`'s seat line, the gate tails, and
each defect's break-it line.
