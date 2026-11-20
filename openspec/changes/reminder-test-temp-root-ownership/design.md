## Scope

Keep **A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed** in the base
verification spec. Reuse `tmp_root_create`, `team_tmp_root_note`, the existing PID record and
`tmp_root_reap_all`. No change to the helper, smoke, or Reminder product. Below, `W` is the managed
work root and `E` is the real-Pi scene output path.

| Apply file under `skills/teamsmith/tests/` | Necessary change |
|---|---|
| `remind-tool-real.sh` | Own the real-Pi run instead of replacing the shell with Node. Expose the same run function to the adversarial shell. |
| `remind-adversarial-real.sh` | Use that function with the current leading `--select=adversarial,death`; keep its existing fingerprint around the driver. Stop creating a separate default evidence directory. |
| `remind-tool-real.mjs` | Use the handed-in paths, remove its competing directory creation/reaping, and route direct calls to the same owner before fixture setup. Keep its normal Pi/server shutdown. |
| `remind-adversarial-faults.sh` | Own the fault run and its existing fingerprint comparison; retain the nonempty `P444_KEEP` behavior. |
| `remind-adversarial-faults.mjs` | Use the handed-in work root for the existing private files. Route direct calls to the same owner **without** the shell-only fingerprint. |

`remind-recovery-real.sh:5` already executes the real-Pi Node driver with the leading
`--select=recovery,withdrawal` and original arguments. Its path therefore changes at the driver, with no
edit to the entry. The drivers' one internal handoff passes cwd, environment, stdio, the running Node
executable and the argument array unchanged. It does not add a public option or parse selectors again:
the driver's first `--select=` wins. A direct Node forwarder returns the owning child's status and forwards
INT/TERM addressed to it only to that child.

The two §69 shell entries take their existing snapshots inside `W`, compare against the same source,
and remove the snapshots after comparison. A disallowed change still forces rc 1; otherwise keep the
driver result and print `isolation=ok` only on rc 0. Direct CLI calls have no additional comparison.

## Work and evidence

| Caller request | Result |
|---|---|
| No nonempty `P442_EVIDENCE` | Scene files and private work share `W`. Nonempty `P442_KEEP` uses the helper's existing keep option and reports the paths kept. Empty evidence means unspecified, consistent with the adversarial shell. |
| Named `P442_EVIDENCE`, no `P442_KEEP` | Leave the written scene files under the named `E` (relative to invoking cwd if relative), including failure or interruption. The private work is in `W`, not an `E/run-*` that survives. |
| Named `P442_EVIDENCE` and nonempty `P442_KEEP` | Leave `E/<scene>` and report the existing `E/run-*` child with its private project files. `W` is only wrapper scratch in this case; do not turn inherited keep into a second retained root. |
| Fault driver | Use `W` for work and fault records; it does not read `P442_EVIDENCE` for placement. Nonempty `P444_KEEP` uses the helper's keep option and keeps the existing `kept fault evidence=` line. |

Both keep variables still use nonempty-string semantics, including the string `0`. P459 and V176 rely on
the kept scene/project paths and so those paths do not move. Smoke already names `$TMP/p442`,
`$TMP/p443` and `$TMP/p444`, all with `P442_KEEP=1`. The inner owner never removes these directories;
smoke's existing cleanup or `--keep` still decides their lifetime. The fault invocation has no such
explicit evidence directory.

## Exact private socket

Retain the absolute `<work>/socket` where it fits. Count bytes with `LC_ALL=C` for the 107-byte check itself
and for the fallback helper: `LC_ALL=C TMP_ROOT_SOCKET_FALLBACK=/var/tmp tmp_root_socket_dir tmux s`.
The helper takes the relative file name `s`, returns a unique directory, and the socket is exactly
`<returned-dir>/s`. If no private path fits, fail setup rather than use a default/shared socket. Resolve
tmux in the driver's existing Pi-directory PATH and use that same resolution for setup, the launch
identity and cleanup. Pass the one selected absolute path with `-S`; observe it with `#{socket_path}`.
After the private server stops, remove only the exact helper-created directory, even if work is kept.

## Finish the active command before reaping work

Start the driver as the owner's tracked child and wait for it. On INT/TERM to the owner, route once to
the ordinary exit cleanup, not to the helper's direct INT reaper. The owner requests graceful stop of
only its recorded driver and waits for it to exit **before** the helper can signal or remove anything.
Do not use the helper's timed forced-kill phase to interrupt the driver while it may have an active command.

Install each driver's local signal callbacks before fixture work; they record the stop request. Keep
`spawnSync` synchronous, but after a synchronous command returns, on success or failure, yield to an
actual event-loop turn (an awaited `setImmediate`, not an already settled Promise) and check the request
before the next write, command, or ordinary summary/exit. In the fault case this includes the boundary
immediately after `remind-tick`, before preparing or launching the injected helper. On a stop request,
leave through the driver's interruption path (INT 130, TERM 143), not the ordinary per-case catch or
summary. Do not call `process.exit()` before the yield. While the active command is still running, the
owner keeps waiting; time elapsed or signal delivery is not proof that the work is safe to delete.

Once the driver exits, close only the real-Pi server at the recorded private socket while it is still
addressable, then call the existing reaper, as in the ordering of `remind-pulse.sh`. The fault run needs
no server step. Regular child/compare results stay unchanged; interrupted runs exit nonzero and make
no successful comparison claim. No process-group signals, scanning, generic supervisor, KILL recovery,
or historical cleanup.
