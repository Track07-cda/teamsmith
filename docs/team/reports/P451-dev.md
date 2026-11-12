# P451 · flock 路径、诊断与迁移回滚收尾

agent: dev   status: delivered   time: 2026-11-12T09:56Z
branch: `task/P451-reminder-flock-diagnostics`   PR/MR: -（local 模式，不推远端）

## 结论

`tasks.md` 的 **1.3.2 已完成，父项 1.3 已勾选**。`team paths` 与真实事务共用权威助手中的同一个 flock 解析器；`team doctor` 能区分缺失、不可执行、无法运行和真实锁失败；缺锁或无锁能力时不会写入。迁移失败与回滚导出均有隔离项目实证。没有操作真实团队的 Standby 或 Reminder 状态，没有合并、归档或发布。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/state-authority.mjs` | 唯一 flock 解析器；事务使用解析出的绝对路径；锁错误点名真实锁路径、文件系统修复与未写状态；新增只读真实锁探针 |
| `skills/teamsmith/scripts/lib/common.sh` | `team paths` 新增 `flock_runner`；paths、doctor 与事务共用解析结果；真实锁探针入口 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `team doctor` 新增状态锁检查；无 Reminder 项目也检查 Standby 所需 flock；已初始化项目验证真实 `authority.lock` |
| `skills/teamsmith/tests/state-authority.sh` | 缺锁、不可执行、ENOLCK、真实锁竞争、迁移失败原状态、回滚导出恢复与新增 `flock-resolution` 翻转臂 |
| `skills/teamsmith/tests/smoke.sh` | paths/doctor 的正常、缺失与不可执行 flock 表面断言 |
| `skills/teamsmith/references/migration.md` | 新错误、静止升级、失败后的两类状态、真实导出/恢复命令；明确不存在自动回滚或旧代码 Reminder 恢复能力 |
| `skills/teamsmith/references/reminders.md` | 依赖错误与迁移指南 §9 的操作入口 |
| `openspec/changes/agent-self-reminder/tasks.md` | 仅勾选 1.3.2 与父项 1.3，并指向本报告 |
| `skills/teamsmith/tests/section-paths.tsv` | 权威段的八条翻转臂及 P451 覆盖说明 |

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 1.3.2 完整 | `flock_runner`、doctor 修复方式、真实锁失败、迁移失败与回滚导出均有产品路径和隔离断言 |
| Correctness | 通过本轮范围 | 权威夹具 140/0、投递夹具 101/0；缺锁/锁失败均不改状态；八条翻转臂成立 |
| Coherence | 通过本轮范围 | paths 与事务调用同一 `flockResolution()`；doctor 只读探测既有锁，不建立第二份路径逻辑或状态权威 |

## CRITICAL

None（本任务范围内）。

## WARNING

- 全量 `openspec validate --all` 为 20 passed / 1 failed：分支起点已有的 `panel-symlink-inside-project` 没有 delta。它不属于 P451，未修改；`agent-self-reminder` 单独校验通过。PM 收口时仍需处理该既有失败。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: 1.3.2 可交 V158 最终复验；不据此宣称整个 change 可归档。
- Unverified applicable checks and reasons: 未跑全量 smoke、夜间或 61b（任务书明确不跑）；未做独立复验（由 V158 执行）；未在真实团队状态上迁移或回滚（任务书禁止）。

## Verification evidence (must have actually been run)

### 权威、缺锁与真实锁失败

```
$ bash skills/teamsmith/tests/state-authority.sh </dev/null
✓ ⑦a 缺 flock：写待命退出码是 1（不是静默成功）
✓ ⑦g 不可执行 flock：点名实际路径与权限问题，写入非零退出
✓ ⑦i 共享解析器区分不可执行（不是 missing）
✓ ⑦j paths 使用与事务相同的 flock 解析结果
✓ ⑦k flock 返回 ENOLCK：错误点名真实 authority.lock、文件系统与未写状态
✓ ⑦m 失败来自实际执行的 flock（参数与真实锁路径已记录），不是伪造成交
✓ ⑦m2 doctor 对真实 authority.lock 的锁失败给出文件系统修复方式
✓ ⑦m4 恢复真实 flock 后 doctor 探针转绿（同一项目、同一锁文件）
✓ ⑦n 静止迁移遇到坏旧标记：显式失败并点名原因
✓ ⑦o 迁移失败后快照保持原状态
✓ ⑦q2 移走旧标记后可从导出快照逐字节恢复它
✓ ⑦r 反向改坏：恢复副本损坏会被逐字节比较发现
✓ ⑦s 从导出原件恢复后字节与待命原因都复原
flip 臂：flock-resolution,unlocked,version,foreign,standby-ignore,standby-file,standby-write,manifest
== state-authority 结果 == ✓140 ✗0 SKIP0
$ echo $?
0
```

真实锁竞争不是故障注入：一个进程持有真实 `authority.lock` 后，事务等待 5086ms 并非零退出，快照哈希前后相同；杀掉持锁者后下一事务 183ms 内成功。文件系统不支持的形状由可执行 flock 故障注入器返回 `No locks available`：调用日志证明产品确实执行了 `-x -w 5 -E 75 <真实 authority.lock>`，不是模拟事务成功；本机没有声称找到一块原生不支持 flock 的文件系统。

### 投递回归

```
$ bash skills/teamsmith/tests/remind-delivery.sh </dev/null
flip 臂：admit-any,intent-multi,observe-nogen,members-length,off-on-queue,unknown-resend,batch-cap,batch-spacing
== remind-delivery 结果 == ✓101 ✗0 SKIP0
$ echo $?
0
```

### paths / doctor / init / migration 选段

第一次组合运行覆盖全部指定段，除新增影子 PATH 夹具的五条断言外均绿：

```
$ bash skills/teamsmith/tests/smoke.sh --select 2,3,15b,17,26,64,66 </dev/null
2   init                         ✓39  ✗0
3   doctor（初始化后）           ✓7   ✗0
15b 必需依赖                     ✓25  ✗0
17  迁移指南与 doctor 指引       ✓74  ✗0
64  升级配方                     ✓1   ✗0（内部 RESULT pass=118 fail=0）
66  项目状态权威                 ✓3   ✗0（内部 ✓140 ✗0）
26  面板 / paths                 ✓151 ✗5
== 选段结果 == ✓386 ✗5
```

五条红全是新增夹具：缺锁用例仍指向含 flock 的旧 PATH，以及把 Bash `command -v` 的返回误当成可执行性判断。只修夹具后重跑同一段：

```
$ bash skills/teamsmith/tests/smoke.sh --select 26 </dev/null
✓ 26-k paths：缺 flock 时如实给出空解析结果
✓ 26-k flock：没有 Reminder 的项目缺 flock，doctor 仍失败
✓ 26-k flock：失败行区分 PATH 中缺失
✓ 26-k flock：缺失行给出安装修复方式
✓ 26-k flock 夹具：PATH 里有 flock 文件但不可执行（不是空 PATH 假象）
✓ 26-k flock：不可执行 flock → doctor 失败
26 · 面板 · ✓156 ✗0 SKIP0
== 选段结果 == ✓219 ✗0
$ echo $?
0
```

这些是两次选段的组合证据，不声称最终提交上做过一次全量运行；未跑段以原始日志的 not-run 清单为准。

### OpenSpec / 结构 / 账本 / diff

```
$ "$HOME/.bun/bin/openspec" validate agent-self-reminder --type change
Change 'agent-self-reminder' is valid
$ echo $?
0

$ "$HOME/.bun/bin/openspec" validate --all
✗ change/panel-symlink-inside-project
  Change must have at least one delta. No deltas found.
Totals: 20 passed, 1 failed (21 items)
$ echo $?
1

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14077 effective line(s); retired 0; undeclared 0
$ echo $?
0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ echo $?
0

$ git diff --check
（无输出）
$ echo $?
0
```

Ledger ban（最终报告写入后在本工作树运行）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree> scope=published files=2752 hits=0 names=ok user=resolved
$ echo $?
0
```

- Verdict: pass（P451 指定行为与相关选段）；全量 OpenSpec 的既有失败单列，未掩盖为绿。
- Notes: 原始输出保存在 `/var/tmp/p451-dev/`；未跑全量 smoke、夜间、61b，未接触真实团队 standby/state。

## Flip evidence (required for defect-fix tasks)

```
# flock 解析：删掉执行权限检查
原实现：unusable  <bad-path>/flock  not an executable regular file
变异体：ok        <bad-path>/flock
✓ flip（不查执行权限）：⑦i 与 paths/doctor 判据会红
恢复后：== state-authority 结果 == ✓140 ✗0

# 无锁直写（保留的承重翻转）
原实现：6×10 并发分配恰好得到 1..60，high-water=61
变异体：序号/high-water 不再满足无丢更新判据
✓ flip（不持锁的直写）：并发断言变红

# 回滚恢复副本
向 state.restore-check.json 追加 corrupt restore → cmp 非零（红）
重新 cp 导出原件 → cmp 为零且 standby.reason 复原（绿）

# 新增 paths 夹具自身
错误 PATH + 错误 command -v 预判 → 26-k 五条红
修正夹具，不改产品 → == 选段结果 == ✓219 ✗0
```

## Decisions and deviations

- flock 解析实现放在权威助手而不是另写一份 Bash 搜索逻辑；`team_flock_check()` 只调用该助手，事务再使用同一解析出的绝对路径。
- doctor 只在定位器与 `authority.lock` 已存在时做真实锁探针；未初始化项目只报告二进制解析结果，不为了诊断创建项目状态。
- ENOLCK 使用可执行故障注入器并记录真实调用；真实锁竞争另行使用系统 flock 实测，两者没有混为同一证据。
- 文档明确区分导入前失败（原快照与旧标记不变）和原子改名后 write/fsync 结果不确定（检查 `standby.migrated`，不假定已回滚）。
- 没有新增 `team remind export` 或自动回滚命令；文档只给实际可运行的 `cp` 与 `node -e`，旧代码不会读取或重放 Reminder 快照。

## Suggested next steps

- 由 V158 在独立检出复验 1.3.2，重点抽查缺失/不可执行 flock、真实锁探针和迁移失败哈希；独立结论前不宣布整个 change 可归档。
- PM 另行处理分支已有的 `panel-symlink-inside-project` 空 delta，使全量 OpenSpec 恢复通过。
