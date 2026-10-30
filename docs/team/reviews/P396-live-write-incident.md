# P396 · unexpected main-checkout writes during the full gate

time: 2026-10-30T06:53Z · owner: pm · status: CONTAINED / origin under investigation

## Answer and next step

Main-checkout files were unexpectedly rewritten while P396-full-smoke was running. PM stopped that one job through the existing PID/starttime-checked `team bg stop P396-full-smoke`; receipt: `signal=TERM target=group 4140082 result=stopped`, and `ps -p 4140082` returned no row. This interrupted full run is not PASS. The writer has not yet been identified; do not attribute it to P396 product code or a particular fixture without evidence. Dev has a read-only incident investigation instruction. No cleanup or restoration is authorized or performed.

P397 is a separate planning-only task in dev2's worktree, with no smoke/full-gate permission. It may continue without waiting for incident recovery. Any future shared-file implementation remains serialized.

## Observed evidence

- At the earlier status check main had only the pre-existing untracked `.cortexkit/`. After dispatch, `git status` additionally showed modified `AGENTS.md`, `.gitignore`, BOARD (expected dispatch todo→wip), and untracked `docs/team/PROTOCOL.md`, `docs/team/reviews/P395-done.md` (expected phase-closing receipt).
- `AGENTS.md`, `.gitignore`, and `docs/team/PROTOCOL.md` mtimes are 2026-10-30 06:51:08Z. AGENTS now says session `pm-skills`, roster `dev verify`, and omits the prior project-specific discipline block. The incident diff is 53 changed AGENTS lines and two added .gitignore lines. This is observation, not evidence of who called init.
- `.pi/team/config.sh` mtime remained 2026-10-29 06:46:10Z. No claim is made yet about all ignored files or live-state effects.
- The gate had progressed from 61b into section 62 at 06:48:20Z; its parent log remained there at detection. The first instruction to dev mistakenly referred to boundary as still current; PM immediately corrected that in a second instruction. No diagnosis depends on that mistaken phase attribution.
- Dev's tracked tree remained clean at `338a9f85` at the PM check. Shared main writes must not be hidden by a clean dev-tree fingerprint.

## Preserved scene

Snapshot: `/var/tmp/p396-unexpected-main-write.t8u4u3/`, created after stopping the job. It holds copies of the three observed files, `main.diff`, `status.txt`, and `SHA256SUMS`. Raw gate evidence stays at `$HOME/.cache/P396/full-gate/`; job record/log at `.pi/team/state/bg/P396-full-smoke.{job,log}`. Do not delete or alter originals while locating the writer.

## Follow-up: writer path narrowed, caller not proven (2026-10-30T07:02Z)

Dev's report at `188e8d41` and `$HOME/.cache/P396/incident-0651/` identify the file-set as matching main's init path. PM independently read `cmd-project.sh:125–310` and `cmd-bootstrap.sh:303–311`: existing-config bootstrap skips the AGENTS/document writer, whereas init rewrites AGENTS and installs these skills. PM also ran `diff -rq skills/teamsmith .pi/skills/teamsmith` (rc=0); dev's skill tree differs, including its new capture extension. This supports main-source init behavior and weakens the running dev fixture as the explanation. It does not capture the actual command, argv, caller or inherited environment, and does not absolutely exclude an indirect invocation. `dev verify` is compatible with default arguments or explicit identical values; omission of --agents is not proven. PM asked dev to narrow its stronger claims and stop broad session scans.

The observed write set also includes local skill/extension installation, inbox/review ignore files and report/review keep files; preserve the full timestamp manifest in `incident-0651/state.txt`. No contents of credentials were read. The absolute credential-file path appended to .gitignore is a separate init rendering issue, not evidence of token disclosure. Replacing the managed AGENTS block is the existing contract and already tracked by P389/P391; classify the lost in-block project rules as the known adoption risk, not a newly discovered change in semantics.

No recovery/restart has been performed. The earlier suspicion of fixture root escape is not established and must not be reported as the cause. Next: bound the evidence to an unknown init-compatible writer, present the minimal recovery diff and obtain authorization before any restore/delete. Do not restart the full gate, run live init/bootstrap/reload, or commit the unexpected file changes.
