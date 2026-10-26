# Release 0.3.4 · review and evidence

Status: **prepared locally; not tagged, pushed or published yet**.

## Scope

Main user-facing changes since `v0.3.3`:

- notifications are recorded in the PM inbox independently of whether the wake succeeds;
- knock outcomes are persisted and surfaced by `team digest`;
- completion messages retain full text, previews carry explicit truncation and source locators, and `asks=` counts questions for the PM;
- PM-window creation failures no longer print a false success;
- unreadable `/proc/<pid>/environ` no longer leaks shell diagnostics into normal output;
- targeted gate and fixture corrections for lock patience, notification traffic, selection declarations and symlink-safe flip trees.

`P376` (PM-window creation truth) was independently verified by V106 before inclusion. The host sections previously reported red by V101 (`33`, `3b`, `6`) were rerun on current main before release preparation: **147 passed / 0 failed**.

## Release checklist

- [x] No active OpenSpec changes; all four completed changes archived (73 archives, 19 capabilities).
- [x] Version locations changed to 0.3.4: `package.json`, `common.sh`, both `SKILL.md` files, README tag pins.
- [x] CHANGELOG entry written.
- [x] Frozen full gate on `d8a21c03` in the pinned container ran to completion: **5058 passed / 1 failed**, 134 sections closed, 14363.7s. It is evidence, not a release pass. The only outer failure is `flip-init-legacy-proceeds-bootstrap` in §61b; `P377` is reproducing and classifying it.
- [ ] Final-candidate full gate or an explicitly accepted composite of the above baseline plus targeted independent verification for every later fix.
- [ ] Performance reference run in the pinned container: **not yet run**.
- [x] `docs/team/tools/release-check.sh` on `d8a21c03`: **28 pass / 2 fail / 0 skip**; both failures are only the then-missing `v0.3.4` tag/HEAD relationship. Rerun after the final tag.
- [x] `docs/team/tools/release-check.sh --self-test`: **A 4/4, B 4/4** on the prepared candidate.
- [ ] Public `main` and `v0.3.4` pushed only after the above is green and the user explicitly authorizes the push.
- [ ] npm staged publish approved by the user, then real installation from the registry verified (CLI, no global signal-command shadowing, shim files present, skills and `/team` extension).

## Release blockers found after preparation

1. **npm global command pollution.** The candidate's `package.json` still exposes four signal commands through npm's global `bin`. An isolated install followed by a PATH-prefixed ordinary `pgrep` reproduced Teamsmith's gate outside a team session (rc=64). The existing specification `init-skill#The CLI ships as one npm bin entry and the package carries what it runs` already requires exactly one `bin`; `P378` restores that boundary and keeps the shims inside PM/worker sessions.
2. **One flip-arm failure in the frozen full gate.** `P377` is reproducing only `init-legacy-proceeds-bootstrap` and reading its actual `bootstrap` output. The other four similarly named inner `FAIL` lines are expected by their flip checks and are not five separate product defects.

No tag, public push or npm publish has been performed for 0.3.4.
