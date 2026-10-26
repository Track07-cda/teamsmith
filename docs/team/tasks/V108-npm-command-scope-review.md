# V108 · Independent review of npm global command scope

task: V108
agent: dev
phase: verify
category: verify
change: -
specs: init-skill#The CLI ships as one npm bin entry and the package carries what it runs
anchor: none (infra) — independent verification of the one-bin/package boundary
deltas: -
branch: task/V108-npm-command-scope-review

## Candidate

`57ba99f3` on `task/P378-npm-global-command-scope` (product/package change `e79402a5`, assertions `792b789d`, changelog `ca774396`). Report: `docs/team/reports/P378-dev-bob.md`.

The candidate removes `pkill`, `killall`, `pgrep`, `pidof` from npm's global `bin`, keeps the shim files in the package, and relies on the existing `team_tmux_shim_exports` for PM/worker sessions.

## Required independent evidence

Use your own clean clone and isolated npm prefixes. Do not alter the user's global npm installation or the real team session.

1. Before/after real install: build the tarball from the old parent (`fd971b5a`) and from the candidate, install each into a separate private prefix. Old `prefix/bin` must show five entries; candidate must show only `team`, while all four shim files remain in the installed package.
2. Ordinary-shell check with the candidate prefix first in PATH: `pkill`, `killall`, `pgrep`, `pidof` resolve to the system executables, not to the package. Run the same `pgrep -f 'v108-mark[e]r'` on old and new paths: old enters Teamsmith's gate (rc=64), new uses system `pgrep` (no match, rc=1).
3. Managed-session export check: from the installed package, evaluate `team_tmux_shim_exports` in a private environment and prove all four names resolve back to the package's shim. Do not start or modify a real PM session.
4. Upgrade cleanup check: install the old five-bin package into a prefix, then install the candidate over it and confirm the old four links disappear.
5. Run `bash skills/teamsmith/tests/install-shape.sh` once and the affected smoke selection `bash skills/teamsmith/tests/smoke.sh --select 11f,39`. Include the negative control: restoring the four global `bin` entries makes the new no-shadowing assertion fail for the intended reason.
6. Inspect the diff: only `package.json`, `install-shape.sh` and the changelog change. No change to `team_tmux_shim_exports`, the signal-gate implementation or `smoke.sh` assertions. Run `bash -n`, `section-select.sh --check`, ledger ban and `git diff --check`. No full gate.

## Delivery

Write `docs/team/reports/V108-dev.md`, starting with PASS, PARTIAL or FAIL, and include exact commands/output tails. Do not modify the candidate, merge, push or publish.
