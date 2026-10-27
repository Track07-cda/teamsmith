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

1. **npm global command pollution — fixed and independently verified.** `P378` removed the four signal names from global `bin`; `V108` independently proved the ordinary shell now uses system commands while managed PM/worker exports still resolve to the package shims. Upgrade from the old five-bin package removes the old links. Merged as `86278477`.
2. **One flip-arm failure in the frozen full gate — fixed and independently verified.** `P377` showed that the mutant scratch is not an installable skill source, so bootstrap still failed for an unrelated reason and the old named refusal assertion could not fire. The flip now targets the refusal-route outputs and the `--print` return-code path. `V107` reproduced the mutant and both controls, PASS. Merged as `d5843fbc`.

## Final candidate and proposed acceptance

Final main candidate: **`51a6a36a`**, version **0.3.4**, working tree clean.

- `openspec validate --all --strict`: **19 passed / 0 failed**.
- `spec-refs --check`: **121 judged, 0 undeclared**.
- `section-select.sh --check`: **12 ok / 0 bad**.
- `section-guard.sh --loop-check`: **all green**.
- `ledger-ban`: **0 hits**.
- Final affected smoke selection on merged main (`--select 11f,39`): **83 passed / 0 failed / 0 skips**, 7 sections closed, rc=0, 185.8s.
- Final `release-check.sh`: **28 passed / 2 failed / 0 skipped**; the two failures are only that `v0.3.4` has not yet been created and HEAD is ahead of `v0.3.3`. Version, public-face scan, ledger ban and all three installation routes pass.
- Final `release-check.sh --self-test`: **A 4/4, B 4/4**.

The full frozen-container run on `d8a21c03` remains the baseline: **5058 passed / 1 failed** over 134 sections. Since then the only product/test changes are `P377` (one flip case) and `P378` (package bin plus installation assertions), each independently verified, plus the final affected selection above. I propose using the **baseline full run + independent targeted verification + final affected selection** as the composite acceptance evidence instead of spending another four hours on an unchanged full suite. This requires the user's explicit acceptance before tagging and pushing.

## Release execution

The user accepted the composite acceptance route and authorized release on 2026-10-27: the baseline full run, independent targeted verification for every later fix, and the final affected selection.

Before pushing, the release commit on `main` must not carry `[skip ci]`: this push contains earlier product commits, and GitHub evaluates only the tip message for skip behavior. This record is therefore the intentional non-skipping release commit; the `v0.3.4` tag is moved to it after the final check.

Final pre-push checks on the tagged release commit:

- `release-check.sh`: **30 passed / 0 failed / 0 skipped**;
- `release-check.sh --self-test`: **A 4/4, B 4/4**;
- product/test/package paths are byte-identical to the independently reviewed candidate `51a6a36a`; later commits are documentation and the P379 read-only exploration brief only.

No npm publish has been performed yet. Public `main` and the single `v0.3.4` tag are pushed only after these checks; npm uses a staged publish and the user's web 2FA approval.
