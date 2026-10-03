# Tasks: `sender-identity-refusal`

The propose task wrote the change and its delta (`specs/notify-and-inbox/spec.md`); the items below are the
apply's. The behaviour is already shipped (P201), so the apply changes no `skills/teamsmith/scripts/**` file: it
re-establishes the delta against the then-current baseline, adds the one missing red side, proves the archive
shape, and runs the gates. The verify phase is a separate brief owned by a different agent.

Coverage map: **R1** = `notify-and-inbox#A manual notification is attributed to its sender, not its recipient` →
1.1–1.3 (the contract text), 2.1–2.5 (falsifiability of its clauses), 3.1–3.2 (archive shape), 4.1–4.4 (gates),
5.1–5.2 (record).

How each added scenario is re-checked (run what → read which part → expected value):

| Scenario | Run | Read | Expected |
|---|---|---|---|
| A seat clue in the main worktree refuses instead of claiming `pm` | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null`; `bash skills/teamsmith/tests/flip-p201.sh` | the `P201 ①` assertions; the shadow's red lines | green; under shadow A the refusal assertions are red (non-zero, zero writes, both names, both ways out) |
| The window clue is the caller's own pane, not the client's current window | section 47; the policy's shim log | `P201 ① 窗口名问的是调用者自己那块 pane` | green (`-t %4242` on the shim's log); a target-less read reddens it |
| An inherited roster name refuses the main worktree's call | section 47; `flip-p201.sh` | the `P201 ②` assertions | green; red under shadow A |
| A name outside the roster is not a clue | section 47 (extended in 2.1); `flip-p201.sh` (shadow B, 2.2) | the new `P201 ③` assertions | green; red under shadow B (membership test dropped) |
| Another session's window of the same name is not a clue | section 47 | `P201 ③ 别的会话` | green; stays green under shadow A (the control) |
| An explicit `--from` is still honoured with a seat clue present | section 47 (extended in 2.1); `flip-p201.sh` (shadow C, 2.3) | the new `P201 ③` assertion | exit 0, `agent:dev3`, stderr names the disagreement; red under shadow C |
| A seat worktree is not refused by a roster clue | section 47 (extended in 2.1); `flip-p201.sh` (shadow D, 2.4) | the new `P201 ③` assertion | exit 0, `agent:dev2`, stderr names the ignored value; red under shadow D |

## 1. R1 · the contract text (`notify-and-inbox`)

- [x] 1.1 re-baseline the delta against the spec this apply will actually replace. Extract both requirements and
  diff them:
  `awk '/^### Requirement: A manual notification is attributed/{f=1} f && /^### Requirement: A wake is at most once/{exit} f{print}' openspec/specs/notify-and-inbox/spec.md > /tmp/p204-base.md`
  and `sed -n '/^### Requirement: A manual notification is attributed/,$p' openspec/changes/sender-identity-refusal/specs/notify-and-inbox/spec.md > /tmp/p204-delta.md`, then `diff /tmp/p204-base.md /tmp/p204-delta.md`.
  Read: the hunks are exactly the intended rewrites (the runtime-directory bullet, the `TEAM_AGENT` sentence,
  and one new paragraph) plus the appended scenarios. If another change archived a modification of this
  requirement in the meantime, its sentences are folded in here — an unexpected hunk is a merge, never noise.
  The eleven baseline scenarios must survive as the baseline's own text.
- [x] 1.2 the scenario inventory, both directions:
  `diff <(awk '/^### Requirement: A manual notification is attributed/{f=1} f && /^### Requirement: A wake is at most once/{exit} f{print}' openspec/specs/notify-and-inbox/spec.md | grep '^#### Scenario:' | sort) <(sed -n '/^### Requirement: A manual notification is attributed/,$p' openspec/changes/sender-identity-refusal/specs/notify-and-inbox/spec.md | grep '^#### Scenario:' | sort)`.
  Read: no `<` line (nothing dropped), exactly seven `>` lines (the additions), eleven titles on both sides.
  Red side (never on the real tree): delete one baseline scenario from a scratch copy of the delta and run
  `openspec validate` there — it fails naming the omitted scenario (`trial.sh` step 2 does this).
- [x] 1.3 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` — green, and
  `PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check` names no undeclared reference
  (the walk judges the delta as the effective text).

## 2. R1 · falsifiability of the new clauses (`skills/teamsmith/tests/**`)

The three "nothing yet" rows of `design.md` §5 are this section's work. Fixtures only: no real tmux is needed
(the section's `tmux` is a shim), and nothing here writes outside the suite's own scratch root.

- [x] 2.1 `skills/teamsmith/tests/smoke.sh` section 47 case ③ (the no-misfire direction) gains the four runs the
  delta's added scenarios pin but the block does not exercise yet: the main checkout with a window named
  `nosuch` (non-roster) → exit 0 and `agent:pm`; the main checkout with `TEAM_AGENT=nosuch` → exit 0 and
  `agent:pm`; the `dev2` worktree with `TEAM_AGENT=dev3` (a roster seat) → exit 0 and `agent:dev2` with stderr
  naming the ignored value; the main checkout with the `dev` window clue and `--from dev3` → exit 0 and
  `agent:dev3` with stderr naming the disagreement with `pm`. Verify:
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null` green, and each new assertion
  reddens under its shadow (2.2–2.4).
- [x] 2.2 `skills/teamsmith/tests/flip-p201.sh`, shadow B: drop the roster membership test in
  `team_sender_seat_clues` (a non-empty window name or `TEAM_AGENT` becomes a clue). The two new non-roster
  assertions of 2.1 must be red, cases ①② must stay red-capable (they still refuse), and the restore must be
  green. This is the red side of "a name outside the roster is not a clue".
- [x] 2.3 shadow C: move the clue refusal above the explicit-claim branch (`--from` no longer wins). The new
  `--from dev3`-with-a-clue assertion must be red (the call refuses instead of recording `agent:dev3`), the
  no-clue runs must stay green, and the restore must be green.
- [x] 2.4 shadow D: drop the refusal's directory precondition (`[ "$dir" = "pm" ]`) so it fires from any
  directory. The new worktree assertion must be red (the `dev2` call refuses instead of recording `agent:dev2`);
  the mutation is deliberately broad, so other worktree-with-clue assertions may redden too — the criterion is
  that the new assertion is among them and the restore is green.
- [x] 2.5 `bash skills/teamsmith/tests/flip-p201.sh` (all shadows) reports its two-sided result and exits 0;
  `bash skills/teamsmith/tests/section-guard.sh --budget-check` and `--loop-check` are green (section 47's row
  keeps `band_s >= max(host, container, ci)`; re-measure the row only if the added assertions exceed the band of
  2 s / budget 60 s, and only in `section-budgets.tsv`), and `bash skills/teamsmith/tests/section-select.sh --check` is green.

## 3. R1 · the archive shape (`notify-and-inbox`)

- [x] 3.1 `bash docs/team/reports/P204-dev2/trial.sh` — all three trials green, i.e. the delivered tree
  validates; a scratch copy with one baseline scenario deleted fails naming it; a scratch
  `openspec archive -y sender-identity-refusal` reports `~ 1 modified`, validates green afterwards, and the
  archived base requirement holds 18 scenarios with the refusal paragraph present and the retired sentence gone.
- [x] 3.2 the same scratch tree holds `openspec/changes/archive/<date>-sender-identity-refusal` and no unarchived
  change directory, and the real `openspec/specs/**` is byte-identical to its pre-trial content (`git status`
  clean for it).

## 4. Gates

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` — green.
- [x] 4.2 `PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check` — green.
- [x] 4.3 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` — green.
- [x] 4.4 the full suite in the disposable container (never the shared tmux server):
  `distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -v "$PWD":/work -w /work localhost/teamsmith-gate:local bash -c 'git config --global --add safe.directory /work; bash skills/teamsmith/tests/smoke.sh </dev/null'`
  — green; a panel timing section that reddens on load records its load (its premise governs).
  **P208 ran no full suite (no log attached): the full run belongs to the PM's final release gate.** This tick
  rests on the apply's own two container full runs — 4566 ✓ 0 ✗ in `docs/team/reports/P205-dev/44-container-full.log`
  and `45-container-full-delivered-tip.log`.

## 5. Record

- [x] 5.1 `docs/team/reports/<ID>-<agent>.md`: the 1.1 diff hunks, the 1.2 title diff (11/18, the seven
  additions named), the 2.2–2.4 shadow outputs (red before, green after), the three trial logs, the four gate
  tails, the delta→scenario map, the exact changed-path list, and what was **not** tested (no real tmux: the
  section shims it; no model call).
- [x] 5.2 the flip evidence is pasted, not summarized: for each shadow, the red lines naming the new assertions
  and the green restore run.

## 6. Path grants the apply brief must state

- The delta: `openspec/changes/sender-identity-refusal/specs/notify-and-inbox/spec.md` (this change's only delta;
  no other unfinished task of this change writes it).
- Agent-owned: `skills/teamsmith/tests/smoke.sh`, `skills/teamsmith/tests/flip-p201.sh`, and
  `skills/teamsmith/tests/section-budgets.tsv` (only if 2.5's measurement requires it).
- `docs/team/reports/<ID>-<agent>.md` and `docs/team/reports/<ID>-<agent>/**`.
- Untouched: `skills/teamsmith/scripts/**` (the behaviour is shipped; a contradiction between the delta and the
  code is a `BLOCKED:` for the PM, not a code edit), `skills/teamsmith/references/**` (P201 updated the prose),
  `openspec/specs/**` (written by the archive only), and the `meeting` capability.
