## MODIFIED Requirements

### Requirement: A reload request is bookkeeping, not a restart

`team reload` SHALL write `state/reload-requested` as a request marker and MUST state what really makes the reload take effect (typing `/reload`, or `/teamsmith-reload`, in the Pi session, or the `reload_skills` tool) and that no component restarts a session because of the marker: the only reader is the Pi notification extension, which removes the marker after a reload. No script may read the marker as an instruction to restart anything. `team reload --done` SHALL clear the marker. Reload MUST NOT be described as adding a directed extension argument absent from the current process's original startup inputs. First adoption of a newly injected PM capture entry SHALL require an explicitly authorized restart through the existing PM lifecycle; when that entry is already loaded, reload MAY replace its runtime, with current-generation loaded-module evidence required before claiming the new code is active. Creating or clearing the request marker, refreshing skills or recording a disk version MUST NOT by itself prove that a capture handler is installed.

#### Scenario: The reload text matches the mechanism
- **WHEN** `team reload` runs
- **THEN** `state/reload-requested` exists and the output names `/reload` as the way to make it effective
- **AND** the output does not promise that the watchdog restarts the PM session, and says explicitly that no component restarts a session because of the marker
- **AND** a search of `scripts/` finds no file other than the reload command itself reading `reload-requested`

#### Scenario: `--done` clears the marker
- **GIVEN** a marker written by `team reload`
- **WHEN** `team reload --done` runs
- **THEN** `state/reload-requested` no longer exists

#### Scenario: Initial injection and replacement reload are different
- **WHEN** a private PM started without the capture entry reloads, and a separate private PM started with that entry reloads after its source changed
- **THEN** the first has no newly installed capture handler and must not be reported enabled, while the second can register a new owner generation and its actual loaded fingerprint
- **AND** neither case is an automatic live-team restart or proof obtained solely from a request marker

## ADDED Requirements

### Requirement: Key reply capture loads only into a positively identified PM

The built-in PM Pi launcher SHALL inject the directed key-reply extension once, retaining existing background/inbox extensions, selected model, continuity and spawn-proof rules. It MUST NOT inject it into workers or ordinary Pi discovery, register another slash command, duplicate `/team`, write shared tmux global identity or add adapter placeholders/configuration keys. Custom PM templates and non-Pi adapters SHALL not receive automatic rewriting or a claim of capture support.

Before capture activation, eligibility or writer execution, the extension SHALL verify the actual main worktree from runtime working directories, the resolved canonical config/state and their launch identity, actual tmux server/session/window/pane, and live PM process PID/starttime/cwd with matching spawn or existing run evidence. An inherited root, `from=pm`, a main-root cwd alone, stale launch record or existing window is insufficient. Foreign cwd MUST NOT fall back to inherited project root. Config/state symlink substitution, a changed identity, missing/nonpersistent session identity or insufficient evidence SHALL disable capture with an honest local diagnostic, without impairing the normal answer or changing another project. Existing explicitly resolved external state directories remain allowed only when fixed by the verified PM launch, not inferred from a foreign environment. Initial spawn evidence SHALL allow the real process that is starting before final pm.pid/launch metadata publication; stale final metadata MUST NOT authorize a different process.

Duplicate extension copies SHALL have one current owner/generation per runtime identity. Nonowners and stale callbacks MUST NOT stage, clean a second time, publish or overwrite a newer registration. Shared source serialization SHALL also hold across processes. Reload/shutdown/session replacement SHALL retire only their own generation and invalidate incomplete activities without deleting a newer owner's record. These rules MUST NOT widen the existing PM liveness vocabulary or mutate running/starting PMs merely to enable capture.

#### Scenario: The built-in PM gets one directed entry and workers get none
- **WHEN** built-in PM and worker launch arguments are previewed and exercised in a private project
- **THEN** only the PM receives one capture entry, existing extensions and lifecycle rules remain, and `/team` is registered no more than before
- **AND** custom templates are not rewritten, ordinary Pi discovery is unchanged and tmux global environment is byte-identical

#### Scenario: Inherited project identity cannot capture from a foreign process
- **WHEN** foreign cwd inherits this project's root/config/state, or an ordinary Pi/worker runs in an apparently plausible directory without valid pane/process/spawn evidence
- **THEN** no capture intent, runtime-ready claim or writer call is produced for that process, no foreign files/processes are changed and its answer remains available
- **AND** a genuine private PM with matching launch/pane/PID/starttime evidence can activate even before its final pm.pid record arrives

#### Scenario: Duplicate copies and stale generations do not duplicate capture
- **WHEN** two paths load copies in the same Pi and reload/session replacement races with an old callback
- **THEN** one current owner sanitizes and stages the message, and old callbacks cannot replace new runtime evidence or earn another writer attempt
- **AND** a dead/reused PID, wrong starttime/cwd/pane or changed config/state ceases to qualify as active capture evidence
