# E1 · dev2 · exploration report: closing the spec gap (`spec-backfill-m6-m8`)

```
task:   E1                       phase:  explore        deps: v1.27.0
agent:  dev2                     status: DELIVERED (report only)
```

This is the **explore** phase artifact. It creates no change, edits no spec, and touches no code: the only file
this task wrote is this report. Scope, boundaries and acceptance come from
`docs/team/tasks/E1-spec-backfill-explore.md`.

Two notes on how to read it:

- **Language**: written in English because the E1 brief is English and this report is the input to an OpenSpec
  propose phase (`openspec/config.yaml`: "Language: every artifact … is written in English"). Chinese CLI output is
  quoted **verbatim** — do not translate those lines, they are what a reader will see.
- **Verdicts, not conclusions**: every gap row carries the path/line/commit I actually looked at, and the falsifier
  that already makes the behavior observable today. Where I could not determine something, §6 says so instead of
  guessing.

---

## 1. Baseline: the spec set as it stands at v1.27.0

```console
$ openspec --version
1.8.0
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
$ openspec validate --all --strict          # rc=0
✓ spec/board-and-status ✓ spec/boundary ✓ spec/dispatch ✓ spec/meeting
✓ spec/memory-and-deps ✓ spec/notify-and-inbox ✓ spec/verification ✓ spec/watchdog
Totals: 8 passed, 0 failed (8 items)
$ bash skills/teamsmith/tests/spec-lint.sh  # rc=0
spec-lint: OK — 8 spec file(s), 45 requirement(s), 77 scenario(s) under openspec
```

So the gate is **green today**, and the numbers match the brief exactly (8 capabilities / 45 requirements /
77 scenarios). The specs were written in **M5.2** and shipped in **v1.19.0** — the CHANGELOG entry for that release
is the receipt:

```console
$ sed -n '/^## v1.19.0/,/^## v1.18.0/p' skills/teamsmith/CHANGELOG.md | grep -n 'capability 规格\|TEAM_GATES'
10:  8 个 capability 规格（dispatch / verification / board-and-status / watchdog / notify-and-inbox / meeting /
11:  memory-and-deps / boundary）共 45 条需求 / 77 个场景；`openspec validate --all --strict` 已加入 `TEAM_GATES`
```

Everything below landed **after** that, tag by tag (`git tag --sort=-v:refname`):

| tag | commit | batch | spec file touched since v1.19.0? |
|---|---|---|---|
| v1.20.0 | `5cead18`, `3d84df7`, `b853dee` | M6.1 state honesty · M6.2 review evidence · M6.5 proven liveness | no |
| v1.21.0 | `3cda164`, `9eca490` | M6.3 dispatch/notify/boundary · M6.4 digest/version/meeting | no |
| v1.22.0 | `0a8c0bd`, `3ee7c31` | M4.3 signal honesty A–E · M5.3 spec falsifiability lint | 2 scenario lines (`3ee7c31`) |
| v1.23.0 | `54d0c76`, `bf56ee3`, `972e1ca` | M7.1 migration guide · M7.2 watchdog `starting` · M7.3 English invariant | no |
| v1.24.0 | `32a74f6` | M7.5 dispatch exit = event evidence | no |
| v1.25.0 | `3989739` | M8.1 PM-side adapter | no |
| v1.26.0 | `cb885e9` | M8.2 worker bare-name + loud launch failure | no |
| v1.27.0 | `6972575` | M9.1 OpenSpec process guidance | no |

```console
$ git log --oneline v1.19.0..HEAD | wc -l
46
$ git log --oneline v1.19.0..HEAD -- openspec/specs/
3ee7c31 test(teamsmith): a spec lint so "every requirement needs a falsifiable scenario" is enforced (M5.3)
$ git diff --name-status v1.19.0..HEAD -- openspec/
M	openspec/specs/board-and-status/spec.md
M	openspec/specs/memory-and-deps/spec.md
```

Those two files are the **only** spec edits since v1.19.0, and both are that one commit (`3ee7c31`, M5.3, shipped in
v1.22.0): it fixed two *scenario* lines (one had no `WHEN`; one attributed the gate to `openspec validate` instead of
`spec-lint`). The set's size is provably unchanged — verified against the tag itself:

```console
$ for f in $(git ls-tree -r --name-only v1.19.0 -- openspec/specs/); do
    printf '%s r=%s s=%s\n' "$f" "$(git show v1.19.0:$f | grep -c '^### Requirement:')" "$(git show v1.19.0:$f | grep -c '^#### Scenario:')";
  done   # → 6/11, 5/6, 6/14, 6/9, 4/7, 6/9, 6/11, 6/10
TOTAL requirements=45 scenarios=77        # identical to today's numbers
```

So no behavior batch has ever touched a spec: the promise set is exactly what M5.2 wrote, while 46 commits changed
the tool underneath it.

**Two corrections to the brief's premise**, stated plainly because they change the size of the job:

1. The brief lists three batches (M6/M7/M8). **M4.3 A–E also landed after the specs** (v1.22.0, same commit pair as
   the M5.3 lint) and is missing from the specs in the same way. I inventoried it and labelled every row with its
   batch, so the PM can cut it or keep it in one command.
2. **M9.1** (v1.27.0, the OpenSpec guide + the recorded proposal review) is a *process* contract, not a tool
   behavior. My verdict is that it stays in `references/` + the smoke §19 assertion (§3.3), not in a spec.

---

## 2. How the inventory was built

Code/docs side first, specs second — the reverse of "assume it is covered":

```console
# the surface: every config key the skill reads vs. every key any spec names
$ grep -rhoE '\bTEAM_[A-Z0-9_]+' skills/teamsmith/scripts skills/teamsmith/extension \
    skills/teamsmith/references skills/teamsmith/SKILL.md skills/teamsmith/tests | sort -u > /tmp/keys_code.txt   # 115
$ grep -rhoE '\bTEAM_[A-Z0-9_]+' openspec/ | sort -u > /tmp/keys_spec.txt                                       # 33
$ comm -23 /tmp/keys_code.txt /tmp/keys_spec.txt | head -20
TEAM_AGENT_BIN / TEAM_AGENT_LOG_TAIL_BYTES / TEAM_ALLOW_FOREIGN_SESSION / TEAM_BOARD_DONE_FORCE /
TEAM_BOARD_DONE_REASON / TEAM_DISPATCH_VERIFY_SEC / TEAM_MODEL_WINDOWS / TEAM_PM_CMD / TEAM_PM_BIN /
TEAM_PM_RESUME_ARGS / TEAM_REVIEW_ALLOW_IGNORED / TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH /
TEAM_REVIEW_TIMEOUT_GRACE / TEAM_TASK_BRANCH_RESET / …

# the concepts (key names are a proxy; concepts are the real test)
$ for s in pm.pid proof=spawn launch-failed "starting" MODEL_WINDOWS TASK_BRANCH_RESET DONE_FORCE \
    unresolved allow-ignored TIMEOUT_GRACE dispatch-<agent>.exit migration CJK perl; do \
    printf '%-24s %s\n' "$s" "$(grep -ril -- "$s" openspec/specs | tr '\n' ' ')"; done
pm.pid                   (nothing)        proof=spawn       (nothing)
launch-failed            (nothing)        MODEL_WINDOWS     (nothing)
TASK_BRANCH_RESET        (nothing)        DONE_FORCE        (nothing)
unresolved               (nothing)        allow-ignored     (nothing)
TIMEOUT_GRACE            (nothing)        migration         (nothing)
starting                 watchdog/spec.md  “resume”         dispatch + watchdog
squash / upstream        board-and-status  “ignored”        notify-and-inbox (unrelated sense)

# then, per candidate, the owning code and its existing falsifier
$ grep -rn 'TEAM_BOARD_DONE_FORCE'          skills/teamsmith/scripts/lib/common.sh
$ sed -n '1880,1960p'                       skills/teamsmith/scripts/lib/common.sh
$ sed -n '600,680p'                         skills/teamsmith/scripts/lib/cmd-review.sh
$ grep -n 'F16\|F15\|F26\|F18\|F28\|F29\|F13\|F12' skills/teamsmith/tests/smoke.sh
```

and the batch side from the git history the PM itself wrote (`git log --oneline v1.19.0..HEAD`,
`git show <sha> --stat`), not from the CHANGELOG alone.

The `F*` ids below are the V4.0 adversarial-verification findings (`docs/team/reviews/V4.0.md`, §"findings table");
`M6.x`/`M7.x`/`M8.x` are the fix batches. Tags/commits are in §1.

---

## 3. Inventory

### 3.1 Behaviors shipped in M4.3/M6/M7/M8 that **no spec covers** (32 rows)

Legend — **Verdict**: `SPEC` = can be written as a falsifiable scenario, and the listed falsifier already proves it;
`MODIFIED` = the existing spec text is *weaker or wrong* about the shipped rule, so a delta must replace it;
`PROSE` = see §3.3.

#### A. `dispatch` (existing capability)

| # | behavior (one line) | where it lives now (code + evidence I looked at) | Verdict |
|---|---|---|---|
| D1 | `dispatch` refuses a worktree parked on **another task's** branch and prints the exact `git switch` line (F16) | `scripts/lib/cmd-agents.sh:242-257` ("M6.3 F16" comment; compares with `team_branch_for_agent`); smoke `tests/smoke.sh:448-456`; commit `3cda164` (v1.21.0) | SPEC — smoke §6 fails by name (`F16: 工作树停在别的任务的分支上时 dispatch 应当拒绝`) |
| D2 | a brief outside the project is refused, `--print` included (F15) | `cmd-agents.sh` dispatch brief check; smoke `:472-478`; commit `3cda164` | SPEC — smoke `:477` |
| D3 | launch proof: `proof=spawn` (pid alive **and** cwd inside the project), "harness came up" ≠ "agent came up", the agent's exit is read from the **event file** the parent shell writes (`state/dispatch-<agent>.exit`), failure keeps diagnostics in `state/dispatch-<agent>-launch-failed.log` and exits non-zero (M4.3 B, M7.5, M8.2) | `cmd-agents.sh:305-320` (nonce + pane-shell pid), `:318-330` (exit file), `:361-390` + `:556-600` (`exit=N` → `✗ 派单失败：harness 起来了，但 agent 立刻退出了`); smoke `:1164-1167` (§6h) and `:1633` (§6j); commits `0a8c0bd`, `32a74f6`, `cb885e9` | SPEC — smoke §6j label `agent 没跑起来必须响亮失败` |
| D4 | before dispatch: session size vs the model's context window; refuse with `--fresh` / `--allow-overflow`, `TEAM_MODEL_WINDOWS` override, `roster`/`ps` show `used/window` (M4.3 A) | `cmd-agents.sh:266-300`; smoke §6h `:1023-1246` (A1–A9 labels); commit `0a8c0bd` | SPEC — smoke `M4.3 A1：大会话 + 小窗口模型应当被拒` |

#### B. new capability `agent-adapters` (the template engine, both sides)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| A1 | the adapter template engine: the placeholder set, malformed/whitespace-only/multi-line rejection, out-of-band prompt, **and the first word of a template is resolved to an absolute path** (worker `TEAM_AGENT_BIN`, else the template's first word, else `TEAM_PI_BIN`) so `bash -lc`'s thin `PATH` cannot silently skip the CLI (M3.2, M8.1 rework, M8.2) | `common.sh` (`team_pm_bin_path`/first-word resolution used by both sides), `cmd-agents.sh` dispatch; doc contract `references/agent-adapters.md:73-78,165-168`; smoke §6j `:1633` + §6i; commits `3989739`, `cb885e9` | SPEC — smoke §6j `裸名字解析`; the placeholder half is already in `dispatch`, the **resolution half is not written down anywhere in a spec** |
| A2 | the PM side is an adapter too: `TEAM_PM_CMD` / `TEAM_PM_BIN` / `{resume_args}` (`TEAM_PM_RESUME_ARGS`), all three empty = the Pi path byte-identical, malformed PM template fails loudly, and an empty resume setting is reported honestly as "this run does not continue the history" + the handover path (M8.1) | `common.sh:211-217` (keys), `:946-1000` (`team_pm_launch_cmd`, resume args, PM template validation reusing the worker engine), `:1281-1290` (`state/pm-launch-failed.log`); smoke §6i `:1247-1632`; commit `3989739` | SPEC — smoke §6i (`PM adapter … 默认不变 / 模板 / 存活 / 真窗口`) |

**Structural note.** The adapter contract currently lives **inside** `dispatch` (its requirement "The adapter
template contract is enforced, not guessed"). It applies byte-identically to the PM side, so keeping it in
`dispatch` forces a second copy into any PM capability. I recommend a new capability `agent-adapters` (same name as
the existing reference doc), with the `dispatch` requirement **REMOVED + migrated** to it in the pilot change
(OpenSpec supports `## REMOVED Requirements` with Reason/Migration; §4.2 shows a move archives cleanly). Fallback if
the PM wants a minimal pilot: leave it in `dispatch` and let the PM-side requirement cross-reference it — at the
cost of one duplicated placeholder list.

#### C. new capability `pm-lifecycle` (the PM is a process with a lifecycle, not a window)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| W1 | PM liveness is **positive evidence, not inference**: `state/pm.pid` alive **and** its cwd inside this project ⇒ running; a manual start must have the resolved agent binary as the foreground process; read-only commands never clear it; `team up` skips a proven PM and starts one otherwise (M6.5) | `common.sh:619-800` (`PM 存活：是「证明」，不是「猜」`, `:783` resolution order `TEAM_PM_BIN > first word > TEAM_PI_BIN`); smoke §11b2 `:2356-2361` ("空窗 ≠ PM 在运行"); commit `b853dee` | SPEC — smoke §11b2 (`11b2·PM 存活证据链`) |
| W2 | `starting` is a real state: six states (`starting/running/busy/idle/foreign/unknown`), each declared with the evidence used, and a single tick never starts a second PM while one is starting (M7.2) | `cmd-status.sh:170, 263, 442`; smoke §11b3 `:2497`; commit `bf56ee3` | SPEC — smoke `11b3 · 启动中的 PM：一拍只拉起一次` |
| W3 | `team reload`'s claim matches reality: the marker is bookkeeping, **no component restarts the session because of it** (F23) | `cmd-update.sh` (the F23 text change); smoke §11h `:2943`; commit `9eca490` | SPEC — smoke §11h (`信号与承诺的诚实`) |

This capability also becomes the natural home for `team up` / `team resume` semantics, which today exist only as a
pointer in the `watchdog` spec ("Those are the PM's calls (`team up`, `team resume`)").

#### D. `verification` (existing capability)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| V1 | an unresolvable `--branch` **fails closed**; the only way through is `--allow-unresolved-branch` (or `TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH=1`) and the override is written into the record (F7) | `cmd-review.sh:320, 351-368`; `tests/flip-m6.2.sh`; commit `3d84df7` | SPEC — the base spec requires `--branch` only in the `TEAM_REVIEW_ANY_DIR` scenario; the fail-closed default is absent |
| V2 | an override is visible in the record: "dirty: N uncommitted changes (TEAM_REVIEW_ALLOW_DIRTY=1)" / "ignored: N artifacts" / "branch unresolved" (F8) | `cmd-review.sh:405-407`; smoke §10b `:1908+`; commit `3d84df7` | SPEC — smoke §10b |
| V3 | `.gitignore`d build artifacts are not invisible: a checkout carrying them is refused unless `TEAM_REVIEW_ALLOW_IGNORED=1` (F9) | `cmd-review.sh:396-406`; smoke `:1952-1953`; commit `3d84df7` | SPEC — smoke `:1952` |
| V4 | `TIMEOUT` means **the wrapper killed the gate**: an ordinary failure whose *output* merely contains "timeout" stays `FAIL`, and the record states elapsed vs. deadline (`TEAM_REVIEW_TIMEOUT_GRACE`, default 2 s) (F10/F11 + M6.5 finding 2) | `cmd-review.sh:426-460`; smoke `:1992-1996`; commits `3d84df7`, `b853dee` | SPEC — smoke `F17 睡过 deadline 的门禁被硬超时终止` |
| V5 | `SKIPPED` is not evidence: the record header says `gates: none`, `digest` keeps the task in pending verification, and `status` prints the verdict next to the path (F12) | `cmd-status.sh:319`; smoke `:1999-2005`; commit `3d84df7` | SPEC — smoke `F12` |
| V6 | the record only speaks for the revision it saw: a branch that moves one commit re-appears as pending verification (F3) | `cmd-review.sh` record + `cmd-status.sh:team_reports_pending_list`; smoke `:2083`; commit `3d84df7` | SPEC — smoke `F3：… 分支再动一格，待复验信号必须回来` |
| V7 | `--strong` matches the **words the report template actually uses** and demands a path that exists: keyword soup is "不满足", a template-shaped report with `## Flip evidence` + a real `…/pkg/run.sh` is "满足" (F13/F14, second round) | `cmd-review.sh:202` (package-path shapes incl. `docs/team/reports/<ID>-<agent>/pkg/…`) + the matcher; smoke `:1882, 2007-2020`; commit `3d84df7` + M6.2 rework | SPEC — smoke `F13 只提关键词的报告 → 不满足强复验` |

#### E. `board-and-status` (existing capability)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| B1 | read-only commands never change durable state — `state/` has a byte fingerprint before/after (F28: `team ps` used to wipe a crashed agent's task) | `common.sh:team_model_running`/`team_state_clear`; smoke `:68` (fingerprint helper) + `:2720-2726`; commit `5cead18` | SPEC — smoke `读命令之后 state/ 一个字节没变（F28）` |
| B2 | a write that changed nothing is not success: unknown board ID fails with a listed vocabulary, and a listing's exit code does not depend on an unrelated empty sub-list (F29, F24) | `common.sh:team_board_set`; smoke §4b `:366-403` and §6 `:594-595`; commits `5cead18`, `9eca490` | SPEC — smoke §4b; the F24 half has no assertion yet (cheap to add) |
| B3 | **`done`'s real admission rule**: a review record whose verdict is `PASS` **or** `UNKNOWN` **or** `SKIPPED`, **or** the branch tip being an ancestor of the protected branch; override only as `TEAM_BOARD_DONE_FORCE=1` **with** `TEAM_BOARD_DONE_REASON`, audited to `docs/team/reviews/<ID>-done.md` (F1) | `common.sh:1889-1960` (`team_review_verdict`, `team_done_evidence`, `team_done_gate`, `team_done_record`), `cmd-review.sh:633-640`; smoke §4b `:374-396`; commit `5cead18` | **MODIFIED** — the shipped rule is *either/or*, the spec says "PASS **and** ancestor **and** pushed"; the force override and the audit file are not written anywhere |
| B4 | `close` states the truth about the review record ("保留" only when the file exists, otherwise "没有复验记录") (F2) | `cmd-review.sh:team_cmd_close` (final block); smoke `:2110, 2119-2120`; commit `5cead18` | SPEC — smoke `不宣称保留一个不存在的文件` |
| B5 | "unpushed" is measured against `@{upstream}` (not the protected branch), and a squash-merged branch reports "已合并（squash，内容一致）· 无需 push" instead of permanent wrap-up noise (F4, M4.3 D) | `cmd-status.sh:53-73` (`team_branch_squash_merged`), `:106-154` (`team_git_cols`); smoke §11h `:2943+` and §11i `:3070+`; commits `9eca490`, `0a8c0bd` | SPEC — smoke `F4：已 push 的分支不再被当成未收尾` |
| B6 | task ids containing `-` (`API-2`) are matched against real task ids, so their reports become "awaiting verification" instead of "ignored non-task reports" (F6) | `common.sh:team_report_is_task`; smoke §11h; commit `9eca490` | SPEC — smoke §11h |
| B7 | `TEAM_TASK_BRANCH_RESET` really gates the post-close `git switch --detach` hint (it used to be dead config) (F5) | `cmd-review.sh:650-657`; smoke `:2111, 2129-2132`; commit `5cead18` | SPEC — smoke `close 真的读了这个配置键（F5 不再是死配置）` |
| B8 | an uncommitted report is a **draft**, not a review target ("report 未提交：先等 agent 交付（不指 review）") (M4.3 C) | `cmd-status.sh:319`; smoke §11i; commit `0a8c0bd` | SPEC — smoke §11i |
| B9 | the digest's "pending wrap-up" list is honest in the other direction too: a squash-merged branch with nothing else outstanding is not pending work (M4.3 D) | `cmd-status.sh:53-73`; smoke §11i; commit `0a8c0bd` | SPEC — smoke `M4.3 D：digest（squash 合并后）` |

#### F. `notify-and-inbox` (existing capability)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| N1 | **the PM's own inbox is a first-class pending source**: `team notify pm --from-file` (the channel the docs recommend) is counted by `digest §[2]`, `team inbox`, and the watchdog — before the fix it silently vanished when the PM was not running (F26) | `common.sh:team_pending_counts`; smoke `:1766-1773`; commit `3cda164` | SPEC — smoke `F26：digest [2] 标注 PM 自己的收件箱` |
| N2 | the dedup key distinguishes two briefings that share a 60-character prefix (F17) | `extension/team-notify.ts:isDuplicate`; smoke `:3358`; commit `3cda164` | SPEC — smoke `去重键必须能区分「开头 60 字符相同、后半不同」的简报` |
| N3 | a mis-typed recipient is loud: rc=1 + the roster, and `--any` is an explicit override that is logged to `state/inbox-unknown.log` (F18) | `cmd-agents.sh:645-660`; smoke `:1794`; commit `3cda164` | SPEC — smoke `F18：打错的收件人不能静默吞消息` |

#### G. `meeting` (existing capability)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| M1 | `--ttl` must be a **positive integer hour**: `0`/`-5`/`abc` no longer create an immortal meeting, and `read` prints the effective TTL (F19) | `cmd-meeting.sh:65-80` (`team_meeting_ttl_hours`); smoke §11h; commit `9eca490` | SPEC — smoke §11h |
| M2 | the "cannot agree with yourself" guard compares the **recorded proposer** against the self-declared `TEAM_PROJECT`; the shared area is writable by both sides, so "both sides agree" is a convention, not a mechanism (F20) | `cmd-meeting.sh:team_meeting_agree`; smoke `:2847-2852`; commit `9eca490` (docs now say it out loud) | **MODIFIED** — the spec says "MUST NOT be confirmed by its proposer" without saying *what is compared*; a reader assumes a mechanism where the design only has a self-declared name (the caveat is in `references/meeting.md`, not in the spec) |

#### H. tooling/dependency truths discovered while probing the workflow (§4.2)

| # | behavior (one line) | where it lives now | Verdict |
|---|---|---|---|
| G1 | `spec-lint.sh` does **not** check the two things `openspec archive` enforces for `MODIFIED` deltas: a modified requirement name that exists in the base spec, and the base requirement's scenarios being restated. Both holes are green in `TEAM_GATES` today (evidence in §4.2) | `tests/spec-lint.sh` (rule list at `:18-27`), `openspec archive` behaviour; probe transcripts in §4.2 | SPEC(cheap) — add as two rules + a `MODIFIED` delta requirement; the failure is observable and already has a verified command shape (proposed patch below) |
| G2 | `team doctor`'s pi check resolves the configured `TEAM_PI_BIN` instead of hard-coded `command -v pi` (F25: false red on machines whose pi is not on `PATH`) | `cmd-project.sh` doctor (`team_pi_bin_path`); smoke `:639-641, 798, 808` covers the adapter path but not this exact false red; commit `9eca490` | SPEC(cheap) — one scenario: `TEAM_PI_BIN=/bin/true team doctor` must not fail on "缺 pi" |

### 3.2 Checked and already covered (no action)

I verified each of these against the specs rather than assuming; they are the reason the inventory is not longer:

| behavior | covered by |
|---|---|
| capacity floor (RAM / MemAvailable / **disk** swap, zram excluded from the floor) | `dispatch` · "The capacity floor protects the host" + 2 scenarios |
| model concurrency limits + `0` = unlimited | `dispatch` · "Model concurrency limits are enforced before dispatch" |
| malformed `{…}` / whitespace-only / multi-line adapter template; prompt out of band | `dispatch` · "The adapter template contract is enforced, not guessed" (4 scenarios) |
| dirty worktree of another task refused; same task resumes | `dispatch` · "A dispatch never mixes two tasks in one worktree" |
| empty/relative tmux targets refused everywhere, **including the typing channel** (M6.3 F27) | `boundary` · "Empty or relative tmux targets are refused" (the smoke assertion at `:297` proves the typing case is falsifiable) |
| foreign session typing needs an explicit human override | `boundary` · "Typing into a foreign session needs an explicit, human-granted override" |
| credentials never read/echoed/committed | `boundary` · two scenarios (sentinel token, no credential reads) |
| `review` needs `--dir`; dirty/mismatched refused; `TEAM_REVIEW_ALLOW_DIRTY`/`ANY_DIR` overrides | `verification` · requirements 1–2 |
| hard timeout → `TIMEOUT`, never a pass | `verification` · "Gates run under a hard timeout" (the *attribution* half is V4) |
| record pins HEAD/branch/gate/timeout/diffstat/commits/files/tail; missing report stated | `verification` · "The record states what was verified" (V6 adds revision *binding for the digest*) |
| `PASS/FAIL/SKIPPED/UNKNOWN` vocabulary, only `PASS` is evidence | `verification` · "Verdicts are explicit…" (V5 adds the digest half) |
| board status vocabulary closed to 6 words | `board-and-status` · requirement 1 (B2 adds the unknown-**ID** half) |
| watchdog: single tmux backend, pending definition, nudge rate limit, standby, restart quota, capacity log, never rebuilds tmux/never resumes agents | `watchdog` · all 6 requirements |
| meeting: closed intent set, order markers refused, shared area as truth, `--as-user` tty-only, both-sides agreement, TTL/turn caps, zero writes into the peer | `meeting` · all 6 requirements (M1/M2 add value validation + the honest wording) |
| OpenSpec + magic-context are required dependencies; `doctor`/`paths` expose the resolution; **no rival requirement tree**; the disk is the source of truth | `memory-and-deps` · all 4 requirements |

### 3.3 Prose only (why these must **not** become scenarios)

| item | where it lives | why prose |
|---|---|---|
| migration / upgrade guide + the `team doctor` pointer (M7.1) | `references/migration.md` + `cmd-project.sh:235, 395-398`; smoke §17 `:3637` | the deliverable is *guidance* ("what never needs migrating, what changed, how to roll back"), not a promise the tool can be held to; the one observable bit (the doctor hint) is already asserted by smoke §17 |
| the English-only prose invariant + "the installer installs exactly one skill" (M7.3) | `tests/smoke.sh` §18 `:3726` (`perl` missing ⇒ red; bidirectional flip self-test) | this is a *repository content* invariant enforced by the gate, not `team` CLI behavior; the config already states "Language: every artifact … is written in English" — a spec copy would be a second place to keep in sync |
| the OpenSpec five-phase process contract: owner + gate per phase, no self-verification, user-confirmed archive, the eight-point proposal checklist, `openspec init --tools pi` precondition (M9.1) | `references/openspec.md` + `templates/{AGENTS.section,PROTOCOL.md,task.md}.tmpl` + `SKILL.md` + `references/workflows.md`; smoke §19 `:3915+` | it constrains **who may run what**, which no `team` command can check; the enforceable part (a phase command exists, the guide keeps its rows) is already asserted by smoke §19 with a per-rule flip fixture. Putting it in a spec would create a second normative copy of `references/openspec.md` — the exact thing `config.yaml` forbids |
| `mark-loaded` can only detect "the disk changed after the marker" (F22) | `cmd-update.sh`; smoke §11f `:2869` | a documented limitation of a session-local convenience; there is no observable promise to make ("it says what it can and cannot see" is wording, not behavior) |
| the meeting identity caveat's *reason* (self-declared `TEAM_PROJECT` in a shared writable area) | `references/meeting.md` (updated in `9eca490`) | the *mechanism* is stated in M2 above; the reasoning belongs where the reader looks for "why" |

---

## 4. Options

### 4.1 The four splits

| option | changes | delta files | apply briefs | what the verify phase must do | what can go wrong |
|---|---|---|---|---|---|
| **A. one change for everything** | 1 (`spec-backfill-m6-m8`) | 9–10 | 6–7 | one record covering ~32 requirements / ~45 scenarios across 8–9 capability delta files; per-brief slices verified one by one | a single bad delta blocks the whole archive; one 9-file proposal review; `openspec/specs/` stays stale until the last brief lands; the change is too big for one proposal to describe honestly (<500 words per the config rule) |
| **B. one change per batch (M6/M7/M8)** | 3 | 3–6 each | 4–5 | coherent only for M6; M7 is 5 items of which 3 are prose, M8 is 2 adapter items | batches cut **across** capabilities: M6 alone touches dispatch+verification+board+notify+meeting+watchdog, so every verify phase is a mixed bag; M7's change would be nearly delta-less (needs `skip_specs` for a "no spec change" change — legal but pointless) |
| **C. one change per capability** | 9–10 (8 + `agent-adapters` + `pm-lifecycle`) | 1 each | 9–10 | tight and easy | PM overhead dominates: each change costs a propose brief, a recorded proposal review, a verify contract and an archive; `meeting` (2 rows) would consume a full cycle |
| **D. value-weighted, capability-scoped (recommended)** | 4 (`spec-delta-gate`, `launch-and-adapter-evidence`, `review-evidence-integrity`, `ledger-and-channel-honesty`) | 1 / 3 / 1 / 3 | 1 / 2 / 2 / 2 | one coherent subject per change; every scenario has a named falsifier (§3.1) | the PM still runs 4 proposal reviews + 4 archives; C3 spans 3 capabilities (accepted deliberately — see §5.1) |

Why D wins: it keeps the property that makes a *backfill* verifiable — **one change = one subject whose scenarios can
be re-run together** — while not paying a full pipeline cycle for 2-row capabilities. A is the "correct" OpenSpec
shape for one coherent feature, but this job is a **backfill of already-shipped behavior**: the value is in the
coverage, and the failure mode (one bad delta blocking everything) is exactly what the audit trail is meant to avoid.

### 4.2 What I verified about the pipeline itself (the brief's open question)

Nobody had run this workflow here, so I ran it end to end in a **scratch copy** (`/tmp/e1-scratch`, a copy of
`openspec/` — no file in this repository was created or edited):

```console
$ openspec new change e1-newcap            # the scaffolder exists (v1.8.0: `openspec new change <name>`)
Created change 'e1-newcap' at openspec/changes/e1-newcap/     # + .openspec.yaml (schema, created)
$ openspec status --change e1-newcap --json    # artifact paths: proposal.md, specs/**/*.md, design.md, tasks.md
$ openspec instructions specs --change e1-newcap --json        # delta ops: ADDED/MODIFIED/REMOVED/RENAMED
$ openspec validate --all --strict  →  Totals: 9 passed, 0 failed (9 items)   rc=0
$ bash skills/teamsmith/tests/spec-lint.sh /tmp/e1-scratch/openspec
spec-lint: OK — 9 spec file(s), 46 requirement(s), 78 scenario(s)             rc=0
$ openspec archive -y e1-newcap
Specs to update:  pm-lifecycle: create
Applying changes to openspec/specs/pm-lifecycle/spec.md:  + 1 added
Totals: + 1, ~ 0, - 0, → 0    Specs updated successfully.
```

So yes: **a new capability and a change both work, the gate sees the change, and archive writes the spec.** Three
mechanics the PM should know before dispatching propose:

1. **`openspec validate --all --strict` does not catch a bad `MODIFIED` delta.** Two probes, both green:
   - `## MODIFIED Requirements` naming a requirement that does **not** exist in the base spec →
     `validate` rc=0 (9/9 passed), `spec-lint` rc=0;
   - a `MODIFIED` block that restates only 1 of the 2 base scenarios → `validate` rc=0, `spec-lint` rc=0.
   `openspec archive` **does** catch both, but only at phase 5, after apply + verify and possibly after the code has
   merged:
   ```console
   $ openspec archive -y e1-probe
   boundary MODIFIED failed for header "### Requirement: Nope does not exist" - not found
   Aborted. No files were changed.                                            rc=1
   $ openspec archive -y e1-mod
   dispatch MODIFIED failed for header "### Requirement: A brief is self-contained …" -
   current spec contains scenario(s) not present in the modified block: "The prompt points at the brief".
   Refresh the change spec before archiving to avoid dropping scenarios.            rc=1
   ```
   A backfill is made almost entirely of `MODIFIED` deltas, so this is the single largest risk in the whole program
   (§6.1) — and it is cheap to move to gate time (task C0 in §5.2). I wrote and tested the command shape that does it
   in bash+awk (no new runtime dependency; red/green transcripts in §7).
2. **Archive normalizes whitespace inside the replaced block.** Archiving a `MODIFIED` requirement with a third
   scenario produced a 12-line diff: the requirement text changed as intended, plus blank lines before `## Requirements`
   and `### Requirement:` were dropped. Expect a small cosmetic diff when a `MODIFIED` delta is archived; it is not
   scope creep (and it is unavoidable — it is the serializer, not the delta).
3. **A `MODIFIED` delta must restate the base requirement byte-faithfully apart from the intended change** — archive
   replaces the whole block, so an accidental paraphrase silently becomes the new spec text. The PM's proposal
   checklist point 7 ("grep `openspec/specs/` before accepting") is what catches this; the delta check in C0 makes it
   mechanical.

---

## 5. Recommendation

**Take option D.** Four changes, ordered so that the risk-reduction lands first:

```
C0 spec-delta-gate          ──▶ C1 launch-and-adapter-evidence ──▶ C2 review-evidence-integrity
 (gate hardening, cheap)        (the pilot backfill)                  (parallel with C3)
                                                              └──▶ C3 ledger-and-channel-honesty
```

Sizes: C0 = 2 requirements (1 test change), C1 = 9, C2 = 7, C3 = 14 (B1–B9, N1–N3, M1–M2).
All 32 requirements have a named falsifier in §3.1; nothing in the plan requires new *behavior*, only new *promises
about behavior that already shipped*.

### 5.1 The change split

| change id | capabilities (delta files) | requirements | apply briefs | why this seam |
|---|---|---|---|---|
| `spec-delta-gate` | `memory-and-deps` | G1, G2 | 1 | tiny, and it makes every later change's gate catch the `MODIFIED` holes at apply time instead of at archive; G2 rides along because it is the same capability and the same kind of "the gate lies" defect |
| `launch-and-adapter-evidence` | `dispatch` + new `agent-adapters` + new `pm-lifecycle` | D1–D4, A1–A2, W1–W3 | 2 (worker side / both-sides+PM side) | one subject: "did the thing we asked for actually start, and by which binary?" It is the largest false-green cluster in the recent history (`✓ dispatched` while nothing ran, v1.26.0). The adapter contract moves to `agent-adapters` so both sides share one placeholder list; the PM's own lifecycle gets its own spec so `watchdog` stays about *when to wake* |
| `review-evidence-integrity` | `verification` | V1–V7 | 2 (checkout/fail-closed; verdicts/strong/flip) | one subject: "what did the review really verify, and what does the record claim?" The V4.0 evidence cluster |
| `ledger-and-channel-honesty` | `board-and-status` + `notify-and-inbox` + `meeting` | B1–B9, N1–N3, M1–M2 | 2 (board/status; channels) | one subject: "no command reports a state it does not have". Three capabilities is deliberate: they are all thin `MODIFIED`/`ADDED` deltas whose scenarios share a single falsifier pattern (`smoke.sh §4b/§7/§11h/§11i/§11i`), and splitting them would buy two extra PM cycles for ~6 rows. **Fallback**: if the PM prefers single-capability verify records, split into `ledger-honesty` (board-and-status) and `channel-honesty` (notify-and-inbox + meeting) |

Capability disjointness makes the parallel plan safe: C1 owns `dispatch`/`agent-adapters`/`pm-lifecycle`, C2 owns
`verification`, C3 owns `board-and-status`/`notify-and-inbox`/`meeting` — no two in-flight changes can touch the same
`openspec/specs/<cap>/spec.md`, so archives cannot collide.

### 5.2 Task split (phase · owner · dependencies)

Roster is `dev`, `verify`, `dev2` (me). Pipeline rule: **explore and propose may be the same agent; apply must not be
the proposer; verify must not be the applier.**

| task | phase | owner | deps | hand-out |
|---|---|---|---|---|
| C0.1 | propose | dev2 | E1 accepted by the PM (DECISIONS entry) | `openspec/changes/spec-delta-gate/{proposal,specs/memory-and-deps/spec.md,tasks}.md` |
| C0.2 | apply | dev | PM proposal review `docs/team/reviews/spec-delta-gate-proposal.md` = ACCEPTED | `tests/spec-lint.sh` gains the two delta rules + a flip pair; report with red→green |
| C0.3 | verify | verify | C0.2 on the branch | `docs/team/reviews/C0.md` (breaks a delta, expects the two new rules to fire, restores) |
| C0.4 | archive | PM | C0.3 PASS + user confirmation | `openspec/changes/archive/<date>-spec-delta-gate/`, `memory-and-deps` updated |
| C1.1 | propose | dev2 | C0 archived (or at least C0.2 landed, see §6.5) | `changes/launch-and-adapter-evidence/**` (3 delta files) |
| C1.2 | apply | dev | C1 proposal review ACCEPTED | worker side: `dispatch` D1–D4 + `agent-adapters` A1 (the `dispatch`→`agent-adapters` move) |
| C1.3 | apply | verify | C1.2 landed (same change; second brief) | PM side: `agent-adapters` A2 + `pm-lifecycle` W1–W3 |
| C1.4 | verify | cross: dev verifies C1.3's delta, verify verifies C1.2's delta | both briefs landed | one `reviews/C1.md` per brief slice (no self-verification) |
| C1.5 | archive | PM | C1.4 PASS + user confirmation | specs for `dispatch`, `agent-adapters`, `pm-lifecycle` |
| C2.1 | propose | dev2 | C1.1 (the propose pattern is now known; may run in parallel with C1.2) | `changes/review-evidence-integrity/**` |
| C2.2/C2.3 | apply ×2 | dev, then verify (or vice versa) | C2 proposal review ACCEPTED | `verification` V1–V7 in two briefs (checkout/fail-closed; verdicts/strong/flip) |
| C2.4 | verify | the agent that did **not** apply that brief | both briefs landed | `reviews/C2.md` |
| C2.5 | archive | PM | C2.4 PASS + user confirmation | `verification` spec updated |
| C3.1 | propose | dev2 | C2.1 (same agent); may run in parallel with C2.2 | `changes/ledger-and-channel-honesty/**` (3 delta files) |
| C3.2/C3.3 | apply ×2 | dev, then verify | C3 proposal review ACCEPTED | board/status brief; channels brief |
| C3.4 | verify | the agent that did not apply that brief | C3.2/C3.3 landed | `reviews/C3.md` |
| C3.5 | archive | PM | C3.4 PASS + user confirmation | 3 specs updated |

Practical sequencing with a 3-agent roster: **C0 alone → C1 alone (pilot: first backfill through the pipeline) →
C2 and C3 in parallel**. The parallel phase has a concrete, legal shape: `dev` applies C2's board/status brief while
`verify` applies C3's first brief (different capabilities, different branches), then the two swap roles for the
verification records — nobody verifies their own change, and `dev2` is free to be the proposer. No change in this plan
depends on another's *content*; the dependencies are the gate (C0) and the knowledge (C1 as pilot).

### 5.3 Every apply brief for this program should carry

1. **The scenario → falsifier table** for its rows from §3.1. The brief's acceptance is `bash
   skills/teamsmith/tests/smoke.sh` **plus**, for each new/changed scenario, the exact falsifier output tail
   (test label or command) — evidence over prose.
2. **The delta↔base check** (until C0 lands it as a lint rule): the tested script in appendix A, run as
   `bash <script> openspec/changes/<id> openspec/specs` → `MISSING-REQUIREMENT` / `LOST-SCENARIO` (rc=1) or
   `NEW-CAPABILITY` (informational, rc=0). Proposed code names for C0: `delta-modified-requirement-missing` /
   `delta-dropped-scenario`.
3. **`## Flip evidence` for the *promise*, not for code**: for a backfill the honest flip is
   *"break the behavior the scenario pins → the named falsifier goes red → restore → green"*. Where no falsifier
   exists yet (B2's F24 half, G2, a couple of §3.1 rows marked "no assertion yet"), the brief must add one to
   `skills/teamsmith/tests/**` (owner: `dev` per `OWNERSHIP.md`). Reports must put that package in
   `docs/team/reports/<ID>-<agent>/pkg/run.sh` so `team review --strong` finds a real path (V7 is exactly this rule).

### 5.4 Ownership precondition (needs a PM decision before the first propose brief)

`docs/team/OWNERSHIP.md` does not list `openspec/**`, and its header says *"没有列出的目录 = PM 独占"* (unlisted
directories are PM-exclusive). As written, **no agent may write `openspec/changes/**`** — so a propose brief handed to
`dev2` would be illegal on day one. The PM needs to either

- grant `openspec/changes/**` to the proposing agent (and `openspec/specs/**` — archive-time — to the PM), or
- keep propose PM-owned and let the explorer hand over the artifacts (which breaks the "the explorer holds the
  context" rationale in `references/openspec.md` §2).

I recommend the first: add `openspec/changes/**` → `agent:*` (temporary borrowing per OWNERSHIP §"变更流程" 2 is
also legal, but this program has 4 changes and would need 4 borrows). This is the one item that must be settled
**before** the first propose brief; I did not touch the file myself (it is PM-owned).

### 5.5 Out of scope, deliberately (no change needed)

M7.1 migration guidance, M7.3 English invariant + installer, M9.1 process contract, F22's limitation, F20's rationale,
and every §3.2 row that is already covered. The gate already falsifies the M7.3/M9.1 halves (§3.3); adding spec text
for them would create a second normative copy of documents the config says are the normative source.

---

## 6. Risks and unknowns

**6.1 The largest risk: `MODIFIED` deltas are not gated until archive** (§4.2 item 1). A typo'd requirement name or a
dropped scenario is green in `TEAM_GATES` and red only at phase 5. Mitigations: (a) C0 shrinks this to a gate-time
failure; (b) until then, every propose brief runs the delta check in §5.3.2 and the PM's proposal review runs it again
against the base specs; (c) the PM's checklist point 7 (grep the base spec) must be executed literally, because it is
currently the only thing catching a paraphrased `MODIFIED` block.

**6.2 Boilerplate risk (named by the brief).** A scenario that cannot fail is worse than no spec. My control: **no
scenario without a named falsifier**. 30 of the 32 rows in §3.1 name a falsifier that already exists; 2 rows (B2's F24
half and G2) need a single new assertion each, which is the only new *code* this program produces. If the PM wants a
hard rule: reject any delta whose scenario lacks an entry in the falsifier column.

**6.3 Duplication with `references/`.** The specs must state the promise and link the reason
(`config.yaml`: "Cross-reference the doc that explains the reason instead of restating it"). C1 is where this bites:
`references/agent-adapters.md` (366 lines) documents the adapter engine in detail, and it must not be copied into
`agent-adapters/spec.md`. Rule for the propose phase: **if the spec text is a procedure, it belongs in the reference;
the spec keeps the observable outcome and a link.**

**6.4 Unknown — how `--strong` treats a backfill report.** The matcher (V7) wants flip evidence **and a path to an
independent package**. A backfill's natural evidence is "smoke §X line Y goes red when the behavior is broken", which
is not a path. The plan's answer (§5.3.3) is a `pkg/run.sh` per apply brief; if the PM disagrees, the strong-review
step will report "independent package missing" for legitimate reports — decide before C1.2 is dispatched.

**6.5 Unknown — the C0 → C1 dependency is a choice, not a fact.** C0 is cheap, but it changes a *test* that every
other task runs; C1's apply briefs would benefit from it and would also be perturbed by it if it lands mid-flight.
Safest: C0 applies and archives first (it is 1 brief), then C1.

**6.6 Unknown — sequential `MODIFIED` deltas.** If change X archives a `MODIFIED` requirement and change Y (cut
earlier, or proposing from a stale tree) also modifies it, Y's delta must be based on the **post-X** text or archive
aborts with "scenario(s) not present". This program never touches the same capability from two changes (§5.1), so it
does not bite here — but the propose phase must still copy the requirement text from the base spec **at propose time**,
not from memory of the code.

**6.7 Unknown — spec file size.** After the backfill `dispatch` would grow from 6 to ~10 requirements and
`board-and-status` from 6 to ~15 (roughly 400 lines). `spec-lint`/`validate` are millisecond-fast, so gates are fine;
readability is not something I can measure from here. If a capability file passes ~300 lines, consider splitting by
subject (`board` vs `digest`), which is a separate decision with no dependency on this program.

**6.8 Cost/benefit I could not settle.** Four changes + seven apply briefs + seven verification runs + four proposal
reviews is a real amount of PM attention. If the PM wants a smaller program, the highest-value subset is **C0 + C1**
(the launch/adapter false greens) — that alone closes the class of bug that produced v1.26.0 and keeps the pilot
learning cheap. My recommendation is still all four, in that order, because C2/C3 are the same mechanical pattern once
C1 has proven it.

---

## 7. Acceptance (the brief's commands, verbatim)

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

$ git status --porcelain          # before the final commit; only the report is ever dirty
 M docs/team/reports/E1-dev2.md
$ git diff --name-status main...HEAD
A	docs/team/reports/E1-dev2.md
$ git merge-base --is-ancestor 12868f0 main && echo "base ok"    # the branch base is still an ancestor of main
base ok
```

Baseline gate at the time of writing (v1.27.0, this worktree): `openspec validate --all --strict` → 8 passed,
0 failed, rc=0; `spec-lint.sh` → 45 requirements / 77 scenarios, rc=0.

### Evidence: the full gate in this worktree at v1.27.0

```console
$ openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh && bash skills/teamsmith/tests/smoke.sh
- Validating...
✓ spec/board-and-status   ✓ spec/boundary   ✓ spec/dispatch   ✓ spec/meeting
✓ spec/memory-and-deps    ✓ spec/notify-and-inbox   ✓ spec/verification   ✓ spec/watchdog
Totals: 8 passed, 0 failed (8 items)
spec-lint: OK — 8 spec file(s), 45 requirement(s), 77 scenario(s) under openspec
teamsmith smoke · skill=…/.worktrees/dev2/skills/teamsmith · tmp=/tmp/teamsmith-smoke.N9NPcK
… (sections 0–19)
== 结果 ==  ✓ 1159  ✗ 0
smoke 全绿
```

Full suite, not `TEAM_SMOKE_FAST=1`: 0 `SKIP` lines, and the live sections §6j, §11b2, §11b3 and §11d all ran. Two
independent runs of the gate on this branch agreed (1159 ✓ / 0 ✗). E1 touched no code file, so these are the baseline
numbers too — the report itself cannot move them (the suite scans `skills/**`, not `docs/team/**`).

### Evidence: the two new `spec-lint` rules, tested red/green before being proposed (C0)

```console
$ bash delta-check.sh /tmp/e1-scratch/openspec/changes/e1-modx /tmp/e1-scratch/openspec/specs
# A: MODIFIED restates both base scenarios (+ an unrelated ADDED requirement)
   (no output)                                                        rc=0
# B: MODIFIED drops "The prompt points at the brief"
LOST-SCENARIO dispatch :: A brief is self-contained and names its evidence :: The prompt points at the brief
                                                                      rc=1
# C: MODIFIED names a requirement the base spec does not have
MISSING-REQUIREMENT dispatch :: Typo name that does not exist          rc=1
# D: only ADDED requirements (the normal backfill case for new text)
   (no output)                                                        rc=0
# E: a capability with no base spec yet (new capability)
NEW-CAPABILITY pm-lifecycle                                           rc=0
```

(`openspec validate --all --strict` and `spec-lint.sh` were rc=0 in cases B and C; `openspec archive -y` was rc=1
with `Aborted. No files were changed.` — the hole and the fix, both demonstrated. The script is appendix A.)

### Evidence: the workflow's mechanics (scratch, no repo file touched)

See §4.2 — `openspec new change`, `status --json`, `instructions specs --json`, a new-capability archive
(`pm-lifecycle: create`, `+ 1 added`), the archive aborts for a bad `MODIFIED` name and for dropped scenarios, and the
whitespace normalization diff.

## Appendix A · `delta-check.sh` (tested; proposed as a `spec-lint.sh` rule in C0)

Bash + awk only — no new runtime dependency (`ROADMAP.md`: no jq/python/node). Cases A–E above were run against this
file verbatim.

```bash
#!/usr/bin/env bash
# spec-lint candidate: the two checks `openspec archive` performs only at phase 5.
#   usage: delta-check.sh <change-dir> [specs-dir]        rc=0 clean, 1 violations, 2 unusable
set -uo pipefail
ch="${1:?usage: delta-check.sh <change-dir> [specs-dir]}"; specs="${2:-openspec/specs}"
[ -d "$ch/specs" ] || { printf 'no delta specs under %s\n' "$ch" >&2; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

pairs() { # <spec.md> <MODIFIED|"">  →  "<requirement><TAB><scenario>" lines
  awk -v want="$2" '
    function emit() { if (req != "") print req "\t" (scen == "" ? "-" : scen) }
    /^## (ADDED|MODIFIED|REMOVED|RENAMED)/ { insec = (want == $2); next }
    /^## Requirements/      { if (want == "") insec = 1; next }
    /^## /                  { insec = 0; next }
    insec && /^### Requirement: / { emit(); req = substr($0, 18); scen = ""; next }
    insec && /^#### Scenario: /   { if (req != "" && scen != "") print req "\t" scen; scen = substr($0, 16); next }
    END { emit() }
  ' "$1" | sort -u
}

bad=0
for f in "$ch"/specs/*/spec.md; do
  [ -f "$f" ] || continue
  cap="${f#"$ch"/specs/}"; cap="${cap%/spec.md}"
  base="$specs/$cap/spec.md"
  if [ ! -f "$base" ]; then printf 'NEW-CAPABILITY %s\n' "$cap"; continue; fi
  pairs "$f" MODIFIED > "$tmp/delta"; pairs "$base" "" > "$tmp/base"
  cut -f1 "$tmp/delta" | sort -u > "$tmp/mods"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    grep -qxF "$r" <(cut -f1 "$tmp/base") || { printf 'MISSING-REQUIREMENT %s :: %s\n' "$cap" "$r"; bad=1; }
  done < "$tmp/mods"
  while IFS=$'\t' read -r r s; do
    grep -qxF "$(printf '%s\t%s' "$r" "$s")" "$tmp/delta" || { printf 'LOST-SCENARIO %s :: %s :: %s\n' "$cap" "$r" "$s"; bad=1; }
  done < <(grep -Ff "$tmp/mods" "$tmp/base" || true)
done
exit "$bad"
```

### Boundary check

- Files written by this task: this report only (`docs/team/reports/E1-dev2.md`). Nothing under `openspec/`, no spec,
  no code, no `docs/team/**` ledger file other than the report.
- The pipeline probes ran in `/tmp/e1-scratch` on a copy of `openspec/`; nothing in this repository was created or
  edited by them.
- No change was opened (`openspec list` → "No active changes found."), no one was dispatched, no other project or
  tmux session was touched.
