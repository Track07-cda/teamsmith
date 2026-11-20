## 1. Apply after proposal acceptance

- [ ] 1.1 Implement the shared real-Pi lifetime in its normal shell, adversarial shell and driver. Keep
  both existing evidence layouts, the existing arguments, and the private socket. Covers caller evidence
  and default scene output. Do not edit the recovery wrapper or smoke.
- [ ] 1.2 Implement the managed fault lifetime in its shell and driver. Keep explicit fault records and
  each entry's existing result. Both lifetimes must finish the active command before reaping work.

## 2. Independent check on one fixed Apply revision

Use a private checkout and a new `/var/tmp` validation directory with distinct existing `TMPDIR` and
`TEAM_TMP_ROOT`. Clear inherited keep/evidence except as named. Record each actual work path while it
exists or from the keep output, stdout/stderr and rc. Use only the existing private Pi/loopback
provider; do not inspect or stop the team's live panes.

- [ ] 2.1 **Default success:** `node skills/teamsmith/tests/remind-tool-real.mjs --select=large`. Require the
  named `64 KiB plus final newline` PASS, `passed=1 failed=0`, rc 0 and real scene files under the managed
  root in `TMPDIR`, no separate default evidence, and the recorded root gone after exit.
- [ ] 2.2 **Same fault case, two completed results:** In a private copy narrow only the case list to
  `remind-intent / after-rename`. For direct `node skills/teamsmith/tests/remind-adversarial-faults.mjs`
  with `P444_KEEP=1` and an unrelated named `P442_EVIDENCE`, make the existing expected restart assertion
  fail *after* the real injected death. Require the named failure and assertion, `passed=0 failed=1`,
  rc 1, the retained `fault-mark.txt` with `after-rename` and `last-authority.txt` in the printed work
  directory, and no placement under the unrelated path. Restore just that assertion; run the same case
  via `bash skills/teamsmith/tests/remind-adversarial-faults.sh` without keep. Require the named PASS,
  `passed=1 failed=0`, rc 0, `isolation=ok`, and the recorded work directory gone.
- [ ] 2.3 **One real-Pi TERM, also the socket check:** Start `large` via the direct Node entry with named
  `P442_EVIDENCE` and no keep; hold its first controlled response in the private copy. Make the ordinary
  candidate exceed 107 **bytes** under a smoke-shaped base. Size a multibyte component so the helper's first
  `<base>/.t-<uid>.XXXXXX/s` candidate would also exceed 107 bytes while fitting by character count;
  don't assume stock CI exceeds the limit. Expect the actual short directory under `/var/tmp`. Wait for a real scene record and live
  pane. With `tmux -S <selected-path> display-message -p '#{socket_path}'` confirm the actual private short
  path, and record driver/server/pane identity. Send TERM to the invocation PID only. Require nonzero
  exit, work and that private server/pane/short socket directory gone, and the original scene record
  still at `E`. A separately started unrelated private session remains alive.
- [ ] 2.4 **One fault TERM during a known command:** On the same isolated fault scenario, hold only its
  actual synchronous `remind-tick` child in a private copy before the real due-admission write. Have the
  child record arrival and wait for a test-controlled release. Send TERM to the fault shell PID after
  arrival (without keep). In the private copy, observe the owner forwarding the stop request before
  releasing the child. In the same external receipt stream, require proof that the real child completed
  the admission write before cleanup, then that the driver took its TERM interruption path and exited,
  without entering the following injection step or printing its ordinary summary. Observe the driver's
  stop branch and mark injection entry in the private copy, not merely the eventual fault-mark (which
  may disappear with the root). Require the recorded child and driver gone, the entry nonzero, and
  the recorded root gone. The owner's nonzero result alone is insufficient. No additional sample.
- [ ] 2.5 **One short entry/evidence method:** Use the changed adversarial real-Pi shell only. In a
  private copy, after its actual argv/path handoff, replace just the business body with a named receipt
  writing one scene file and one project-state file to the paths actually supplied. Place it before
  starting the provider/Pi so it creates no live resources. Confirm the current
  first selector `adversarial,death`. With a smoke-shaped `E` and `P442_KEEP=1`, require rc 0,
  `isolation=ok`, and both actual files at `E/<scene>` and the reported `E/run-*/<scene>/.pi/team/state`.
  Repeat that same receipt with no keep and a named nonzero result: scene file remains, recorded work
  is gone, original rc is preserved and no success comparison line is printed. Use the existing source
  comparison for all three outer smoke paths, the unchanged recovery entry, plain argv passthrough,
  and the mapping of default keep to shared keep; do not rerun those entry shapes. A receipt is not a
  business PASS, and a selection that runs zero scenes proves neither behavior nor cleanup.

No full smoke, repeated business matrix, installed product, live reminder or external model checks.
Proposal author runs none of these samples.
