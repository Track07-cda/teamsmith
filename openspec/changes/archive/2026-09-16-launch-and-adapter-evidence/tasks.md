# Tasks: launch-and-adapter-evidence

Rows: E1 §3.1 `D1–D4`, `A1–A2`, `W1–W3` (nine). One change, one apply brief, three **sequential** sub-tasks in
dependency order — `dispatch` → `agent-adapters` → `pm-lifecycle` (D18; one writer per change directory). The file
order inside a delta is irrelevant to the CLI (E2 §4.2), the task order is not.

**Why there is no smoke-based evidence here:** a backfill ships no behaviour, so the project's suite is green before
and after and cannot fail for anything this change does. The gate is still required (4.1–4.2), but the claim "this
scenario is falsifiable" is only demonstrated by the verify phase's three layers: archive applicability (4.3), the
migration diff (4.4), and the injection matrix (4.5). A smoke run without 4.4–4.5 is the false green a backfill
invites (E2 §6.4).

Only `openspec/changes/launch-and-adapter-evidence/**` may be written; `openspec/specs/**` is archive's job and must
not change before phase 5.

## 1. `dispatch` delta — two new requirements, two additive scenarios

- [x] 1.1 `specs/dispatch/spec.md` — `## REMOVED Requirements`: the adapter-engine requirement with `**Reason**` and
  `**Migration**`, the requirement name byte-identical to the base spec.
  Verify: `grep -c '^### Requirement: The adapter template contract is enforced, not guessed$' openspec/specs/dispatch/spec.md`
  is 1 and the same grep on the delta's REMOVED section is 1.

- [x] 1.2 Same file — `## MODIFIED Requirements` for "A brief is self-contained and names its evidence": the whole
  base block (both base scenarios) plus the project-boundary scenario. Falsifier (exists, smoke §6):
  `F15：项目外任务书被拒（--print 也不放行）`, `F15：报错说明任务书在项目外`, `F15：报错点名项目主工作树`.
  Verify: `openspec validate --all --strict` exits 0 and `bash skills/teamsmith/tests/spec-lint.sh` exits 0; with
  C0's lint present, no rule fires on this file.

- [x] 1.3 Same file — `## MODIFIED Requirements` for "One task branch per task": the whole base block plus the
  parked-on-another-task's-branch scenario. Falsifier (smoke §6): `F16：工作树停在别的任务的分支上 → dispatch 拒绝`,
  `F16：报错点名了工作树当前的分支`, `F16：报错点名了本任务的规范分支`, `F16：给出 PM 该跑的 git switch 命令`,
  `F16：没有真的派单`.

- [x] 1.4 Same file — `## ADDED Requirements`: "A dispatch proves the agent started, or fails loudly" (`D3`) with its
  four scenarios. Falsifiers (smoke §6h/§6j): `M4.3 B1：派单进楔死窗口 → 如实报失败`,
  `B1：标题就是「未能确认启动」（不是成功）`, `B1：按约定重试了一次`, `B1：失败后的窗口终态 = 不存在`,
  `M7.5 B4a：旧 nonce 的退出记录不算本轮证据`, `M4.3 B3：退出证据落盘（state/dispatch-dev.exit）`,
  `B3：通知报出的是真实退出码`, §6j `M8.2：agent 秒退非 0 → 派单失败`, `exit=7`,
  `dispatch-<agent>-launch-failed.log`.
  Verify: the gate of 1.2 stays green and every scenario block has GIVEN/WHEN/THEN bullets:
  `grep -c '^#### Scenario:'` on the four blocks is 4 and `grep -c '^####'` is 4.

- [x] 1.5 Same file — `## ADDED Requirements`: "A dispatch refuses a session the model's window cannot hold" (`D4`)
  with its six scenarios. Falsifiers (smoke §6h): `M4.3 A1：大会话 + 小窗口模型被拒`, `A1：报出选中模型的窗口`,
  `M4.3 A2：--print 也被拒`, `M4.3 A3：大窗口模型可以复用同一会话`,
  `M4.3 A4：--allow-overflow 显式放行`, `M4.3 A5：--fresh 不受历史会话大小影响`,
  `M4.3 A6：未知窗口按保守阈值拒绝`, `M4.3 A7：TEAM_MODEL_WINDOWS 可显式覆盖窗口`,
  `M4.3 A9：roster 显示已用/窗口并标出超窗`.
  Verify: same gate; `grep -c '^#### Scenario:'` on those blocks is 6.

## 2. `agent-adapters` — the new capability (the move)

- [x] 2.1 `specs/agent-adapters/spec.md` — `## Purpose` (50+ characters) as the first block, then
  `## ADDED Requirements` starting with the migrated engine requirement, byte-identical to its base block.
  Verify: `grep -c '^## Purpose' openspec/changes/launch-and-adapter-evidence/specs/agent-adapters/spec.md` is 1 and
  the item-4.4 migration diff is empty.

- [x] 2.2 Same file — ADDED "The template's first word is resolved, not guessed" (`A1b`) with its two scenarios.
  Falsifiers (smoke §6j): `M8.2：裸名字被换成调用者 PATH 解析出的绝对路径`,
  `M8.2：渲染出的命令不再出现裸名字`, `M8.2：已经是绝对路径的首词原样保留`,
  `M8.2：TEAM_AGENT_BIN 指向别的名字时不改模板首词`, `M8.2：裸名字的 CLI 真的在窗口里跑起来了`.
  Verify: same gate; the two scenario headers are present.

- [x] 2.3 Same file — ADDED "The PM is an adapter too" (`A2`) with its six scenarios, including the observable
  default-path scenario from `design.md` D4 (no internal function name, no test-only reference string).
  Falsifiers (smoke §6i/§11b2): `M8.1 默认渲染与历史逐字节一致`, `②b` bad PM templates
  (`{sessionid}` / `{ cwd }` / blank / multi-line / `{notify_ext}` / `{summary}`) → `坏 PM 模板 → 直接失败`,
  `不可解析的 PM CLI → 启动前失败`, `Pi 路径：默认 -c（延续）`, `自定义 CLI + 空 resume 参数 → 明确报「不延续」`,
  `resume 参数真的进了这一轮的 argv`, `非 Pi PM 被拉起`, `pm-launch-failed.log`, `exit   : 7`,
  §11b2 `①b：这一轮真的用 -c 拉起 PM`, `①b：这一轮真的用 @ 提示词文件拉起 PM`.
  Verify: same gate; the PM placeholder spelling in the requirement matches `references/agent-adapters.md` §2
  (`grep -n 'pm-side:begin' skills/teamsmith/references/agent-adapters.md`).

## 3. `pm-lifecycle` — the new capability

- [x] 3.1 `specs/pm-lifecycle/spec.md` — `## Purpose` first, then ADDED "PM liveness is proven, not inferred" (`W1`)
  with its six scenarios. Falsifiers (smoke §11b2 + F28): `M6.5 ①：不再把 tmux 自己报成运行中的 PM`,
  `M6.5 ①b：前台是 tmux 的窗口不算 PM`, `M6.5 ②：记录的 pid 死了 → 不再算存活`,
  `M6.5 ③：本项目里的非 PM 进程 → unknown:*`, `M6.5 ④：up 明确拒绝覆盖外来进程`,
  `M6.5 ④b：人工在窗口里启动的 agent 被认成 running`, `F30：启动证据就是 spawn`,
  `F30：别人放的 sleep 只是 unknown`, `读命令之后 state/ 一个字节没变（F28）`.
  Verify: same gate; `grep -c '^#### Scenario:'` on the requirement's blocks is 6.

- [x] 3.2 Same file — ADDED "A PM that is starting is a state, not a missing PM" (`W2`) with its two scenarios; the
  vocabulary is `running/starting/idle/unknown/foreign/missing` and the text must not contain `busy`.
  Falsifiers (smoke §11b3): `第二拍没有杀掉刚起来的 PM（pane 没换）`, `重启配额只记 1 次`,
  `PM 只被启动了一次`, `启动标记用完就撤`, `手动落下的启动标记 → team_pm_state 报 starting:*`,
  `启动中的一拍不吃配额`, `陈旧标记过期后不再报 starting:*`, `陈旧标记不阻塞拉起`.
  Verify: `grep -c 'busy' openspec/changes/launch-and-adapter-evidence/specs/pm-lifecycle/spec.md` prints 1 — the
  sentence that says there is no `busy` state; the requirement prose lists the six states.

- [x] 3.3 Same file — ADDED "A reload request is bookkeeping, not a restart" (`W3`) with its two scenarios.
  Falsifiers (smoke §11h): `F23：不再承诺 watchdog 会重启 PM 会话`, `F23：明说 marker 不会重启任何东西`,
  `F23：给出真正生效的方式`, `F23：scripts/ 里除 cmd-update.sh 外没有组件读 marker`,
  `F23：reload --done 仍然能清掉 marker`.

## 4. Evidence (apply runs 4.1–4.4; verify owns 4.5 and re-runs all of them)

- [x] 4.1 `openspec validate --all --strict` with the change active — paste the totals line (`9 passed, 0 failed`).
- [x] 4.2 `bash skills/teamsmith/tests/spec-lint.sh` with the change active — paste the summary line. With C0's
  checker present this same command would also run the six delta-applicability rules; **C0 was dropped (D23)**, so
  the extra C0-branch run this row used to ask for no longer applies — the delta-name class is caught by the trial
  archive in 4.3 instead.
- [x] 4.3 Archive applicability on a **scratch copy** (the spec root must be `<scratch>/openspec`; a directory that
  *is* the spec root is not found by openspec 1.8.0 — P4 finding F5):
  `rm -rf /tmp/c1-archive && mkdir -p /tmp/c1-archive && cp -r openspec /tmp/c1-archive/openspec && (cd /tmp/c1-archive && openspec archive -y launch-and-adapter-evidence)`
  must report `dispatch` `+ 2 added / ~ 2 modified / - 1 removed` and create `agent-adapters` and `pm-lifecycle`
  with a real `## Purpose` (no `TBD - created by archiving`). The repository's `openspec/` stays untouched:
  `git status --porcelain` shows only the change directory and the report.
- [x] 4.4 Migration and restatement diff: extract the engine requirement from
  `git show HEAD:openspec/specs/dispatch/spec.md` and from the scratch archive's
  `openspec/specs/agent-adapters/spec.md` and `diff` them → empty; diff each `MODIFIED` block against its base block
  → the only hunks are the appended scenarios.
- [ ] 4.5 **Verify phase, real processes (tmux windows + fake CLIs, `TEAM_SMOKE_FAST` unset):** falsifier injection —
  for each requirement, break the behaviour it pins in a scratch copy, watch the named assertion go red, restore it,
  watch it go green. Minimum: drop the spawn nonce check (`D3`), compare the session window with `>=` or skip the
  guard (`D4`), skip the branch-identity check (`D1`), drop the brief-in-project check (`D2`), render the template's
  first word verbatim (`A1b`), drop `-c` from the built-in Pi path (`A2`), make `team_pm_alive` accept `unknown:*`
  (`W1`), ignore `state/pm.pid.starting` (`W2`), restore the "watchdog restarts the PM session" wording (`W3`). Any
  row whose red cannot be demonstrated is named in the record instead of claimed.
- [ ] 4.6 Archive (PM, phase 5, only after independent verification and the user's confirmation):
  `openspec archive -y launch-and-adapter-evidence` on the merged tree, then re-run the gate.
