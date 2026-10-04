# P213 · P211 换人独立验证：看板裁决 dropped 不再算待复验

agent: verify   status: PASS   time: 2026-10-04
branch: `task/P213-verify`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P213-verify/run.py` | 自造 T1 项目、CLI 对换、wip 对照、三种裁决及两条影子 |
| `docs/team/reports/P213-verify/README.md` | 来源、隔离方法、SHA256 和重跑命令 |
| `docs/team/reports/P213-verify/logs/` | 逐次完整 digest/status、真实影子失败、规格与相关段门禁输出 |
| `docs/team/reports/P213-verify/{before,fixed}-cmd-status.sh` | 本次唯一替换文件的前后快照 |

## Verification evidence (must have actually been run)

**结论：范围 PASS。** 自己跑了全部五项验收要求；未发现 P211 范围缺陷。证据包及门禁均由 verify 本次生成，没有引用 P211 或 PM 的通过记录。仅引用 `790112dd` 及其父提交作为被验代码来源。

### 1. 同环境对换与不误吞

```text
$ git show 790112dd^:skills/teamsmith/scripts/lib/cmd-status.sh > docs/team/reports/P213-verify/before-cmd-status.sh
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -v "$PWD/docs/team/reports/P213-verify:/work" -w /work localhost/teamsmith-gate:local python3 /work/run.py /work/.gate
SOURCE before sha256=74c989ee68390a1fcb996e8b478d07303120724273cbd18d3a3ba7ff099bd095
SOURCE fixed sha256=c7828f9d7b55aa229f5b911221fb02c8c1808c9c124ed995c172b281f999d16e
FIXTURE task/T1-verify resolves to 9bf290ab9fc2e449080f0b837feb222660babc21
OBSERVE old-dropped: board=dropped pending=True skipped_named=False explanation=[]
OBSERVE fixed-dropped: board=dropped pending=False skipped_named=True explanation=['  待复验：**不列**（看板是 dropped：任务已被显式丢弃，不是「已交付待复验」；digest 的「已按看板跳过」一行会点名它）']
OBSERVE restore-old-dropped: board=dropped pending=True skipped_named=False explanation=[]
OBSERVE old-wip: board=wip pending=True skipped_named=False explanation=[]
OBSERVE fixed-wip: board=wip pending=True skipped_named=False explanation=[]
RESULT independent assertions=14, failures=0; shadow guards=2 expected-red
[team_bg_wait p213-independent: exit=0]
```

实际 stdout/stderr 重定向到 `logs/independent.log`；每次 CLI 的原始输出独立保存。自己生成报告、看板、任务书和可解析分支，普通 `reviews/T1.md` 不存在；没有使用 P211 夹具或助手。对换时报告与 dropped 看板内容相同，只换 scratch 的 `cmd-status.sh`。恢复旧文件后假待办再次出现，排除了环境本来就不报的假绿。

只认 digest `[3]` 内以 `T1-verify` 开头的候选行；跳过行另检。不能用整份输出匹配报告名，因为 `[4]` 也可能提及未入账记录。

### 2. 三处判据一致

| 看板 | digest 待复验候选 | 跳过行 | status 说明 |
|---|---|---|---|
| dropped | 不列 | 点名 T1-verify，状态清单含 dropped | 明说显式丢弃与不列；不引用不存在的 T1-done.md |
| done | 不列 | 点名 T1-verify，状态清单含 done | 明说 done 与不列，引用已存在的 T1-done.md |
| closed | 不列 | 点名 T1-verify，状态清单含 closed | 明说 closed 与不列，引用已存在的 T1-done.md |
| wip（前后两版） | 都列 | 不跳过 | 未伪造裁决说明 |

对应原始输出：`logs/fixed-{dropped,done,closed,wip}.{digest,status}.txt`、`logs/old-wip.{digest,status}.txt`。done/closed 的决定记录是自造凭证，用于检验引用目标存在，不用于宣称真正的任务交付。

### 3. 门禁（本人运行，容器内）

先 `git archive HEAD | tar -x -C docs/team/reports/P213-verify/.gate`，在包内创建独立 git 检出；避免容器无法解析宿主 worktree 的 `.git` 指针。

```bash
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -v "$PWD/docs/team/reports/P213-verify:/work" -w /work/.gate localhost/teamsmith-gate:local bash -c 'git config --global --add safe.directory /work/.gate; git init -q -b main; git config user.name P213-gate; git config user.email p213@example.invalid; git add .; git commit -qm "P213 independent gate checkout"; openspec validate --all --strict > /work/logs/openspec.log 2>&1; s=$?; tail -12 /work/logs/openspec.log; echo openspec_exit=$s; TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 21,12f </dev/null > /work/logs/smoke-21-12f.log 2>&1; g=$?; tail -20 /work/logs/smoke-21-12f.log; echo smoke_exit=$g; test "$s" -eq 0 && test "$g" -eq 0'
Totals: 13 passed, 0 failed (13 items)
openspec_exit=0
21 · 待复验清单不得越过看板决定（M9.4） · ✓35 ✗0 SKIP0
12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token） · ✓27 ✗0 SKIP0
账本自查：8 段收口 · 增量 ✓125 ✗0 SKIP0 ｜ 结果行 ✓125 ✗0 —— 一致
== 选段结果 == ✓ 125 ✗ 0
smoke_exit=0
[team_bg_wait p213-gates: exit=0]
```

- 实际运行的八段：`0,0b,0c,0d,2,21,33,12f`，含自动补齐的依赖段；33 内部自测另显示 ✓335 ✗0。
- 按任务书只跑相关段，**没有跑全套**。116 个未跑键完整列于 `logs/smoke-21-12f.log` 末尾，包括巡逻生命周期、其它进程段及性能门禁；不把选段结果称为全套通过。
- 未在宿主跑 smoke。容器日志明确证明本轮 tmux socket 在私有目录，默认 server 没有本轮 session；未看到「私有 socket 没生效」红侧。
- 两次长命令均用 `team_bg_run`，两份结果均已 `team_bg_wait` 收齐。

## Flip evidence (required for defect-fix tasks)

同环境红/绿/回红：旧文件 `pending=True` → 被验文件 `pending=False + skipped_named=True` → 恢复旧文件 `pending=True`，见上表及 `logs/independent.log`。

另有两条**真实失败的消费侧守卫**，不是只打印预期结果：

```text
$ run.py: 在 scratch 的固定实现中将 done|closed|dropped) 替换为 done|closed)，再执行 CLI dropped 用例和 assert actual == expected
OBSERVE shadow-remove-dropped: board=dropped pending=True skipped_named=False
AssertionError: pending=True, expected=False
guard_exit=1

$ run.py: 在 scratch 的固定实现中将 done|closed|dropped) 替换为 done|closed|dropped|wip)，再执行 CLI wip 用例和同一守卫
OBSERVE shadow-swallow-wip: board=wip pending=False
AssertionError: pending=False, expected=True
guard_exit=1

$ run.py: 恢复固定文件，再执行两条原判据
OBSERVE restored-fixed-dropped: board=dropped pending=False skipped_named=True
PASS restore fixed implementation returns dropped guard to green
OBSERVE restored-fixed-wip: board=wip pending=True skipped_named=False
PASS restore fixed implementation returns wip guard to green
```

详细异常：`logs/shadow-remove-dropped.guard.txt`、`logs/shadow-swallow-wip.guard.txt`。所有替换限于报告包内的 scratch，没有修改产品文件。

## Decisions and deviations

- 初次缺失 AGENTS.md 的 BLOCKED 记录保留于 `68dcb78c`。PM 授权合入 main 后协议恢复，已按首读顺序重读并解除阻塞；合入提交 `ba69c7b4`。
- 任务书的「main 版」按修复前 main 理解，使用 `790112dd^`；当前 main 已含被验实现，拿当前 main 作红侧不会区分行为。
- 所有项目夹具均在本人证据包内，未越过目录授权。未 push、未开 PR/MR（local 模式），未修改真实协议、配置、看板、实现或主工作树。
- 原始 CLI 日志保留终端颜色及空白；常规 diff whitespace 检查仅这些原始输出产生告警，非日志文件检查通过。

## Suggested next steps

- 请 PM 从独立检出复跑 `docs/team/reports/P213-verify/README.md` 中的命令并收取本地分支。P211 范围无需返工。
