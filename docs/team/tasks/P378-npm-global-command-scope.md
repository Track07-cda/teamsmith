# P378 · Keep signal-gate shims inside Teamsmith sessions, not the user's global PATH

task: P378
agent: dev-bob
phase: apply
category: code
change: -
specs: init-skill#The CLI ships as one npm bin entry and the package carries what it runs
anchor: none (infra) — restores the existing one-bin requirement; no new spec delta
deltas: -
branch: task/P378-npm-global-command-scope

## Reproduced defect

The current 0.3.4 candidate lists `pkill`, `killall`, `pgrep`, `pidof` in `package.json.bin`. An isolated `npm i -g --prefix …` therefore creates those four entries in `prefix/bin`. With that directory first in PATH, an ordinary terminal's `pgrep -f npm034-outside` enters Teamsmith's signal gate and exits 64. This affects shells outside Teamsmith and is a release-blocking external side effect.

The correct boundary already exists: `team_tmux_shim_exports` injects the shim directory into PM and worker launch commands. Global `bin` entries are not needed for the gate to work inside managed sessions.

## Required change

1. Remove the four signal names from `package.json.bin`; keep `team` only.
2. Keep all four shim files in the published tarball and installed package. Do not remove or weaken the signal gate itself.
3. Update the installation-shape assertions so they verify the actual contract rather than the old global-bin assumption:
   - after a real `npm pack` + global install into an isolated prefix, `prefix/bin` contains `team` and does **not** contain `pkill`, `killall`, `pgrep`, `pidof`;
   - the four shim files still exist inside the installed package;
   - with that `prefix/bin` first in PATH, ordinary `pgrep`/`pkill` resolution remains the system executable, not Teamsmith's shim;
   - the existing PM/worker shim export path still resolves those names to the package's shim when evaluated in a managed-session environment.
4. Update any comments/docs that describe the four names as required global bin entries. Add a short 0.3.4 CHANGELOG note explaining that npm no longer shadows those commands globally; the gate remains active inside PM/worker sessions.

## Acceptance evidence

1. Before/after isolated-install comparison: the old candidate creates five entries; the repaired package creates only `team`, while all four shim files remain in the package.
2. Ordinary-shell resolution check with the isolated prefix first in PATH.
3. Managed-session shim export check proving the four names resolve to the package shim after `team_tmux_shim_exports` is applied. Use a private environment; do not alter the real team session or the user's global npm installation.
4. Run `bash skills/teamsmith/tests/install-shape.sh` and only the smoke sections affected by `package.json` and the changed assertions. Include a negative control: restoring the four `bin` entries makes the new no-global-shadowing assertion fail.
5. `bash -n`, `section-select.sh --check`, ledger ban and `git diff --check`. No full suite.

Report `docs/team/reports/P378-dev-bob.md` with exact commands and output. Do not merge, push, tag or publish. Independent verification follows separately.
