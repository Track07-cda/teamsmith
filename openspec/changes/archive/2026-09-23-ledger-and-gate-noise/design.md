# Design: `ledger-and-gate-noise` — the gate's premise is stable state, the ledger sees every worktree, and an empty override is a value

## 1. Context

Read-only recon against this checkout (`.worktrees/dev-bob`, branch `task/P43-json-override-propose`), measured
2026-09-22. Every number below was produced by a command in this tree; the raw shapes are in the task brief
(D34, M31, P36, M74) and re-measured here.

### 1.1 The self-test's host fingerprint (`tests/container-tmux.sh:102`)

`host_tmux_fingerprint()` hashes two components:

1. **Per socket**, over three candidates (the caller's socket from `TMUX`, `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/default`
   and `/tmp/tmux-<uid>/default`, deduplicated): the socket's `stat -c '%i:%Y:%s'` and the server's answer
   `list-sessions -F '#{session_name}:#{session_created}:#{session_windows}:#{session_attached}'`.
2. **A whole-`ps` sweep**: `ps -eo pid=,args= | grep -E '(^|/)tmux( |$)' | grep -v grep | sort`.

Measured against the live host:

- The sweep's `^tmux` alternative never fires: `ps -eo pid=,args=` right-aligns the pid, so every line starts with
  padding. What actually matches is the `/tmux ` branch, i.e. **path-qualified** invocations — the gate shim
  (`…/scripts/shim/tmux list-windows …`), `/usr/bin/tmux …` — while the daemonized servers
  (`tmux new-session -d -s …`, ppid 1) and the clients (`tmux attach -t …`) do not match at all.
- It also matches **unrelated shells** whose argv text contains a path ending in `/tmux ` (measured: the probe's
  own `bash -c` line, which merely printed a tmux command).
- A storm of clients moves the hash: `1477ba9e…` before, `a55a6516…` after six `tmux list-sessions` calls.
- The pair brackets only the container runs: `ensure_image` and the mount probe run in `main` **before**
  `ct_selftest`, so the window is seconds, not image-build minutes.
- Reading the fingerprint is read-only: `display-message -p '#{pid}'` on a socket with no server exits 1 with
  `error connecting to …` and starts no server (measured; only the socket directory is created).

What the sweep adds over component 1 is attribution-free: a teammate's private fixture server (`tmux -L p21-…`,
daemonized) or another project's session change is exactly the kind of ps-visible fact it counts, and **four
projects share this host**. That is the false-red channel D34 measured (`✓2807 ✗1`, `前 2dc577da… ≠ 后 9c2754d9…`
with a third value `3b1f7842…` on the immediate rerun).

### 1.2 The untracked-record warning (`scripts/lib/cmd-status.sh:497`)

`team_untracked_records()` runs one `git -C "$TEAM_MAIN_ROOT" status --porcelain --untracked-files=all --
<docs>/reviews <docs>/reports`, keeps the `??` lines and drops dotfiles (`awk -F/ '$NF !~ /^\\./'`). The digest's
[4] consumer (`:684–700`) counts them, caps the display at 8 and appends the M16 task-name suffix computed from
the path (`team_record_task_id` + `team_task_name_suffix`). The function's own comment rules the worktrees out on
the ground that [3] already explains "wait for delivery".

Measured in a scratch fixture (a fresh `team init` repo with a worktree at `.worktrees/dev`):

- An untracked `docs/team/reviews/P43r.md` **inside the worktree** is named by neither [3] nor [4]: [3] iterates
  report candidates only, [4] never leaves the main checkout.
- An untracked `docs/team/reports/P43d-dev.md` inside the worktree appears in [3] once as
  `P43d-dev（在 dev 分支上）（未入账报告） … 先等 agent 交付` — a *draft* verdict, not the byte-level question [4]
  answers (a squash merge carries branch content only). The package file next to it
  (`docs/team/reports/P43d-dev/run.sh`) is not named at all.
- A `git status` per worktree is one subprocess; the ledger-read budget test (§37) already counts `git`
  invocations and its fixture has two worktrees.

### 1.3 The empty seat override (`scripts/lib/cmd-config.sh:537`, `common.sh:1174`)

`team_config_seat_state()` prints `model<TAB>source<TAB>override`; the read splits it with
`IFS=$'\t' read -r model src override <<< "$(…)"` at `:718` and again at `:661` (the `models.known` walk). With
`TEAM_AGENT_MODELS="dev="`:

- `team_agent_model dev` (`common.sh:1174`) matches the `dev=*` token and prints an **empty** model.
- A leading tab is IFS whitespace, so `read` **strips** the empty first field: `model` becomes `配置` (the source
  label), `src` becomes `true`, `override` stays unset — and the record is emitted as
  `…"model":"配置","source":"config","override":}`.
- Measured: `python3 -m json.tool` refuses the document (`Expecting value: line 1 column 35533`),
  `models.known` is `["deepseek/deepseek-flash","配置"]`, and `team ps`/`roster` display `0·配置` for the seat.

So the same defect breaks three surfaces: the machine read's validity, the model vocabulary, and the seat's
displayed model.

## 2. Goals / Non-Goals

**Goals.** (1) The container self-test's premise is host state a real change moves and a bystander cannot —
measured three ways (a client storm is a no-op, a server's death moves it, the in-scope session table stays in
the premise). (2) `team digest` answers "these bytes are in no commit" for every worktree, per file and with the
agent's name, without turning into a blocker and without reporting dirty non-records. (3) Every JSON exit of the
CLI parses on the empty-override shape, the seat row keeps its fields, `known` carries models only, and the seat's
displayed model is the configured fallback — one resolution shared by `team ps`, the read and the dispatch.

**Non-Goals.** The writer (`team config set`'s validation, CAS, audit, danger list, canonicalization) and
`set-agent-model`; the M31 findings about staged/modified (non-`??`) records; the pulse's pending definition
(`watchdog`); `tmux-lint.pl`'s rules; the panel's rendering; `panel.conf`; the container image.

## 3. Decisions

### D0. Spec homes: `verification`, `board-and-status`, `memory-and-deps`

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the self-test's fingerprint is stable per-socket host state; only a real host change moves it; the two-sided fixture is part of the gate | `verification` | ADDED |
| R2 | the untracked-record reminder covers the main checkout **and** every worktree, names `<agent>: <path>`, filters to the record paths, and stays reminder-only | `board-and-status` | MODIFIED (`Unfinished work is visible as pending wrap-up`) |
| R3 | the ledger read's git-call budget and the counting fixture cover the per-worktree scan | `board-and-status` | MODIFIED (`The ledger read path stays inside a git-call budget…`) |
| R4 | a seat row is field-safe; `override` is a boolean; an empty token falls back; no label in `known` | `memory-and-deps` | MODIFIED (`A seat's model is read and written as a seat…`) |
| R5 | every JSON exit parses; an empty string is `""`, a field is never valueless | `memory-and-deps` | ADDED |

**The brief's `deltas:` header lists `watchdog`; this change writes `board-and-status` instead**, which the brief's
body explicitly allows ("watchdog 或 board-and-status —— 按能力语义选一个并说明"). The reason is the capability
boundary: `watchdog` owns the **pulse's** definition of pending work (`team watch --once` wakes the PM on an
unread inbox, a report without a review, a `blocked` row, a stopped agent with an unfinished task) and says
nothing about `team digest`'s byte-level view of the ledger. The two requirements R2/R3 extend live in
`board-and-status`, whose purpose line is "how `digest`/`status` report". Nothing in this change moves the pulse's
wake-up set, and no `watchdog` delta is written. The header line is flagged in the delivery report for the PM to
correct (the change-dispatch guard reads it, so a wrong list is a ledger inconsistency, not a scope question).

### D1. The fingerprint is per-socket server state — the `ps` sweep is deleted

Ruled shape (R1): the fingerprint keeps the three-socket loop and, per socket, contributes **the socket's `stat`
identity**, **the server's session table** and — when a server answers there — **the server's pid**
(`display-message -p '#{pid}'`, read-only, no server started). The whole-`ps` sweep is removed.

Why:

- **The sweep is the only component that can see facts not attributable to an in-scope socket**, and that is
  exactly what made it a false red. Measured: it matches path-qualified client invocations and even unrelated
  shells, and it matches none of the daemonized servers (pid padding) — a ps snapshot is the wrong instrument.
- **Attribution is what keeps the premise honest.** A `ppid=1`-filtered server set would be stable against
  clients but still flap on another project's private fixture server (`tmux -L p21-…`) or a teammate's dispatch
  in the pair window. The `#{pid}` per socket query is the same fact ("is there a live server here, and which
  process?") with the socket as its key, so nothing outside the in-scope sockets can move the value.
- **The red side is preserved and sharpened.** A killed server removes the socket (`stat` changes) and empties
  the session answer; a server that keeps an empty session table (`exit-empty off`) still flips the pid line —
  the corner the sweep was supposed to cover.
- Rejected alternatives: keep the text grep with a `ppid=1` filter (unsolved cross-project churn, and the
  padding bug means the grep does not even match servers); count every tmux process (today's bug); drop the
  process fact entirely for `stat` + `list-sessions` (loses the empty-table corner and R1's "servers only, never
  clients" falsifiability).

**Residual, stated on purpose**: the in-scope session table stays in the premise, so a window created or
destroyed in a host session *between* the two reads is red. That is not noise but the assertion's contract — the
self-test claims the host's tmux state is unchanged — and the window is the two container runs (seconds), with
the gate serialized by its lock. The design records it so a future reader does not re-litigate it as a bug.

### D2. The ledger scan walks the worktree directories, not `git worktree list`

Ruled shape (R2, R3): the advisory scan runs the same `git status --porcelain --untracked-files=all --
<docs>/reviews <docs>/reports` for the main checkout and for every directory under
`$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/*/`, attributing each hit the way the brief asks (`<agent>: <record path>`,
the directory's basename; the path after the prefix is the worktree-relative one, so `team_record_task_id` and the
M16 name suffix work unchanged). The scan stays advisory: the warning is printed, no exit code changes, the
display cap (8) and the total count stay, and a worktree whose `git status` fails (a stale directory that is no
longer a worktree) is skipped silently.

Why the directory walk and not `git worktree list --porcelain`:

- **The question is on-disk bytes.** A worktree git has pruned but whose directory still holds a report package is
  precisely a record that no commit carries; a list from git would not see it while the bytes are still there.
- **Cost and locality.** The directory walk is one `git -C <dir> status` per worktree and reuses the existing
  pathspec/awk filter; `worktree list` costs another call and its output needs a second parse (and the ledger
  read's budget is asserted as call counts, R3).

Why [3]'s existing draft note does not make [4] redundant: [3] answers "is this task's primary report
delivered?" for **tasks** and only for reports; [4] answers "will this byte survive the merge?" for every record
file (reviews included, and the files inside a report package), on the checkout where it was found. Measured:
today both questions miss a worktree-side review record. Both stay; [4]'s line is a reminder, never a verdict.

Rejected: scanning only the main checkout (the bug); extending the scan to staged/modified records (M31's two
findings — the brief keeps this change at `??`; PM decision, out of scope here); deduplicating against [3]
(fragile, and the two lines answer different questions).

### D3. An empty override is a present override with the fallback model, and `""` is how emptiness serializes

Ruled shape (R4, R5):

- The seat row is read **field-safely** (a delimiter-safe read, or a quoted-printing variant), so the fields can
  never shift again; `models.seats` keeps one row per roster seat plus `pm`.
- `override` is always a JSON **boolean**: `true` when the seat carries a token in `TEAM_AGENT_MODELS`
  (`dev=` included), `false` otherwise (for `pm`: whether `TEAM_PM_MODEL` is set). It is never omitted, never
  `""`, never `null`.
- A token whose value is empty **resolves like an absent token**: `team_agent_model` skips it and returns
  `TEAM_DEFAULT_MODEL`. That one change fixes three surfaces at once — `team ps`/`roster`'s displayed model, the
  read's `seats[].model`, and the dispatch renderer — while `override` still reports the file faithfully.
- `known[]` therefore carries the resolved fallback and never a source label; the vocabulary stays the same set
  `choices.values` reports.
- **Serialization ruling**: a string field with no value is `""` (a JSON string), never a valueless field
  (`"override":`) and never `null`. The failing shape is the *valueless* field; an empty string is a legal,
  visible value, and a reader can always tell "no value" from "no field".

Rejected: `null` for empty values (adds a second empty representation and changes an existing field's type);
dropping the row when the model is empty (violates the base requirement that `seats` covers every roster seat,
and hides the token); **leaving the resolution empty and only serializing `model` as `""`** (a legal document,
but the read would report a model the CLI itself does not display — `team ps` keeps printing `0·配置` — while
the base requirement says the row carries the model the CLI displays for that seat); a second fallback inside
the read (would let `team ps` disagree with the JSON — the exact second source of truth R4 forbids); refusing
`dev=` at write time (a hand-edited file must still read; the write side is not in this change).

### D4. Where the gates live

- **R1** — `container-tmux.sh` gains `--fingerprint` (print the value for the current `TMUX`/`TMUX_TMPDIR`) and
  `--fingerprint-check` (the two-sided fixture: a client storm leaves the value byte-identical; killing an
  in-scope server changes it). The fixture joins **the existing** smoke §31c (`tmux 运行时闸门`, which already owns
  the private-server leg and the default server's liveness bracket): a live leg next to `31c·真私有 server 生死`
  (full gate; a visible FAST SKIP, matching that section's discipline) plus a FAST-runnable static pin on the
  fingerprint's shape — its body carries no whole-`ps` snapshot and takes its facts per in-scope socket.
  The container bracket itself stays in §31b (full gate) and keeps asserting the byte-identical fingerprint.
- **R2/R3** — smoke §7b (the M31 section) gains the worktree fixtures (an untracked review and report package in
  a worktree, a `junk.txt` decoy, the reminder-only exit code), and §37's counting fixture seeds an untracked
  record inside one of its two worktrees so the ≤50 budget is measured with the new scan and the cache-on/off
  equivalence still holds.
- **R4** — `tests/config-cli.sh` (the `list`/`models`/`seats` sections) gains the empty-override contract, the
  valueless-field flip and the `team ps`/`dispatch --print` agreement; `tests/panel-choices.sh` stays green
  because the model vocabulary only loses the label.
- **R5** — `tests/config-cli.sh` gains a `json` section: the four machine exits
  (`config list --json`, `change status <id> --json`, `paths`, and `monitor --json` when a JS runtime is present —
  absent runtime is a visible SKIP) on the empty-override contract, each piped through `python3 -m json.tool`,
  plus the scratch-tree red side where a re-introduced valueless field must fail the walk.

## 4. Verification map

Requirement → delta file → primary fixtures:

| Requirement | Delta | Fixtures (FAST-visible unless noted) |
|---|---|---|
| R1 fingerprint premise | `specs/verification/spec.md` (ADDED) | `container-tmux.sh --fingerprint-check` via smoke §31c; `--selftest` in §31b (full) |
| R2 worktree record visibility | `specs/board-and-status/spec.md` (MODIFIED) | smoke §7b |
| R3 call budget and fixture | `specs/board-and-status/spec.md` (MODIFIED) | smoke §37 (M50 counting fixture) |
| R4 seat read and resolution | `specs/memory-and-deps/spec.md` (MODIFIED) | `config-cli.sh list models seats`; `panel-choices.sh`; `team ps` |
| R5 JSON validity | `specs/memory-and-deps/spec.md` (ADDED) | `config-cli.sh json` |

Each requirement's scenarios are written to fail: R1's storm/death/session-change fixtures, R2's
`junk.txt` decoy and per-file names, R3's call count with the cache off, R4's valueless-field flip and
`dispatch --print` line, R5's parse walk.

## 5. Open risks handed to the PM

1. The brief's `deltas:` header (`watchdog`) disagrees with the body (D0). The proposal writes
   `board-and-status`; the header needs the same word if the dispatch guard is to stay truthful.
2. The M31 staged/modified gap stays open (by scope); it remains a candidate for its own change.
3. The self-test's premise still includes host session churn (D1's residual). If that ever produces a real
   false red, the ruling is to narrow the session line to name+creation time rather than to reintroduce a
   process sweep.
