# Design: `notify-sender-identity` — the sender is the runtime directory, not the argument

## 1. The defect as measured

Probed on this tree in a throwaway `/tmp` project (`team init`, one `dev` worktree, `TEAM_NOTIFY_TMUX=0`):

```
$ cd <main>/.worktrees/dev && team notify pm --from-file <file>     # TEAM_AGENT unset
  - 2026-09-22T20:30:10Z [manual] agent:pm · P72 probe: worker summary      rc=0
$ cd <main> && team notify pm --from-file <file>                    # the PM itself
  - 2026-09-22T20:30:10Z [manual] agent:pm · P72 probe: worker summary      rc=0
$ cd <tmp>/elsewhere && team notify pm --from-file <file>           # a worktree outside .worktrees/
  - 2026-09-22T20:30:10Z [manual] agent:pm · P72 probe: worker summary      rc=0
```

Three different runtime contexts, one indistinguishable line. The code says why: `team_inbox_append` prints
`agent:$1` where `$1` is the **inbox file owner** (`cmd-agents.sh:1106`), and `team_cmd_notify` passes the
recipient as `$1`, as the knock text's `agent:`, and as `--from` (`:1141`, `:1148`, `:1160`). That `--from`
lands in the outbox entry header, is rendered by the watcher as `from <x>` in the wake, and is recorded in
`state/outbox/delivered.log` — so the wrong sender is not only on the durable line.

What is already right: the turn-end extension names the **sender** (`const agent = window || basename(cwd)`,
`extension/team-notify.ts:272`; `--from agent` at `:371`; the line at `:339` goes to `inbox/<agent>.md`).
For the same seat the two paths therefore contradict each other, which is the inconsistency the brief's item 3
names. The audit consequence is the brief's item 2: 55 `agent:pm` lines in the PM's inbox whose authors are
workers, contradicting `docs/team/reports/**`.

## 2. Signals and precedence (the trade-off the brief asks for)

| Signal | Present when | Authority | Why |
|---|---|---|---|
| Runtime directory | always; the CLI already resolves it (M40 lock) | **authoritative** | The user-decided M40 rule; the worktree path encodes the dispatch-time seat; works headless (adapter notify, scripts, smoke fixtures); not renamable |
| `--from <name>` | explicit | **authoritative claim** | The escape the brief names for a runtime directory that names no seat; recorded verbatim; a disagreement with the directory is named |
| `TEAM_AGENT` | only if someone exports it (dispatch/install never set it) | never overrides the directory; a disagreement is named | M40: an inherited `TEAM_*` must not silently win over cwd |
| tmux window name | inside tmux | corroboration only | Renamable UI state; absent headless; the extension's `window \|\|` preference is exactly what would mislabel a renamed window or a session started in a subdirectory |
| The recipient argument | always | **never** the sender | It is the addressee: the inbox file name and the knock target |

Decision: `--from` → runtime directory (main worktree = `pm`; a worktree under
`<main>/<TEAM_WORKTREES_DIR>/` = that worktree's directory name, subdirectories included) → otherwise
**refusal** (non-zero, nothing written, `--from` named). The window name never decides; a disagreement with
the directory is a warning (CLI stderr / the extension's log).

Rejected alternatives:

- **Window first (the brief's option 3).** The adapter notify command, scripted notifies and smoke fixtures run
  without a pane, so a window-first rule still needs the directory path; window names are UI state a human can
  change, while the worktree path is created by dispatch; and M40 already decided that the runtime directory,
  not ambient signals, is identity.
- **Keep `pm` as the fallback.** That is the defect: an unattributable claim the ledger cannot later
  distinguish from a real PM report (`references/philosophy.md`: a false green is worse than nothing).
  Refusal is recoverable — the caller states the sender with `--from`.
- **Always demand `--from` from workers.** The worker case is the common one and the directory already names
  the seat exactly; requiring the flag would make every adapter command and ad-hoc notify brittle for no gain.
- **Parse the pane/session name (`teamsmith:<agent>`).** The session name is project-scoped, not seat-scoped;
  the seat would come from the window part — the signal rejected above, with the same limitations.

## 3. Attribution surfaces

One resolved value appears in four records: the durable inbox line, the knock text, the outbox entry's
`from:` field (which the watcher renders as `from <x>` and `delivered.log` records), and the wake ledger.
`team_inbox_append` gains an optional sender so the notify path can pass it while `say`/`draft`/pulse keep
today's owner label — their tag already names the sender (`[pm]`, `[blocked]`, `[queued]` payloads carry the
sender text). The recipient stays observable as the file name (`docs/team/inbox/<recipient>.md`) and the knock
target, so nothing loses the addressee.

## 4. Cross-path agreement

The extension keeps its guards (cwd under the worktrees directory, not the PM window, session match) and its
write-before-knock order; only the agent derivation changes from `window || basename(cwd)` to the worktree
containing cwd (roster name preferred, so a nested path cannot mislabel), with the window used to detect and
log a disagreement. The shared rule is written once in the ADDED requirement and referenced by the MODIFIED
one; the fixture pins the agreement with a deliberately mismatched window (`dev` vs `.worktrees/dev2`).

## 5. Compatibility, residuals and non-goals

- **Adapter notify commands.** `TEAM_AGENT_NOTIFY_CMD` runs inside the agent's shell; if an adapter runs it
  from a directory that names no seat, the call now refuses instead of writing `agent:pm`. Mitigation: the
  notify template already supports `{agent}`, and the apply updates the recommended command in
  `references/agent-adapters.md` to `… notify pm --from {agent} --from-file {summary_file}` so the explicit
  claim is always present. The built-in Pi path is unaffected (the extension is the sender there).
- **Historical lines are not rewritten.** Rewriting the inbox would falsify the ledger it is evidence for;
  the fix is forward-only, and the report says so.
- **Other writers unchanged**: `team say`, `draft`, pulse `blocked` lines, meeting knocks, the outbox and
  delivery-guard semantics.
- **`--root`** is already folded into M40's identity, so `team --root <main> notify …` resolves to the main
  worktree (`pm`) wherever it is run from: an explicit location override, not a silent inheritance.
- **`TEAM_AGENT`** is not set by dispatch (measured empty in worker processes); its only role here is
  adversarial — it must not override the directory, which the fixture pins.

## 6. Falsifiability plan

- Fixture: a scratch project (`team init` + `dev`/`dev2` worktrees) with inherited identity cleared, the
  extension driven through the existing smoke runner with a fake tmux for the window cases; the scenarios of
  the ADDED requirement and the MODIFIED one's new scenario are each one assertion.
- Red baseline: today's tree fails the first scenario (`agent:pm` where `agent:dev2` is required) — the
  apply's report carries the red-before tail, the green-after tail and the restored tree.
- `flip-p72.sh` mutations, each reddening a named scenario: (1) sender back to `$agent` (the recipient) →
  scenario 1; (2) unresolved runtime directory falling back to `pm` → scenario 4; (3) the extension back to
  `window || basename(cwd)` → the agreement scenario; (4) dropping the `TEAM_AGENT` guard → scenario 3.
