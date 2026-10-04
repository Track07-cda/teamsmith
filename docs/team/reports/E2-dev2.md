# E2 · dev2 · exploration report: scope and split for change C1 `launch-and-adapter-evidence`

```
task:   E2                       phase:  explore        deps: E1 (inventory, accepted: D15), v1.29.0
agent:  dev2                     status: DELIVERED (report only)
```

This is the **explore** phase artifact for the second change. It opens no change, edits no spec and touches no code:
the only file this task wrote is this report. Scope, boundaries and acceptance come from
`docs/team/tasks/E2-explore-c1-scope.md`.

How to read it: written in English (`openspec/config.yaml`). Chinese CLI output is quoted **verbatim**. Every
verdict carries the path/line or the command I ran; §1.3 says which of E1's and the brief's statements I could not
reproduce. Where I say "falsifier", I mean *the command/assertion that already goes red if the behaviour breaks*.

---

## 1. Baseline, method, and three corrections

### 1.1 The tree this report was written against

```console
$ git log --oneline -1
63e0bcf docs(team): M9.3 gains the ambiguous-task-id rule (found while renaming V1.1 to V2)
$ git rev-list --count main ^HEAD        # main is two doc commits ahead of this branch
2
$ git log --oneline main ^HEAD
9a2d3cf docs(team): queue M9.5 — a verify task's record is bound to the reviewed revision, not the verifier's branch
8877203 docs(team): start the second change's pipeline — E2 explores C1 (launch-and-adapter-evidence)
$ git tag | tail -2                      # the CHANGELOG is at v1.29.0; the tags stop at v1.26.0
v1.25.0
v1.26.0
```

So: the skill is at the v1.29.0 content, the specs are **exactly** the M5.2 set (45 requirements / 77 scenarios;
unchanged since v1.19.0, corroborated by E1 §1 and re-checked here — `git diff --name-status v1.27.0..HEAD --
openspec/` is impossible because that tag does not exist in this clone; the M5.3 lint still reports the same counts).

```console
$ openspec list --specs
Specs:
  board-and-status     requirements 6
  boundary             requirements 5
  dispatch             requirements 6
  meeting              requirements 6
  memory-and-deps      requirements 4
  notify-and-inbox     requirements 6
  verification         requirements 6
  watchdog             requirements 6
$ openspec list
No active changes found.
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 8 spec file(s), 45 requirement(s), 77 scenario(s) under openspec     # rc=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # baseline only
== 结果 ==  ✓ 940  ✗ 0                                                            # rc=0, 13 real-process sections skipped
```

### 1.2 Method

E1's inventory rows are the input (`A1, A2, D1–D4, W1–W3`), not a fresh survey. For each row I re-read, at
`63e0bcf`, (a) the code that ships it, (b) the smoke assertion that is its falsifier, (c) whether any spec text
already promises it. The pipeline behaviour (delta operations, ordering, archive results) was probed in **scratch
copies under `/tmp`** (`cp -r openspec /tmp/e2-*`; the repo's `openspec/` was never written). The C0 delta gate was
run against those copies with the copy of the checker from the P2.1 branch
(`git show task/P2.1-apply-rework-close-v1-findin:skills/teamsmith/tests/spec-lint.sh`), because that is the gate
C1 will actually meet — see §1.3(1).

### 1.3 Three corrections

1. **C0 is not in main, and not in this tree.** The brief says "the open changes (C0 is one of them until it
   archives)". Here `openspec list` prints *No active changes found*: `openspec/changes/` does not exist in main at
   all. The C0 artifacts live only on `task/P1-…`, `task/P2-…`, `task/P2.1-…`; the branch tip of P2.1 is not an
   ancestor of main:

   ```console
   $ git ls-tree --name-only main openspec/
   openspec/config.yaml
   openspec/specs/board-and-status/spec.md
   … (specs only; no changes/)
   $ for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
       n=$(git ls-tree -r --name-only "$b" openspec/changes/ 2>/dev/null | wc -l); [ "$n" -gt 0 ] && echo "$b: $n"; done
   task/P1-propose-spec-delta-gate-c0-g: 5
   task/P2-apply-spec-delta-gate-c0-che: 5
   task/P2.1-apply-rework-close-v1-findin: 5
   $ git merge-base --is-ancestor ca05f30 HEAD && echo yes || echo no     # the spec-lint delta rules
   no
   ```

   Consequence for C1 (detailed in §7.1): **the base of C1's propose/apply is a decision, not a given**, and
   `bash skills/teamsmith/tests/spec-lint.sh` in a main-based tree does not yet check deltas.

2. **E1's W2 state list is wrong on one word.** E1 §3.1 C says six states `starting/running/busy/idle/foreign/unknown`.
   The shipped vocabulary is `running/starting/idle/unknown/foreign/missing`, and the reason-document says so out
   loud: `references/protocol.md:164` — "`busy` is not a liveness state of its own … the internal pane-busy probe is
   only used to tell an empty prompt (`idle`) from an occupant (`unknown`)". `grep -rn 'busy:' skills/teamsmith/scripts/`
   → no hits. The propose phase must name `missing`, not `busy` (evidence: `team_pm_state()` in `common.sh`, which
   prints exactly those six values, and `team_pm_alive()` which accepts only `running:*`).

3. **E1's report itself is not in main.** `git ls-tree -r --name-only main -- docs/team/reports/ | grep E1` → nothing;
   the file exists only on `task/E1-explore-spec-backfill-m6-m8-` (3fbc10d). D15 cites `docs/team/reports/E1-dev2.md`
   as its evidence, but a fresh worktree cut from main cannot read it. I read it from the branch
   (`git show task/E1-…:docs/team/reports/E1-dev2.md`). Either the PM folds it into main or the branch is the
   archive of record — but the C1 briefs should not require an agent to discover a branch to find their input.

---

## 2. Row-level scope

E1's C1 set is `D1–D4 + A1–A2 + W1–W3` (9 requirements, E1 §5.1). I checked each row against the code, the smoke
falsifier and the current spec text; **no row leaves C1**. Verdicts, with the delta operation each row needs:

| row | what it pins (shipped) | capability · delta op | verdict + reason |
|---|---|---|---|
| **A1a** engine | placeholder set, malformed/whitespace-only/multi-line rejection, out-of-band prompt | `agent-adapters` · **REMOVED** from `dispatch` + **ADDED** (migrated) | keep — the engine is shared with the PM side (A2); leaving it in `dispatch` forces a second copy of the placeholder list into any PM capability (E1 §3.1 B, confirmed) |
| **A1b** first word | template first word resolved on the caller's `PATH` → absolute path; `TEAM_AGENT_BIN`/`TEAM_PM_BIN` override; unresolvable = fail before a window opens | `agent-adapters` · **ADDED** | keep — this is C1's other core subject ("by which binary did it start"); today no spec records it |
| **A2** PM side | `TEAM_PM_CMD`/`TEAM_PM_BIN`/`{resume_args}`; all empty = built-in Pi path unchanged; malformed loud; empty resume reported honestly | `agent-adapters` · **ADDED** | keep — same engine and the riskiest regression surface (byte-identical default); it must be pinned in the change that moves the engine |
| **D1** branch guard | a worktree parked on **another task's** branch is refused, naming both branches + the exact `git switch` line (F16) | `dispatch` · **MODIFIED** ("One task branch per task": restate both base scenarios + add this one) | keep — same delta file C1 already opens for D3/D4; no other change owns `dispatch`; moving one row out would spawn a fifth change |
| **D2** brief boundary | a brief outside the project's main worktree is refused, `--print` included (F15) | `dispatch` · **MODIFIED** ("A brief is self-contained…": restate both base scenarios + add this one) | keep — same file, same family ("refuse a dispatch that cannot be honest about what it runs") |
| **D3** launch proof | `proof=spawn` (pid alive **and** cwd in-project); "harness came up" ≠ "agent came up"; exit read from the event file `state/dispatch-<agent>.exit`; failure keeps `state/dispatch-<agent>-launch-failed.log` and exits non-zero | `dispatch` · **ADDED** | keep — C1's core subject; the largest false-green cluster in the recent history |
| **D4** session window | reused session size vs the selected model's window; refuse with `--fresh`/`--allow-overflow`; `TEAM_MODEL_WINDOWS`; `roster`/`ps` show `used/window` | `dispatch` · **ADDED** | keep — the other "refuse **before** opening a window" promise; same falsifier section (§6h A1–A9) |
| **W1** PM liveness | running = positive proof only (`state/pm.pid` alive + in-project cwd, or the configured binary in the window); read-only commands never clear it; `team up` skips a proven PM | `pm-lifecycle` · **ADDED** | keep — same evidence chain as D3 (`pm.pid.spawn`/`proof=spawn`), other side of the relation; `watchdog` stays about *when to wake* |
| **W2** `starting` | the state between "decided to start" and "proof landed"; six-value vocabulary; one tick never starts a second PM | `pm-lifecycle` · **ADDED** | keep — `starting` is what makes the liveness proof meaningful ("no evidence yet" ≠ "no PM"); a separate change would duplicate D3's spawn-proof context or have to be based on C1 anyway. **Name `missing`, not E1's `busy`** (§1.3-2) |
| **W3** reload honesty | `team reload`'s marker is bookkeeping; **no component restarts the session because of it** (F23) | `pm-lifecycle` · **ADDED** | keep, with a caveat — see below |

**W3 caveat.** It is the only C1 row whose evidence chain is *not* launch/liveness: it is a claim-vs-mechanism row
(falsifier: `smoke.sh:3028-3029`, §11h). Recommendation: keep it (one row, existing falsifier, D15's assignment
unchanged) and mark it in the verify record as outside the injection matrix. If the PM wants C1's verify contract to
be *purely* the injection matrix, W3 is the row to move to C3 (`ledger-and-channel-honesty`) — the cost is that C3
gains a 4th delta file and must be based on a tree where C1 has already archived.

### 2.1 Deliberately out of scope (the anti-widening fences)

- **A general `pm-lifecycle` CLI spec.** E1 §3.1 C says the new capability "becomes the natural home for `team up` /
  `team resume` semantics". Those commands were never inventoried as rows; C1 specs only the *liveness* and
  *starting* promises (`W1`, `W2`). Writing a full `team up`/`team resume` contract here is the most likely way to
  widen C1.
- **A `watchdog` delta.** `openspec/specs/watchdog/spec.md:93` points at "the PM's calls (`team up`, `team resume`)";
  the pointer stays true after C1, and adding a watchdog delta would add a 4th capability file for a
  cross-reference. No watchdog change in C1.
- **Rows that belong to other changes**: `B1–B9`, `N1–N3`, `M1–M2` (C3), `V1–V7` (C2), `G1–G2` (C0, G2 explicitly
  deferred by C0's own boundary).
- **Prose**: M7.1 migration guidance, M7.3 English invariant/installer, M9.1 process contract, F22's limitation,
  F20's rationale (E1 §3.3 — the gate already falsifies the enforceable halves).

---

## 3. Options for the split

All three options share the same **propose** artifact (one change, three delta files) and the same **archive**
(PM, after the user's confirmation). They differ in the apply/verify slicing.

| option | tasks | delta files touched | verify phase | failure modes |
|---|---|---|---|---|
| **A. E1's worker/PM split (2 apply briefs)** | 4 + archive | `dispatch`, `agent-adapters`, `pm-lifecycle` | 2 records, cross-verified | **two writers on one change dir**: the `agent-adapters` delta file is written by brief 2 (worker engine) *and* brief 3 (PM side), so the briefs must be strictly sequential (each based on the previous tip, D16); the two verify slices cannot be independent — the move is atomic across two delta files, so both verifiers essentially re-run the same gate on the same final tree |
| **B. one apply brief (recommended)** | 3 + archive | same 3 | 1 record, one owner | the apply brief is the largest single artifact of the program (~9 requirements / 3 files) and must carry the two flips (§6); mitigations: the brief's acceptance is the unchanged gate + the C0 lint, and the move is one atomic artifact, which is what makes it reviewable |
| **C. three apply briefs, one per capability file** | 5 + archive | same 3 | 3 records | the `REMOVED` (dispatch) and the migrated `ADDED` (agent-adapters) land in **different** briefs: between them the change still passes both gates while a promise is deleted — the gate cannot see a move (§4.4). Rejected |

**Recommendation: option B.** Reasons, in order: (1) the change is a *document* change; its only atomic unit is the
move, and the move spans two delta files; (2) one writer per change dir removes the rebase/rewrite hazard option A
accepts for no parallelism gain (D16 serializes it anyway); (3) the verify phase is one record with one contract
(§6), which is easier to attack than two half-records; (4) the roster still satisfies the pipeline rules
(propose ≠ apply ≠ verify).

### 3.1 Recommended tasks

| task | phase | owner | deps | hand-out / acceptance |
|---|---|---|---|---|
| `C1.1` | propose | dev2 | C0 wrapped up **or** the C1 base decision from §7.1; the temporary grant of `openspec/changes/launch-and-adapter-evidence/**` | `proposal.md`, `tasks.md`, `specs/{dispatch,agent-adapters,pm-lifecycle}/spec.md`; acceptance `openspec validate --all --strict` + the C0 lint |
| `C1.2` | apply | dev | PM's `docs/team/reviews/launch-and-adapter-evidence-proposal.md` = **ACCEPTED**; branch cut from `C1.1`'s tip | the three delta files landed; acceptance = full gate (not `TEAM_SMOKE_FAST`) + the two flips of §6 |
| `C1.3` | verify | verify | `C1.2` landed; own checkout (`team review C1 --dir … --strong`) | `docs/team/reviews/C1.md`; the three-layer package of §6, including the migration diff and the injection matrix (own probes, not the applier's) |
| `C1.4` | archive | PM | `C1.3` PASS + the user's confirmation | `openspec/changes/archive/<date>-launch-and-adapter-evidence/`; specs for `dispatch`, `agent-adapters`, `pm-lifecycle` |

One board caveat: `C1.1`'s propose branch must carry C0's change artifacts only if the PM picks base option (b) in
§7.1; either way the *apply* branch is based on the propose tip (D16).

---

## 4. The structural decision to settle before propose: the `dispatch` → `agent-adapters` move

**Decision: yes.** `agent-adapters` becomes a new capability (same name as the reference doc), the requirement
"The adapter template contract is enforced, not guessed" is **REMOVED** from `dispatch` and re-created in
`agent-adapters` as the migrated engine requirement. The PM side then extends the same capability without a second
copy of the contract.

### 4.1 The delta operations, exactly

`openspec/changes/launch-and-adapter-evidence/specs/dispatch/spec.md`

- `## REMOVED Requirements` → `### Requirement: The adapter template contract is enforced, not guessed` with
  `**Reason**:` (the contract is shared with the PM's own adapter) and `**Migration**:` (restated and extended in
  `agent-adapters`). The CLI's own guidance says **MUST** include both
  (`openspec instructions specs --change <id> --json`); the archive tolerates their absence (probe 6), so this must
  be a brief requirement, not a hope.
- `## MODIFIED Requirements` → D1 and D2, each restating the **whole** base requirement block (all base scenarios +
  the new one). The C0 checker enforces the restatement (`delta-dropped-scenario`); archive replaces the whole
  block, so anything not restated is silently deleted.
- `## ADDED Requirements` → D3 and D4 (new promises, one scenario minimum each).

`…/specs/agent-adapters/spec.md`

- Must open with `## Purpose` (50+ chars) — the first block, before the delta headers — then
  `## ADDED Requirements` **only**. A new capability accepts neither `MODIFIED` nor `RENAMED` (§4.3). The migrated
  engine requirement goes here **with its full scenario set** (4 scenarios at HEAD), plus A1b (first word) and A2
  (PM side).

`…/specs/pm-lifecycle/spec.md`

- Same shape: `## Purpose` + `## ADDED Requirements` only (W1, W2, W3).

### 4.2 Ordering: it does not matter (tested)

Both scratch probes carried the same three sections with content in different orders:

| probe | section order in the `dispatch` delta | `validate --all --strict` | C0 lint | `archive` result |
|---|---|---|---|---|
| in-order | REMOVED, MODIFIED, ADDED | 9 passed / 0 failed, rc=0 | OK — 11 files, 53 requirements, 90 scenarios | `dispatch: update +2 ~1 -1`; `agent-adapters`/`pm-lifecycle`: create `+2`; `Totals: + 6, ~ 1, - 1, → 0` |
| reordered | **ADDED, MODIFIED, REMOVED** | 9 passed / 0 failed, rc=0 | OK — same counts | identical output; the resulting `dispatch/spec.md` is **byte-identical** to the in-order probe (`diff` → no output) |

What *does* matter is which section a requirement sits in — the checker parses `ADDED`/`MODIFIED`/`REMOVED`/`RENAMED`
by header, and a requirement under the wrong header fails applicability. The order of the three files
(`agent-adapters` created before/after `dispatch` updated) is irrelevant: archive processes each capability file
independently (`Specs to update:` lists all three in one pass).

### 4.3 Why not `RENAMED` (and why MODIFIED cannot express a move)

A cross-capability move cannot be a rename: `RENAMED` is same-capability only, and a delta against a capability with
no base spec may only add. Probed on scratch copies:

```console
$ openspec validate --all --strict          # RENAMED block in specs/agent-adapters/spec.md
Totals: 9 passed, 0 failed (9 items)        # validate is green — the name-class hole C0 closes
$ bash spec-lint(p2.1) /tmp/e2-p2/openspec
…/specs/agent-adapters/spec.md:3: delta-operation-on-new-capability: RENAMED is not allowed for a capability with no base spec: The adapter template contract … -> The launch-template contract …
spec-lint: FAIL — 1 violation(s)                                    # rc=1
$ openspec archive -y probe-renamed
agent-adapters: target spec does not exist; only ADDED requirements are allowed for new specs.
Aborted. No files were changed.

$ openspec validate --all --strict          # MODIFIED block in specs/agent-adapters/spec.md (RFC-2119 clean)
Totals: 9 passed, 0 failed (9 items)        # same hole
$ bash spec-lint(p2.1) /tmp/e2-p8/openspec
…:3: delta-operation-on-new-capability: MODIFIED is not allowed for a capability with no base spec: …
```

So the move **must** be `REMOVED` (dispatch) + `ADDED` (agent-adapters). Note the C0 gate is what makes the wrong
shape fail at gate time; `validate` alone would have let it through to archive.

### 4.4 Numbering, cross-references, and the one thing no gate checks

- **Numbering**: requirements are identified by **name**, not number, and the specs carry no numbering. Removing one
  from `dispatch` renumbers nothing; the surviving requirements keep their order (`dispatch` went 6 → 7 in the probe:
  the modified one stayed in place, the two new ones appended).
- **Cross-references**: `grep -rn "The adapter template contract is enforced" .` finds the requirement only in
  `openspec/specs/dispatch/spec.md` — no other spec, reference, template or doc cites it by name, so the move breaks
  no pointer. `references/agent-adapters.md` is the reason-document and is already the capability's namesake.
- **`## Purpose` cannot be edited by a delta.** The delta format has no Purpose operation (the CLI guidance: "Do NOT
  add `## Purpose` to a delta for an existing capability … To change an existing capability's Purpose — including a
  leftover TBD placeholder — edit `openspec/specs/<capability-path>/spec.md` directly"). `dispatch`'s Purpose is
  generic and stays true after the move — leave it alone (direct spec edits are archive's job).
- **The blind spot the gate cannot see**: `REMOVED` + `ADDED` is indistinguishable from a *deletion* to every
  mechanical check. The C0 gate verifies an `ADDED` requirement has ≥1 scenario, not that the migrated requirement
  kept **all** of the base's scenarios or its exact text. Probe: a move whose migrated block silently dropped one of
  the base's four scenarios is validate-green, lint-green and archive-green. The migration diff in §6.2 is the only
  check for this, and it must be in the verify package (and in the PM's proposal review).
- **Purpose-less new capabilities leave a `TBD` in the spec**: a new-capability delta without `## Purpose` archives
  fine and writes
  `## Purpose\nTBD - created by archiving change probe-nopurpose. Update Purpose after archive.` while both gates
  stay green (probe 5). The C1 apply must include Purpose in both new-capability deltas, and the verify must grep for
  `TBD - created by archiving`.

---

## 5. Falsifiability: which requirements can be stated today

Every C1 row already has a **runnable** falsifier — C1 adds no test code (E1 §6.2's two rows that need a new assertion each
are C3's B2/F24 half and G2, which C0's own boundary deferred to a separate change — none is C1). What follows is the
scenario→falsifier table the apply brief and the verify record should carry.

| requirement (row) | falsifier that exists at `63e0bcf` | observable through |
|---|---|---|
| `dispatch` MODIFIED · brief boundary (D2) | `smoke.sh:477-481` §6 — `F15：项目外任务书被拒（--print 也不放行）`, `F15：报错说明任务书在项目外` | `team dispatch … /tmp/outside.md --print` → rc≠0 + message |
| `dispatch` MODIFIED · branch guard (D1) | `smoke.sh:448-468` §6 — `F16：工作树停在别的任务的分支上 → dispatch 拒绝`, `F16：给出 PM 该跑的 git switch 命令` | park a worktree on another task's branch, dispatch → rc≠0 |
| `dispatch` ADDED · launch proof (D3) | §6h `1024+`: `B1：标题就是「未能确认启动」（不是成功）` (`:1144`), `B2：启动证据落盘（state/dispatch-dev.spawn）` (`:1185`), `B3：退出证据落盘（state/dispatch-dev.exit）` (`:1202`), `B3：通知报出的是真实退出码` (`:1203`), `B4a：旧 nonce 的退出记录不算本轮证据` (`:1165`); §6j `M8.2：失败文案报出真实退出码（exit=7）` (`:1714`), `…给出诊断文件路径` (`:1715`) | wedged pane / adapter that exits 7 |
| `dispatch` ADDED · session window (D4) | §6h `A1`–`A9` (`:1024+`): `M4.3 A1：大会话 + 小窗口模型被拒`, `A4 --allow-overflow`, `A5 --fresh`, `A6` conservative threshold (`:1090`), `A7 TEAM_MODEL_WINDOWS`, `A9 roster 显示 400k/272k` | `team dispatch` on a fixture session + `TEAM_MODEL_WINDOWS` |
| `agent-adapters` migrated engine (A1a) | the base spec's own 4 scenarios have direct CLI falsifiers (`TEAM_AGENT_CMD='myagent {sessionid} {prompt}' … --print`), plus §6f/§6g/§6j | `--print` renders / rc≠0 |
| `agent-adapters` ADDED · first word (A1b) | §6j (`:1650`) `M8.2：裸名字被换成调用者 PATH 解析出的绝对路径`, `…已经是绝对路径的首词原样保留`, `…TEAM_AGENT_BIN 指向别的名字时不改模板首词`; §6i (`:1337`) `裸名字被换成调用者 PATH 解析出的绝对路径（登录 bash 里没有它）` | a fake CLI only on the caller's `PATH` |
| `agent-adapters` ADDED · PM side (A2) | §6i (`:1255+`): `M8.1 默认渲染与历史逐字节一致（TEAM_PM_CMD/BIN/RESUME_ARGS 全空）` (`:1282`), `坏 PM 模板 → 直接失败`, `找不到 PM 可执行文件` (`:1395`), `自定义 CLI + 空 resume 参数 → 明确报「不延续」`, real window `非 Pi PM 被拉起` / `假 PM 在窗口里真的跑起来了` | render + real window (fake PM) |
| `pm-lifecycle` ADDED · liveness (W1) | §11b2 (`:2361+`): `M6.5 ①：不再把 tmux 自己报成运行中的 PM` (`:2374`), `①b 前台是 tmux 也不压制启动` (`:2397`), `② 记录的 pid 死了 → 不再算存活` (`:2408`), `④ up 明确拒绝覆盖外来进程` (`:2445`), `F30：启动证据就是 spawn` (`:2465`) | real tmux window + fake pi |
| `pm-lifecycle` ADDED · starting (W2) | §11b3 (`:2497+`): `第二拍没有重复拉起` (`:2550`), `重启配额只记 1 次` (`:2554`), `启动标记用完就撤`, `手动落下的启动标记 → team_pm_state 报 starting:*` (`:2599`) | two watchdog ticks during a start |
| `pm-lifecycle` ADDED · reload (W3) | §11h (`:3028-3029`): `F23：不再承诺 watchdog 会重启 PM 会话`, `F23：明说 marker 不会重启任何东西` (`team reload` writes `state/reload-requested`) | `team reload` output |

**The one promise that cannot be a plain CLI scenario: A2's "the default Pi path is byte-identical".** It is a
statement about a *rendered command*, and the existing proof (`smoke.sh:1282`) compares the implementation's
`team_pm_launch_cmd` output against a literally hardcoded legacy string — a library-level render, not a CLI surface.
`openspec/config.yaml` forbids internal function names in specs ("internally observable behaviour (commands, exit
codes, files on disk), never internal function names"), so the scenario must be phrased at an observable end.
Recommended reading (one scenario, marked as needing a real window, per the config's `tasks` rule):

> **Scenario: the empty keys keep the built-in launch path**
> **GIVEN** `TEAM_PM_CMD`, `TEAM_PM_BIN` and `TEAM_PM_RESUME_ARGS` are empty
> **WHEN** `team up` starts the PM in a fixture project
> **THEN** the process recorded in `state/pm.pid` has the built-in argv
> (`<TEAM_PI_BIN> --provider <p> --model <m> --skill <skill dir> -c @<state>/pm-prompt.md`) and no `{` token, and
> `team paths` / `team doctor` report the adapter as `built-in (Pi) → <path>`

Falsifier: the §11b2 argv assertions plus §6i's `:1282` (the fast net stays the render comparison; the *spec*
scenario is the observable one). Alternative surface if the PM prefers no real-window scenario: tmux's recorded
`#{pane_start_command}` after `team up` — same command, read from tmux instead of `ps`. What the scenario must **not**
do is name `team_pm_launch_cmd` or compare against a test-only reference string; and if neither observable surface is
acceptable, the honest move is to keep the byte-identical promise as **prose in `references/agent-adapters.md`** (it
is already documented there) instead of inventing a scenario that cannot be run from outside.

Second correction for the propose phase: W2's six states are `running/starting/idle/unknown/foreign/missing`
(§1.3-2). A scenario asserting a `busy` state would be unfalsifiable *and false*.

---

## 6. What the verify phase must do for C1

For C0 the strongest check was a differential matrix against `openspec archive` (the gate's own promise was parity).
C1 needs a different angle, for a structural reason: **a backfill ships no behaviour, so the project's whole test
suite is green both before and after the change.** Smoke cannot fail for anything C1 does. The only things that can be
wrong are the documents and their tie to a runnable red — so the verify package must attack exactly those, in three
layers, in this order:

### 6.1 Layer 1 — applicability and archive parity (re-run, not re-derived)

Run the C0 matrix against *this* change: (a) `openspec validate --all --strict` green; (b) the C0 lint green;
(c) `openspec archive -y` on a **scratch copy** of the tree must apply exactly the promised operations
(`agent-adapters`/`pm-lifecycle` created; `dispatch` +2/~1/−1; the *other* specs byte-unchanged apart from the
archive's known blank-line normalization at `## Requirements`); (d) the archived `dispatch` spec must not contain the
removed requirement, and the two new capability files must contain it/their new requirements. C1's delta mix is
mostly REMOVED+ADDED, so this layer is cheap and catches the whole name-class of errors — but note it is
**indistinguishable from a deletion**, which is why layer 2 exists.

### 6.2 Layer 2 — the migration diff (the strongest available check, and C1-specific)

Reconstruct the pre-move requirement from the base commit (`git show <base>:openspec/specs/dispatch/spec.md`) and the
post-move requirement from the scratch archive (`openspec/specs/agent-adapters/spec.md`), and `diff` them. Require
that the only differences are the **declared** additions (the PM-side engine equivalence, the first-word requirement,
the new scenarios) and that **all four** base scenarios of the engine requirement survive, byte-for-byte apart from
whitespace. No gate can see this: `REMOVED` checks nothing, `ADDED` needs one scenario, and archive just concatenates.
For a move-shaped change the migration diff is to C1 what the archive-parity matrix was to C0 — the one check whose
failure is invisible to every automated gate, and therefore the one a verifier must own.

### 6.3 Layer 3 — falsifier injection (no scenario without a red)

For each requirement, break the behaviour the scenario pins in a **scratch copy** (never in the reviewed checkout),
watch the named smoke assertion go red, restore it, watch it go green. One mutation per requirement is enough —
the point is to prove the scenario is falsifiable, not to re-test the tool. Minimum matrix:

| requirement | mutation (scratch copy) | must go red |
|---|---|---|
| D3 launch proof | make the launch-proof wait accept any line in `state/dispatch-<agent>.spawn` (drop the nonce check) | §6h `B1`, `B4a` |
| D3 exit evidence | write `state/dispatch-<agent>.exit` without the current nonce | §6h `B4a`, `B3` |
| D4 session window | compare only when `--allow-overflow` was **not** given, or `>=` instead of `>` | §6h `A1` or `A5` |
| D1 branch guard | skip the "current branch == this task's branch" check | §6 `F16` |
| D2 brief boundary | drop the "brief must live under the main worktree" check | §6 `F15` |
| A1a/A1b first word | render the template's first word verbatim (no `PATH` resolution) | §6j `裸名字被换成…绝对路径`, §6i PM-side counterpart |
| A2 default path | drop the `-c` from the built-in Pi path | §6i `M8.1 默认渲染与历史逐字节一致` |
| W1 liveness | make `team_pm_alive` accept `unknown:*` as alive | §11b2 `①b`, `②` |
| W2 starting | ignore the `state/pm.pid.starting` marker in `team_pm_state` | §11b3 `第二拍没有重复拉起` (a second tick restarts the PM) |
| W3 reload | restore the old "watchdog will restart the PM session" wording | §11h `F23` |

Plus the two document-level guards: the new capabilities' `## Purpose` is not a `TBD - created by archiving` placeholder
(§4.4), and the new specs contain no unfalsifiable scenario (the C0 lint's placeholder rule is the fast net; the
injection matrix is the real one).

### 6.4 The honesty rule for the record

The verify record must name which rows' falsifiers were **not** injected and why. A row whose red was never
demonstrated is a claim, not evidence — and this is the exact failure mode a backfill creates: 9 green gates and no
new test. The strongest available check for C1 is therefore `6.2` (it can catch a real defect) followed by `6.3` (it
proves the rest can fail at all); `6.1` alone would be the false green.

---

## 7. Preconditions and ledger notes for the PM

### 7.1 The C1 base depends on C0, and C0 is mid-flight

E1 §6.5 recommended "C0 applies and archives first"; the roadmap row says C1 is "⏸ 待 C0 收口". Today: P2.1 is `wip`
on the board, V2 is `wip`, the changes dir is on three unmerged branches and main has no delta gate (§1.3-1). Two
legal bases for C1:

- **(a) Wait for C0 to archive and land in main** (recommended): C1's propose branch starts from that main; the gate
  C1 meets is exactly the one that ships. This is the only base where the C0 lint is documented as *the* gate.
- **(b) Base C1 on P2.1's tip** (fallback if the user's confirmation is delayed): C1's branches then contain C0's
  change dir and the new lint; C1's archive still cannot precede C0's (C0's change would be archived first), and
  C0's archive touches only `memory-and-deps`, so C1's deltas are unaffected. The cost: C1's branch is not based on
  the protected branch, and `team review` records the reviewed revision — a merge order problem the PM owns.

### 7.2 `openspec/**` ownership is still not written down

`docs/team/OWNERSHIP.md` does not list `openspec/**`, and its header says unlisted directories are PM-exclusive —
E1 §5.4's precondition is still open. Precedent: P1's brief granted `openspec/changes/spec-delta-gate/**` *inside the
brief* ("You may write only `openspec/changes/spec-delta-gate/**` and your report"). Either repeat that explicit
temporary grant in the C1.1 brief, or add one row to `OWNERSHIP.md` (`openspec/changes/**` → agent:\*, `openspec/specs/**`
→ PM/archive). The second is cheaper across four changes; the file is PM-owned either way.

### 7.3 The gate C1 runs must be the full one, and the tree must have C0's smoke fix

- The 13 sections `TEAM_SMOKE_FAST=1` skips include the only falsifiers for D3/its real-window half, A2, W1 and W2
  (§6h at `:1174`, §6i at `:1428`, §6j at `:1671`, §11b2 at `:2363`, §11b3 at `:2499`). Both the apply and the verify
  brief must require the **full** suite; a fast run proves nothing for these rows.
- `smoke.sh` §16's real-tree count assertion is coupled to the spec-lint counting model. With a C1-shaped change
  active, the P2.1 lint reported `11 spec file(s), 53 requirement(s), 90 scenario(s)`, while the **pre-C0** smoke
  (this tree) computes its expectation from `openspec/specs/*` only → `45/77` → red. The P2.1 smoke already counts
  base + active-change deltas (that is what its `sl_real_files` change is for). So "C0 must land before C1" is not
  only about the delta rules: without it, C1's own gate goes red for an unrelated reason on every run while the
  change is active.

### 7.4 Ledger observations (PM-owned files, not touched)

- E1's report is not in main (§1.3-3). C1's briefs should cite it as a branch artifact or the PM folds it in.
- The E2 brief's acceptance note ("C0 is one of them until it archives") predates this tree state; the observable
  fact is `openspec list` → *No active changes found*.
- `dispatch` will grow 6 → 7 requirements, `board-and-status` is untouched by C1 (E1 §6.7's file-size worry is a
  C3 concern, not C1's).

---

## 8. Acceptance (the brief's commands, verbatim)

```console
$ openspec list --specs
Specs:
  board-and-status     requirements 6
  boundary             requirements 5
  dispatch             requirements 6
  meeting              requirements 6
  memory-and-deps      requirements 4
  notify-and-inbox     requirements 6
  verification         requirements 6
  watchdog             requirements 6

$ openspec list
No active changes found.

$ git status --porcelain
?? docs/team/reports/E2-dev2.md
```

`openspec` is not on the non-login `PATH` in this container; the commands in this report ran with
`export PATH="$HOME/.bun/bin:$PATH"` (`openspec --version` → `1.8.0`).

## Boundary check

- Files written by this task: this report only. Nothing under `openspec/`, no spec, no code, no ledger file other
  than this report.
- The pipeline probes ran in `/tmp/e2-*` copies (`cp -r openspec …`); the repository's `openspec/` was never written.
  The one repo-level write is `docs/team/reports/E2-dev2.md`.
- No change was opened, no one was dispatched, no other project or tmux session was touched.

## Appendix A · the probes, so they can be re-run

```bash
export PATH="$HOME/.bun/bin:$PATH"
REPO=<home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2
git -C "$REPO" show task/P2.1-apply-rework-close-v1-findin:skills/teamsmith/tests/spec-lint.sh > /tmp/e2-p21-spec-lint.sh

# 1) move shape: REMOVED in dispatch + ADDED in a new capability + MODIFIED + ADDED, one change, three files
rm -rf /tmp/e2-scratch && mkdir -p /tmp/e2-scratch && cp -r "$REPO/openspec" /tmp/e2-scratch/openspec
# (the probe change dir is written by hand: proposal.md, tasks.md,
#  specs/{dispatch,agent-adapters,pm-lifecycle}/spec.md — see §4.1 for the section/op shape)
cd /tmp/e2-scratch
openspec validate --all --strict                      # 9/9, rc=0
bash /tmp/e2-p21-spec-lint.sh /tmp/e2-scratch/openspec # OK 11 files / 53 req / 90 scen, rc=0
openspec archive -y c1-probe                          # +6 ~1 -1, three specs updated, rc=0
openspec list --specs                                 # dispatch 7, agent-adapters 2, pm-lifecycle 2

# 2) ordering: same content, sections ADDED → MODIFIED → REMOVED
#    (rebuilt from the archived dispatch delta with an awk splitter; §4.2 table)
#    → validate 9/9, lint OK, archive +6 ~1 -1, resulting dispatch/spec.md diff vs (1) = empty

# 3) wrong shapes (each on its own fresh copy of openspec/)
#    RENAMED on a new capability   → validate 9/9 green, lint rc=1 delta-operation-on-new-capability, archive aborts
#    MODIFIED on a new capability  → validate 9/9 green, lint rc=1 delta-operation-on-new-capability, archive aborts
#    new capability without Purpose→ archive writes "## Purpose\nTBD - created by archiving change …", gates green
#    REMOVED without Reason/Migration → archives (the CLI tolerates it; its guidance says MUST)
```

## Appendix B · the delta skeleton the propose phase can start from (shape only)

```markdown
# dispatch delta — openspec/changes/launch-and-adapter-evidence/specs/dispatch/spec.md
## REMOVED Requirements
### Requirement: The adapter template contract is enforced, not guessed
**Reason**: the contract applies identically to the PM's own adapter (`TEAM_PM_CMD`); keeping it in `dispatch`
forces a second copy of the placeholder list into any PM capability.
**Migration**: restated (and extended with the PM-side engine) in `openspec/specs/agent-adapters/spec.md`;
no tool behaviour changes.

## MODIFIED Requirements
### Requirement: A brief is self-contained and names its evidence
<whole base block, both base scenarios restated, + the project-boundary scenario>

### Requirement: One task branch per task
<whole base block, both base scenarios restated, + the parked-on-another-task's-branch scenario>

## ADDED Requirements
### Requirement: A dispatch proves the agent started, or fails loudly
### Requirement: A dispatch refuses a session the model's window cannot hold

# agent-adapters delta — …/specs/agent-adapters/spec.md   (new capability: Purpose + ADDED only)
## Purpose
<50+ characters; archive copies it verbatim>
## ADDED Requirements
### Requirement: The adapter template contract is enforced, not guessed   ← migrated, all 4 base scenarios kept
### Requirement: The first word is resolved, not guessed                  ← A1b
### Requirement: The PM side is an adapter too                            ← A2

# pm-lifecycle delta — …/specs/pm-lifecycle/spec.md       (new capability: Purpose + ADDED only)
## Purpose
<…>
## ADDED Requirements
### Requirement: PM liveness is proven, not inferred                     ← W1
### Requirement: A PM that is starting is a state, not a missing PM      ← W2 (states: running/starting/idle/unknown/foreign/missing)
### Requirement: A reload request is bookkeeping, not a restart         ← W3
```
