# Tasks: `ledger-and-gate-noise`

Planning only — nothing in this file is executed by the propose task (P43). One apply brief: the fingerprint's
premise, the ledger scan and the seat read are independent code paths, but they share one gate run and one report,
so they land together. Items that need a real process (a tmux server, a container, a JS runtime) are marked; none
of them is the only evidence for a requirement — the FAST-wired fixtures carry the cheap half.

Coverage map (requirement → items): **R1** the self-test's stable premise → 1.1–1.4; **R2** worktree record
visibility → 2.1, 2.2; **R3** the call budget and the counting fixture → 2.3; **R4** the seat read and the empty
token's resolution → 3.1–3.3, 3.5; **R5** JSON validity → 3.4; gate/evidence → 4.1–4.3; the independent
verification phase → 5.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check` (and smoke §31c) | its four legs' lines | storm leg: two values equal, exit 0; kill and session legs: values differ, exit non-zero; no-server leg: exit 0 twice |
| R2 | a scratch repo with an untracked record in `.worktrees/dev` + smoke §7b | digest's `记录未入账` block | one line per file as `dev: <path>`, the `junk.txt` decoy absent, exit 0 |
| R3 | smoke §37's counting fixture (cache on and off) | the printed call counts and the digest block | cache on ≤ 50 with the worktree record named; cache off > 50; the cache on/off outputs identical after filtering live fields |
| R4 | `team config list --json` / `team ps` / `team dispatch dev --print` on `TEAM_AGENT_MODELS="dev="` | `models.seats`' `dev` row and `models.known` | `model`=`TEAM_DEFAULT_MODEL`, `source`=`config`, `override`=`true`, no label in `known`, dispatch renders that model |
| R5 | `bash skills/teamsmith/tests/config-cli.sh json` (smoke §33) | the parse line per machine exit | each exit 0 and parsed by `python3 -m json.tool`; the scratch-tree red side non-zero with the position printed |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is agent-owned;
`skills/teamsmith/scripts/lib/cmd-status.sh`, `cmd-config.sh` and `common.sh` are **PM-owned** and need an explicit
grant for this change (the digest scan, the seat read and the model resolution only — the writer is untouched);
`openspec/changes/ledger-and-gate-noise/**` belongs to the phase's owner; `docs/team/reports/**` is the agent's own
file. `openspec/specs/**` and `docs/team/tasks/**` stay PM-owned.

Fixture notes: every fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u
TEAM_SESSION`) and writes only inside its scratch tree; the fingerprint fixture starts its private server as
`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<a mkdir -p'ed directory> tmux -L <private-name> …` (memory #1250: the
socket directory must exist, and `TMUX` must be cleared), never with a literal absolute tmux path, and it kills
that server on exit; the ledger fixtures are real git repos with a real worktree.

## 1. The self-test's premise is stable state (`verification`, ADDED)

- [x] 1.1 `tests/container-tmux.sh`: rebuild `host_tmux_fingerprint()` (currently `:102`) — keep the three-socket
  loop (`stat -c '%i:%Y:%s'` + `list-sessions`), add the live server's pid per in-scope socket via
  `display-message -p '#{pid}'` (queried only when the socket exists), and **delete** the whole-`ps` sweep; add a
  `--fingerprint` mode that prints the value for the current `TMUX`/`TMUX_TMPDIR` without a container. Verify:
  `bash skills/teamsmith/tests/container-tmux.sh --fingerprint` exits 0 and prints one value; the function's body
  carries no `ps` call —
  `sed -n '/^host_tmux_fingerprint()/,/^}/p' skills/teamsmith/tests/container-tmux.sh | grep -c 'ps '` is 0.
- [x] 1.2 `tests/container-tmux.sh`: add `--fingerprint-check`, the two-sided fixture of R1 — a private
  default-named server in a private `TMUX_TMPDIR`, (a) two reads bracketing a client storm are byte-identical,
  (b) killing that server between two reads changes the value and the mode exits non-zero, (c) creating a session
  on it changes the value, (d) with no server the read exits 0 twice, prints the same value and leaves no socket
  file. Verify (flip, red before → green after): in a scratch copy of the tree with the old fingerprint restored,
  `--fingerprint-check` fails on (a) with the two values printed; with the new fingerprint it exits 0. Paste both
  tails.
- [x] 1.3 `tests/smoke.sh` §31c (the existing `tmux 运行时闸门` section, which already owns the private-server leg
  and the default server's liveness bracket): add a live leg next to `31c·真私有 server 生死` that runs
  `--fingerprint-check` and asserts its exit code (full gate; `fast_skip`/`cond_skip` for no tmux, matching that
  section's discipline), plus a FAST-runnable static pin on the fingerprint's shape — its function body carries
  no `ps` snapshot and reads its facts per in-scope socket. Verify: `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` shows the pin green, and re-inserting the `ps` sweep into a scratch
  tree turns it red; the full run's leg is green with the fixture's tails. §31b keeps the container self-test
  (full gate only) with its byte-identical fingerprint bracket unchanged.
- [x] 1.4 Isolation lint: the new fixture's server calls carry isolation proof. Verify:
  `perl skills/teamsmith/tests/tmux-lint.pl` exits 0 with 0 RED lines.

## 2. The ledger sees every worktree (`board-and-status`, MODIFIED × 2)

- [x] 2.1 `scripts/lib/cmd-status.sh` (`team_untracked_records`, `:497`): scan the main checkout and every
  directory under `$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/*/`, keeping the one-`git status --porcelain
  --untracked-files=all -- <docs>/reviews <docs>/reports` shape per source and the existing dotfile filter; return
  each hit as `<agent>: <worktree-relative record path>`; a directory whose `git status` fails is skipped
  silently; the consumer at `:684` stays reminder-only (no exit-code change) and keeps the count and the display
  cap. Verify: in a scratch fixture (untracked `docs/team/reviews/T9.md`, `docs/team/reports/T9-dev.md`,
  `docs/team/reports/T9-dev/run.sh` inside `.worktrees/dev`, plus a decoy `junk.txt`) `team digest` names all
  three with the `dev: ` prefix, prints no line for `junk.txt`, and exits 0.
- [x] 2.2 `tests/smoke.sh` §7b: extend the M31 section with the worktree fixtures (review + report + package file
  named per file; the decoy silent; the unknown-name case falls back to the bare path; the reminder-only exit
  code). Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green, and neutering the
  worktree leg in a scratch tree turns the section red (the M31 flip style).
- [x] 2.3 `tests/smoke.sh` §37 (M50 counting fixture): seed one untracked record inside `.worktrees/bob` and
  assert (a) digest names it with the `bob: ` prefix, (b) the cached call count is still ≤ 50 with the new scan,
  (c) the cache-off count is still > 50, (d) the cache on/off outputs stay byte-identical after filtering the live
  fields. Verify: the section's lines with the printed counts; the fixture is red if the record is not named.

## 3. The seat read and the JSON contract (`memory-and-deps`, MODIFIED + ADDED)

- [x] 3.1 `scripts/lib/common.sh` (`team_agent_model`, `:1174`): a token whose value is empty resolves like an
  absent token (return `TEAM_DEFAULT_MODEL`). Verify: on the empty-override contract `team ps` and
  `team roster` display `TEAM_DEFAULT_MODEL` (not `0·配置`) and `team dispatch dev --print` renders that model.
- [x] 3.2 `scripts/lib/cmd-config.sh`: read each seat row field-safely (the `IFS=$'\t' read` sites `:661` and
  `:718` must not lose an empty leading field), emit `override` as a JSON boolean, keep an empty model as `""`,
  and keep source labels out of `model`/`known`. Verify: `team config list --json` on the `dev=` contract parses,
  its `dev` row reads `model`=`TEAM_DEFAULT_MODEL`, `source`=`config`, `override`=`true`, and `models.known`
  carries no `配置`.
- [x] 3.3 `tests/config-cli.sh` (`list`, `models`, `seats`): add the empty-override contract (row present with the
  fallback, boolean `override`, no label in `known`), the empty-`TEAM_DEFAULT_MODEL` case (`"model":""`), the
  `team ps`/`dispatch --print` agreement, and the flip **F-J1**: a scratch tree whose serializer emits a valueless
  field makes the section red, restoring it makes it green. Verify: the section tails plus both F-J1 tails.
- [x] 3.4 `tests/config-cli.sh`: new `json` section — on the empty-override contract run `config list --json`,
  `change status <id> --json`, `paths` and (JS runtime present) `monitor --json`, and parse each with
  `python3 -m json.tool`; with no JS runtime the console exit is a visible SKIP; add the scratch-tree red side of
  R5. Wire the section into smoke §33. Verify: `bash skills/teamsmith/tests/config-cli.sh json` green and, in a
  scratch tree with a valueless field, non-zero with the parser's position printed.
- [x] 3.5 Regression around the vocabulary: `bash skills/teamsmith/tests/panel-choices.sh` and
  `bash skills/teamsmith/tests/panel-p21.sh choices` stay green (the model vocabulary only loses the label).
  Verify: both tails.

## 4. Gate and evidence (the apply's own report)

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, `bash skills/teamsmith/tests/smoke.sh </dev/null` (once, full),
  `perl skills/teamsmith/tests/tmux-lint.pl`, `bash skills/teamsmith/tests/container-tmux.sh --selftest`
  (container present), and `git status --porcelain` clean. Paste the tails.
- [x] 4.2 The report's flip section: each defect's red→green (the fingerprint storm and the server death; the
  worktree record becoming visible with the decoy still silent; the parse failure at column 35533 becoming a
  passing walk), the ledger fixture's before/after digest [4], and the git-call counts with the cache on and off.
- [x] 4.3 Trial archive on a scratch copy (`cp -r openspec /tmp/trial-p43 && (cd /tmp/trial-p43 && openspec
  archive -y ledger-and-gate-noise)`) — proves the MODIFIED requirements keep every base scenario and that the
  deltas merge next to the other open changes.

## 5. Independent verification (a different agent — the pipeline's verify phase)

- [x] 5.1 Rerun, out of tree and on the apply's tip: `--fingerprint-check`'s four legs, the worktree-record
  fixture with its decoy, the call counts, the JSON parse walk, `openspec validate --all --strict` and the full
  smoke; the record goes to `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings
  is rework, not archive).

> **PM 勾选说明（2026-09-22）**：propose=P43 · apply=P47（dev-bob）· verify=P54（verify，PASS）· 尾单 P58（F1：pm 行同源 + R5 文字）—— 全部任务项落实。
