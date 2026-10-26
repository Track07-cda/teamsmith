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
- [ ] Frozen final-tip full gate in the pinned container: **not yet run**.
- [ ] Performance reference run in the pinned container: **not yet run**.
- [ ] `docs/team/tools/release-check.sh`: **not yet run on the final candidate**.
- [ ] `docs/team/tools/release-check.sh --self-test`: **4/4 already reproduced before version preparation; rerun on final candidate**.
- [ ] Public `main` and `v0.3.4` pushed only after the above is green and the user explicitly authorizes the push.
- [ ] npm staged publish approved by the user, then real installation from the registry verified (CLI, four signal entries, skills and `/team` extension).

No tag, public push or npm publish has been performed for 0.3.4.
