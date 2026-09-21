# tmux-gate-grant-redesign · design

## Context

`spec-backfill-2026-09` gave the tmux runtime gate a home in `boundary` and the PM's evidence pass (M62) found the
contract broken: the gate refuses default-socket destructive calls, but the very tool that builds the windows
(`scripts/team:19`) exports `TEAM_ALLOW_DESTRUCTIVE_TMUX="${…:-1}"`, the schema default is `0`
(`cmd-config.sh:65`), and tmux copies a server's environment into every new pane — so a server that was ever started
from a process carrying the variable authorizes every window of every project on that server
(`docs/team/reviews/M62.md`, with the independent reproductions). The seventh default-server death
(2026-09-21T12:19:58Z) is in the ledger as two consecutive lines — `act=refused` then `act=override`
(`.pi/team/state/tmux-calls.log` L143–144).

The user chose option 2 (2026-09-21): redo the grant model. Verdict by the object a call targets; a human's argv
token as the only in-band escape; no environment variable authorizes anything.

Baseline on this branch (`421bebb`, the brief commit = `main`'s tip):

```
$ git log --oneline -1
421bebb docs(team): M63 brief — redesign the destructive-tmux grant model …

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict | tail -2
Totals: 17 passed, 0 failed (17 items)

$ grep -n '^### Requirement' openspec/specs/boundary/spec.md
11:### Requirement: Actions stay inside the project and its own session
23:### Requirement: Empty or relative tmux targets are refused
33:### Requirement: Typing into a foreign session needs an explicit, human-granted override
45:### Requirement: Credentials are never read, echoed or committed
63:### Requirement: An actor touches only the paths its brief allows
# → the base boundary spec has no gate requirement; the gate rows are pending in
#   openspec/changes/spec-backfill-2026-09/specs/boundary/spec.md L5 (gate), L68 (log+injection), L106 (container)

$ grep -o 'act=[a-z-]*' .pi/team/state/tmux-calls.log | sort | uniq -c
      1 act=override
   1823 act=pass
      1 act=refused
$ grep -E 'kill-server|kill-session|kill-window|kill-pane' .pi/team/state/tmux-calls.log | grep -o 'act=[a-z-]*' | sort | uniq -c
      1 act=override
     41 act=pass
      1 act=refused
```

The gate's whole live path holds one refusal, one override (the PM's demonstration that killed the shared server)
and 41 passes on private sockets: the "escape hatch" is not an exception, it is the mode of operation.

## Goals / Non-Goals

**Goals**

- One verdict rule: the object a destructive call targets decides; the environment never does.
- Make the escape a deliberate, auditable, one-shot act of a human (an argv token, or the documented absolute path).
- Delete the export, retire the key visibly, and keep every legitimate CLI destructive path working.
- Make the falsification cheap and safe: fixtures that prove a verdict cannot execute a wrong one.

**Non-Goals**

- No change to socket resolution, the M41 fake-isolation matrix, the non-destructive fast path, the log bound, the
  fixture container contract, or the isolation lint's A–D proofs.
- No new capability, no `## REMOVED` requirement, no code in this task.
- No flag on any CLI call site (see D5) and no widening of the guarded subcommand set.

## Decisions

### D1 — The requirements land in `boundary` as ADDED, and the pending gate rows move out of `spec-backfill-2026-09`

The base spec has no gate requirement (baseline above); the statement lives in an **unlanded** sibling delta
(`spec-backfill-2026-09/specs/boundary/spec.md` L5/L68). Those rows cannot simply land either: they promise the
`TEAM_ALLOW_DESTRUCTIVE_TMUX=1` escape this change deletes, and the PM blocked their archive because the default
they promise is defeated in real windows (M62 review).

**Recommended plan (this delta is written for it):** the two gate rows are *transferred* to this change — this
delta adds them under new names, and `spec-backfill-2026-09`'s boundary delta keeps only its container requirement
(L106). That transfer is a PM action under spec-backfill's own change (a small rework task); it is named in
`tasks.md` as the first prerequisite of M63's archive. Consequences: this change's archive does not depend on
another change's order, and no two requirements end up as parallel statements for the same rule.

**Alternative considered and rejected:** `## MODIFIED` against the spec-backfill wording. At this change's archive
the base still would not hold the requirement, and OpenSpec catches "a MODIFIED naming a requirement the base
lacks" only at the trial archive (`references/openspec.md` §5) — so M63's archive would be gated on spec-backfill
archiving first, and spec-backfill could only archive honestly *after* the fix, by which time its text is the old
model. Both orderings record something false. The new requirement names also state the new rule ("decided by the
object it targets"), which a MODIFIED block keyed to the old name cannot.

The container requirement (L106) is **not** touched: it constrains fixtures that start or kill servers, not the
verdict, and it stays true.

### D2 — The exact ownership criterion (brief question 2)

The verdict runs after socket resolution, so it only ever decides calls that resolve to the **shared default
socket** (private sockets keep passing; the M41 table and the fake-isolation verdicts are copied verbatim by the
implementation).

| subcommand | effective target | verdict |
|---|---|---|
| `kill-server` | none (the server is the object) | **refused** — no project-owned object exists on a shared server |
| `kill-session` with `-a` | `-a` widens to every other session | **refused** — no single named target bounds the effect set |
| `kill-session` / `kill-window` / `kill-pane` | `-t X`: `X` non-empty, its session component (before the first `:`) a literal session name equal to a non-empty `TEAM_SESSION`, identity **bound to the caller** | **allowed-owned** |
| the same three | no `-t`, `-t ""`, `-t %N`, `-t @N`, `-t :win`, `-t .`/`+`/`-`, a window name without its session, another session's name | **refused** |
| any of the four | the argv token present (D3) | **explicit-flag** (execute) |

The **identity binding** is M40's contract read at the gate (`team_identity_env_prefix`, `common.sh` L622–641):
`TEAM_SESSION` is trusted only when `TEAM_ROOT` or `TEAM_MAIN_ROOT` resolves (realpath) to the gate's cwd or an
ancestor of it. The launch commands write exactly those three variables into every window (M40), so the binding
holds in the PM window (main root), in worker windows (their worktree) and in the pulse window. An inherited
foreign `TEAM_SESSION` fails it, which is the leak shape M62 found.

Parsing rules: the effective target is the **last** `-t` in the subcommand's argv (tmux's own last-wins option
semantics), accepting `-t x` and `-tx`; an unparseable or ambiguous form is "not provable" and is refused. The
decision runs on a copy; the executed argv is the caller's (minus the gate's own token). Prefix subcommands
(`kill-ser`, `kill-ses`, `kill-w`, `kill-p`) are classified exactly as today. `kill-window -a` / `kill-pane -a`
stay scoped to the target's session/window, so they inherit their target's verdict.

**Rejected alternative:** resolving the caller's live session with a read-only
`display-message -p -t "$TMUX_PANE" '#S'` against the resolved socket. It would allow `team` invoked from an
unrelated cwd inside a gated window (the binding refuses that today), but it adds a server round trip and a new
failure mode to the verdict path — including for probes that must prove a refusal without touching a server — and it
makes the gate itself query the shared server, which D6 says fixtures must not do. If the PM prefers the query
variant, only this paragraph's binding sentence changes.

### D3 — The argv token (brief question 1)

**Name and syntax:** `--teamsmith-allow-destructive`, a standalone word. Recognized **only in the global-option
position** (while scanning options before the first non-option word, i.e. before the subcommand); every occurrence
there is removed before the downstream `exec`. `--teamsmith-allow-destructive=1` is *not* recognized (it falls
through to tmux, which errors — fail closed), and a token equal to it **after** the subcommand is data (a
`send-keys` payload must survive untouched). Nothing is written to the environment; the executed process sees no
trace of the token.

**Why the position restriction:** after the subcommand, every word is a command argument — tmux command syntax
alone cannot tell a payload from an option — so stripping there would corrupt data. Why this name: tmux has no
`--teamsmith-*` option, so with the gate absent the token makes tmux fail instead of silently executing; and a
plain `--allow-destructive` would risk colliding with a future tmux option.

**Consumption vs "transparent pass-through":** the M36 principle is "judge on a copy, execute the original argv".
The token is the gate's own, not tmux's, so the contract becomes "execute the caller's argv minus the gate's own
tokens"; everything else stays byte-for-byte, including incomplete calls (`tmux -L`, `tmux -V`, no subcommand) that
must be passed through rather than hang.

### D4 — Retiring `TEAM_ALLOW_DESTRUCTIVE_TMUX` (brief question 4)

Decision: the key is **kept as a non-writable legacy tombstone**, not deleted.

- The shim stops reading it (today `shim/tmux` L162 reads it, L196 prints it as the remedy) and `scripts/team:19`
  (the export, default `1`) is deleted. No path exports it any more.
- The schema row (`cmd-config.sh:65`) stays, still `refuse` class (the console is read-only for it and
  `team config set` refuses it with the existing exit 5 contract), and its description changes from
  "allow destructive tmux calls outside a private socket" to a retirement note: it grants nothing, the verdict is
  by target, removal is unnecessary.
- `references/config.md:380`, `references/troubleshooting.md` §18 (L587–588 today) and `CHANGELOG.md:21` are
  rewritten to the new model; the word "override" leaves the gate's vocabulary (D7).
- `team doctor` gains one line when the running server's global environment still carries the key
  (`tmux show-environment -g`, read-only, skipped when tmux is absent): the key is retired, it grants nothing, and
  restarting the server clears the residue.

**Trade-off against deleting the key:** deleting it would be cleaner textually, but every existing project config
that still sets it becomes an unknown key in the settings read, with no visible migration step; keeping the
tombstone costs one inert row and turns the retirement into something an operator can see. Deleting the *export*
(not the key) is what removes the leak, and the tombstone cannot be re-armed because it is `refuse` class.

### D5 — The existing legal destructive paths, enumerated (brief question 3)

| path | where | target | authorization after this change |
|---|---|---|---|
| `team teardown --agent/--all` | `cmd-agents.sh:1069` | `$TEAM_SESSION:$w` | ownership — no flag |
| add-agent / dispatch window cleanup | `cmd-agents.sh:779`, `:812` (`team_tmux_kill_window "$TEAM_SESSION:$agent"`) | own session | ownership |
| `team review` window cleanup | `cmd-review.sh:883` | `$TEAM_SESSION:$w` | ownership |
| pulse / watch stuck-window restart and window close | `cmd-watch.sh:1361`, `:1376`, `:1380` | `$TEAM_SESSION:$w` / `$TEAM_SESSION:watchdog` | ownership |
| generic wrappers | `common.sh:1325–1332` (`team_tmux_kill_window`, `team_tmux_kill_session`) | the caller's target | ownership when the target is own; an empty target is still refused by `team_tmux_target_required` |
| `team up --agents`, `team resume` | `common.sh:1266`, `cmd-draft.sh:52/61/63`, `common.sh:2221` (`new-session`, `respawn-pane`) | not in the guarded set | unchanged — no authorization involved |
| host shell outside a gated window | any | any | no gate on `PATH` — unchanged |

**Conclusion: no CLI call site needs the token, and none gets one**; `scripts/team:19` is simply deleted. This is a
deliberate reading of the brief's "the CLI's own destructive calls switch to the argv flag": the flag is for a
human's exceptional act, and every CLI path targets a named object of its own session, which the ownership rule
already authorizes. Adding the token at those sites would require a "is the gate on `PATH`?" probe at each call
site (the CLI also runs outside gated windows, where the token makes tmux fail) and would fill the ledger with
`explicit-flag` lines for routine operations, destroying the one signal the audit exists for. If a future CLI path
must act on something its own session does not bound (a server, another session), the rule is: argv token, never an
environment variable.

### D6 — Fixtures under the new model (brief question 5)

The ruled shapes (`tests/smoke.sh` §31c, `tests/container-tmux.sh`, `tests/tmux-lint.pl`):

1. A probe whose verdict is **refused** or **allowed-owned** and whose call resolves to the shared default socket
   pins `TEAM_TMUX_REAL` to the argv-recording stub already used in §31c (smoke L10028–10039). A wrong verdict then
   executes a shell script, never a server. §31c already records the default server's liveness before and after; it
   keeps doing that.
2. A probe that must **execute a real destructive call** uses a private socket (`-L`/`-S`/private `TMUX_TMPDIR`,
   M23/M41 shapes) or the container runner. Nothing real is aimed at the real default socket.
3. The **leak shape** (a server started from a process whose environment carries `TEAM_ALLOW_DESTRUCTIVE_TMUX`)
   runs in the container (`container-tmux.sh`), where "the default socket" is the container's own and the host's
   fingerprint must stay byte-identical. No host-side fixture starts such a server.
4. The **lint** (`tmux-lint.pl`) keeps its A–D isolation proofs and its absolute-path rule; the token must be
   parsed as a global option so a flagged mutating call is still classified as mutating (it cannot hide), and the
   token must **not** count as an isolation proof. New selftest fixtures pin both directions.
5. The smoke identity sanitizer keeps unsetting `TEAM_ALLOW_DESTRUCTIVE_TMUX` (smoke L37) — now as a *regression
   guard*: the fixtures prove the value is inert, so a leaked value can no longer make a refusal assertion falsely
   red, nor falsely green.

### D7 — Audit vocabulary and log shape (brief question 6)

Actions become exactly `pass`, `refused`, `allowed-owned`, `explicit-flag`; the word **"override" is gone** from the
gate's own vocabulary — the shim, the refusal text, the gate's sections of `references/` (troubleshooting §18, the
config row) and the gate's `CHANGELOG.md` entry. Other mechanisms that legitimately speak of overrides
(`TEAM_REVIEW_ALLOW_*`, `TEAM_BOARD_DONE_FORCE`, the typing guard's env override) are untouched. The line keeps
today's fields
(timestamp, `sock=`, `TMUX=`, `TMUX_TMPDIR=`, `argv=`, `pid=`/`ppid=`, `cwd=`) and its 2000/1000 bound and
best-effort write; no field is added (the full argv already carries the target, and a richer line is not worth a
fixture churn). The refusal text names the reason class — no/shared identity, unbound identity, target not own,
server, widening — the resolved socket, the token and the private-socket route.

### D8 — What deliberately does not change

Socket resolution and the fake-isolation matrix (M41, `shim/tmux` L89–147); the non-destructive pass-through; the
incomplete-call pass-through; the log fields/bound; the PM/worker launch prefix contract (only the grant-related
parts of `common.sh` L2051–2100 comments change); the container contract (`container-tmux.sh` L1–40, exit 77);
the lint's A–D proofs; `new-session`/`new-window`/`respawn-pane`/`split-window` (not in the guarded set); every
`boundary` requirement other than the three this change adds.

## Evidence map (requirement → evidence at this branch's tip → review method)

| # | Requirement (this delta) | Evidence today (`421bebb`) | Independent review method (after apply) |
|---|---|---|---|
| R1 | `boundary#A destructive tmux call is decided by the object it targets, never by an inherited environment` | `shim/tmux` L149–162 (destructive set + the env-keyed verdict), L89–147 (socket table + fake isolation), L183–201 (refusal text); `team:19` (the export); `common.sh` L622–641 (identity contract), L2051–2100 (gate block) | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §31c's own/foreign/unprovable/server/widening/binding/inherited-env/token/private/fake-isolation/read-only probes green. Flips (each in a `/tmp` copy of the tree, restore → green): (a) put the `TEAM_ALLOW_DESTRUCTIVE_TMUX` read back in the shim → the inherited-environment probes stop refusing; (b) accept every target → the foreign-target probes execute the stub and go red; (c) drop the M40 binding → the unbound-identity probe allows; (d) keep the token in argv → the stub sees it. `bash skills/teamsmith/tests/container-tmux.sh --selftest` stays exit 0 |
| R2 | `boundary#The gate's actions are logged, and no window carries a destructive-call grant` | `shim/tmux` L165–181 (log), L12/L196 (the override vocabulary); `common.sh` L2089–2100 (`team_tmux_shim_exports`); `smoke.sh` L10028–10039 + the worker-window probe at L10290–10330; `cmd-config.sh:65`; `references/config.md:380`; `CHANGELOG.md:21`; `references/troubleshooting.md:582–600` | `grep -rn 'TEAM_ALLOW_DESTRUCTIVE_TMUX' skills/teamsmith/scripts/` → no read, no export (only the tombstone text); `grep -rn 'act=override' skills/teamsmith/` → nothing; FAST smoke → §31c's log-field/bound assertions and the window-env probe (the variable and any grant absent, `TEAM_TMUX_CALLS_LOG`/`TEAM_TMUX_REAL` present) green; `TEAM_AGENT_BIN=…` window evidence carries the CLI's calls as `act=allowed-owned`; `team config set TEAM_ALLOW_DESTRUCTIVE_TMUX 1 --dry-run` refuses (exit 5) and the config file is unchanged; the doctor residue line appears with the residue and not without it |
| R3 | `boundary#Destructive gate fixtures never aim the real tmux at the real default socket` | `smoke.sh` §31c L10028–10039 (stub), L10052–10053 and L10246/L10286 (the default server's liveness bracket), §31b/L9908–10011 (lint + container); `tmux-lint.pl` L26–44 (rules), L52 (mutating set), L691–718 (selftest); `container-tmux.sh` L1–40 (contract), L262 (bare kill-server), L280 (fingerprint) | `perl skills/teamsmith/tests/tmux-lint.pl --selftest` → the token fixtures red/clean as specified and the existing fixtures unchanged; `perl skills/teamsmith/tests/tmux-lint.pl` on the repo → clean; `bash skills/teamsmith/tests/container-tmux.sh --selftest` → exit 0, host fingerprint byte-identical, and the new leak-shape fixture inside it reproduces `act=refused` then `act=explicit-flag` (exit 77 with the reason when no runtime) |

## Risks / Trade-offs

- **The binding refuses a legitimate CLI run from an unrelated cwd inside a gated window** (`cd ~ && team --root
  proj teardown`). Remedy: the argv token, named in the refusal text. Accepted: the deployment paths (`team` from
  the PM window, a worker worktree, the pulse window) all sit inside the project, and acting on a project from
  outside its tree is exactly the inherited-identity shape M40 guards.
- **The token is a bypass by design.** It is one-shot, audited, and cannot be inherited; the audited alternative
  (`/usr/bin/tmux`) stays un-logged, which is why the lint keeps it red in repository scripts.
- **An inherited `TEAM_SESSION` that happens to be bound** (cwd inside the other project's tree) still authorizes
  that project's session. Accepted: the actor is then operating inside that project's tree, and the shared server's
  blast radius is not widened beyond it.
- **Fixture rot**: a future fixture could aim the real tmux at the real default socket. Mitigation: R3's stub rule
  is a scenario; the lint's "flagged call is still mutating" fixture keeps the flag from becoming a blanket
  exemption.
- **The transfer of the spec-backfill rows is another change's edit** (D1). Mitigation: it is named in `tasks.md`
  as the prerequisite of the archive, and the trial archive catches a forgotten transfer as two parallel
  requirements — the PM owns the decision.
- **Over-specification**: only closed tokens are pinned (exit 64, the four action names, the token spelling,
  `act=` field names); prose and message wording may change later.

## Migration plan

No project re-initialisation is needed: the scripts come from the skill, the schema row keeps its name, and a config
that still carries the key keeps loading. An operator sees the retirement in `team config list` (the tombstone's
description), in the refusal text (the token, no env value) and in `team doctor` (the server-global residue plus
the restart remedy). Windows launched before the upgrade keep the old variable in their environment and are
unaffected by it — that is precisely what R1's inherited-environment scenario pins.
