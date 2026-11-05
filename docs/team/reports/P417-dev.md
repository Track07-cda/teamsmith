# P417 · 版本记录没人写，于是永远过期 —— 改向：不写记录，删掉记录

agent: dev   status: DONE   time: 2026-11-05T06:40Z
branch: `task/P417-mark-loaded-at-launch`   PR/MR: -（local 模式：提交留在任务分支）

## 交付内容（一句话）

`state/pm-loaded.env` 这条「谁来写」的链条整条删掉；会话新旧改由**已有事实**推导 —— PM 进程的启动时刻
（`/proc/<pid>/stat` 的 starttime，复用 `team_orphan_start_epoch`）与 skill 文件最近 mtime（`SKILL.md` +
`extension/*` + `scripts/*` 的顶层文件）。磁盘更晚就提示并给出那个时刻与 `/reload`，否则静默；没有 PM 在跑
时只说磁盘版本。doctor 与 `team version --check` 同一条判据。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-update.sh` | 删 `team_loaded_env/fields/version/hash` 与 `team_cmd_mark_loaded`；新增 `team_skill_mtime` / `team_skill_mtime_when` / `team_pm_age_pid` / `team_skill_stale_line`；`team_update_notice`（digest）与 `team_cmd_version_check` 改成推导三态（磁盘更新 / 与磁盘一致 / 没有 PM 在跑） |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | doctor：`team_migration_reasons` 只留 AGENTS.md 旧名标记一条判据；skill 新旧另起一行 `skill 新鲜度`（磁盘比 PM 新才出现，否则整行不出现） |
| `skills/teamsmith/scripts/team` | `mark-loaded` 子命令变「已移除」说明行（rc=2，指出替代做法）；已移除命令的 `/reload` 提示改由推导判断 |
| `skills/teamsmith/scripts/strings/commands.tsv` | `mark-loaded` 行改成与 `merge/pr/gh` 同形（read-only、无参数、不写 state） |
| `skills/teamsmith/scripts/strings/help.en.tsv`、`help.zh.tsv` | `mark-loaded` 页改为「已移除的版本记录」；`version`/`reload` 的 see 行去掉它；删掉 `--version` 参数条 |
| `skills/teamsmith/tests/smoke.sh` | 新增 `smoke_skill_copy`（可改 mtime 的 skill 副本，真树不写）；§11f、§17 换成推导两侧断言；§3b、§11h F21 同步；§11f 标题去掉 mark-loaded |
| `skills/teamsmith/tests/help-surface.sh` | 删整张「记录时间字段」哨兵机制（`IDEMPOTENT_TIME_FIELDS`/`idem_*`）与 5 条对应翻转（⑯–⑳）；幂等探针回到「逐字节不变 + 退出码一致」，1.1s 间隔保留；**顺带修好长期空转的翻转 ⑪**（见 Flip evidence 二） |
| `skills/teamsmith/tests/lib/main-team-fingerprint.sh` | 指纹豁免表里去掉已不存在的 `pm-loaded.*` |
| `skills/teamsmith/tests/section-paths.tsv` | 3b/11f/11h/17 四行的「段内调用」与 11f 描述同步（不再点名 mark-loaded） |

## 验证证据（都是本树实跑）

**1. 一次真实流程**（`/var/tmp` 独立项目 + 独立 tmux session，skill 副本 mtime 全钉在 2020）

```
$ team up
✓ PM 已启动（cli=pi，proof=argv，model=deepseek/deepseek-flash）
pm.pid=1787840
$ ls .pi/team/state/pm-loaded.env
ls: cannot access '.pi/team/state/pm-loaded.env': No such file or directory      ← 起 PM 不再写记录
$ team doctor | grep -E "skill 新鲜度|迁移指引"
（无）                                                                          ← 磁盘不比 PM 新 → 静默
$ team version --check | tail -1
✓ 一致：磁盘 skill 0.4.1 在这台 PM 启动之后没有改动

$ touch "$D/skills/teamsmith/SKILL.md"          # 磁盘比这台 PM 新
$ team doctor | grep "skill 新鲜度"
  skill 新鲜度          ! 磁盘上的 skill 在这台 PM 启动之后有改动（2026-11-05T05:35:55Z 起）：/reload 或重启 PM 生效
$ team version --check | sed -n '5p;11p'
  最近改动   2026-11-05T05:35:55Z（SKILL.md）
! 磁盘上的 skill 在这台 PM 启动之后有改动（2026-11-05T05:35:55Z 起）：/reload 或重启 PM 生效

$ touch -d '2020-01-01T00:00:00Z' "$D/skills/teamsmith/SKILL.md"
$ team doctor | grep -E "skill 新鲜度|迁移指引"
（无）                                                                          ← 改回旧时间 → 静默
$ team version --check | tail -1
✓ 一致：磁盘 skill 0.4.1 在这台 PM 启动之后没有改动

$ team mark-loaded; echo rc=$?
✗ mark-loaded 已移除：会话新旧由推导得出——PM 进程启动时刻 vs skill 文件的最近改动时刻，跑 team version --check 或 team doctor
rc=2
$ team help mark-loaded
teamsmith · mark-loaded — the removed version record
```

**2. 选段门禁**（最终树 `7deaa2c0`）

```
$ bash skills/teamsmith/tests/smoke.sh --select 3,3b </dev/null
== 选段结果 ==  ✓ 132  ✗ 0
$ bash skills/teamsmith/tests/smoke.sh --select 11f,3b </dev/null     # 最终树上再跑一次
  ✗ README 安装 pin 与 package.json（version=0.4.1）不一致： README.md:60=@v0.4.0 README.md:61=@v0.4.0 README.md:66=@v0.4.0 README.md:67=@v0.4.0
== 选段结果 ==  ✓ 143  ✗ 1        ← 唯一一红是既有漂移，见「边界与待办」
$ bash skills/teamsmith/tests/smoke.sh --select 17 </dev/null
== 选段结果 ==  ✓ 219  ✗ 0
$ bash skills/teamsmith/tests/smoke.sh --select 11h </dev/null
== 选段结果 ==  ✓ 106  ✗ 0
$ bash skills/teamsmith/tests/smoke.sh --select 51 </dev/null      # FAST 静态组
== 选段结果 ==  ✓ 27  ✗ 0
$ bash skills/teamsmith/tests/help-surface.sh --select claims,coverage --flip
  ✓ claims: mark-loaded 只读（跑完后状态指纹不变）
  ✓ claims: mark-loaded 幂等：第二次跑退出码与第一次一致（rc 2 → 2）
  ✓ claims: mark-loaded 幂等（第二次跑逐字节不变）
== 结果 ==  ✓ 121  ✗ 1        ← 唯一一红是翻转 ⑪（既有），见 Flip evidence 二
```

新断言（§11f / §17）在最终树上全部绿：`没有 PM 时明说不判断会话`、`磁盘比 PM 新时给出提示`、`提示里给出那个
改动时刻`、`改回旧 mtime 后静默`、`磁盘比 PM 新时 doctor 多打一行`、`不再有「本会话加载 X」这个说法`、
`迁移指引仍然只打一行（两件事分开说）`。

**3. 其余验收行**

```
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ git diff --check
（无输出）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2394 hits=12 names=ok user=resolved
$ echo $?
1
```

`hits=12` 逐条落在 **PM 拥有的账本文件**上，没有一条来自本任务改动的文件：`docs/team/tasks/P415-safe-dir-own-group.md`
（5）、`docs/team/reviews/P415.md`（1）、`docs/team/tasks/P417-mark-loaded-at-launch.md`（2）、
`docs/team/tasks/P418-session-file-mode.md`（4）。主检出上跑是同一批命中（改动前后都一样红），不是本分支引入。

## Flip evidence

**一、推导的两侧都是承重的**（产物内 `team_skill_stale_line` 只改一行，跑完 `sha256sum -c` 逐字节还原，两次都 `OK`）

```
FLIP-A：把比较行换成 `return 0`（推导删掉，永远「没更新」）
  11f ✗ 磁盘比 PM 新时给出提示 / ✗ 提示里给出那个改动时刻 / ✗ 提示了 /reload 生效方式 / ✗ 说明了 scripts 不需要刷新
  17  ✗ 磁盘比 PM 新时 doctor 多打一行 / ✗ 说的是「磁盘比进程新」，不是「本会话加载 X」 / ✗ 提示里给出那个改动时刻 / ✗ 另一条判据也在
== 选段结果 ==  ✓ 229  ✗ 9
FLIP-B：把比较行换成 `:`（不分新旧，永远「有更新」）
  11f ✗ 改回旧 mtime 后静默（说「没有改动」） / ✗ 改回旧 mtime 后不再提示
  17  ✗ 改回旧 mtime 后 doctor 静默
== 选段结果 ==  ✓ 234  ✗ 4
```

**二、顺带发现并修好一条长期空转的红侧（⑪）**：它的变异字面量是 `"__inbox-write __panel-data"`，而声明是三个名字
（`__inbox-write __notify-settle __panel-data`）—— 替换静默空转，于是它长期报「没有红（检查看不见这个破坏）」。

```
$ TEAM_HELP_SURFACE_TREE=<f4459e54 的导出> TEAM_HELP_SURFACE_FLIP_ONLY=internal-list-short bash …/help-surface.sh --flip
  ✗ 翻转 ⑪声明清单里删一个内部名 没有红（检查看不见这个破坏）
== 结果 ==  ✓ 132  ✗ 1          ← 改动前就红，不是本任务引入
$ TEAM_HELP_SURFACE_FLIP_ONLY=internal-list-short bash skills/teamsmith/tests/help-surface.sh --flip   # 修字面量后
  ✓ 翻转 ⑪声明清单里删一个内部名：  ✗ 内部入口清单：dispatcher 的 __ 标签 __inbox-write 不在声明清单里
== 结果 ==  ✓ 132  ✗ 0
```

## 删掉的断言与被顶替的（减法清单）

| 删掉 | 位置 | 顶替 |
|---|---|---|
| `mark-loaded 退出码 0` / `mark-loaded 记录了当前版本` | smoke §11f | `没有 PM 时明说不判断会话`（没有记录可写了） |
| `版本记录写进 state`（`pm-loaded.env` 存在）/ `记录里含内容指纹` | smoke §11f | `磁盘比 PM 新时给出提示` + `提示里给出那个改动时刻` |
| `本会话是旧的` / `提示了 /reload` / `说明了 scripts 不需要刷新`（记录臂） | smoke §11f | 同三条断言改挂在推导臂上（磁盘比 PM 新） |
| `旧会话版本 → doctor 指向迁移指南` / `指引说明的是版本这一条判据` | smoke §17 ③ | `磁盘比 PM 新时 doctor 多打一行` / `说的是「磁盘比进程新」，不是「本会话加载 X」` |
| `版本一致后指引消失` | smoke §17 ③ | `改回旧 mtime 后 doctor 静默` |
| `两条判据同时成立仍然只打一行`（原指记录 + 标记） | smoke §17 ④ | `迁移指引仍然只打一行` + `另一条判据也在（两条判据各一行）` |
| `版本落后时提示 /reload`（已移除命令的提示臂） | smoke §3b | 无（该提示改由推导判断，§11f ② 已覆盖；3b 保留 `merge` 的替代做法断言） |
| `旧会话的 version --check 退出码 0` / `本会话是旧的`（F21 的旧分支） | smoke §11h | `磁盘比会话新的 version --check 退出码 0` + `走的仍然是「磁盘比 PM 新」这条` |
| 整张 `IDEMPOTENT_TIME_FIELDS` 哨兵机制（`idem_fields`/`idem_stamp`/`idem_names`，59 行） | help-surface | 幂等探针回到「第二次跑逐字节不变 + 退出码一致」；1.1s 间隔保留（同秒改写仍然看不见） |
| 翻转 ⑯ `mark-loaded-rewrites`、⑰ `time-field-gone`、⑱ `clock-undeclared`、⑲ `missing-time-field`、⑳ `second-run-fails` | help-surface | 无（它们钉的是已删机制）；幂等本身仍由 ⑮ `idem-writes` 反向验证 |

净减：产品 + 测试合计 **199 插入 / 318 删除**（首笔提交前 `git diff --stat`），测试侧 160 行改动里主要是删除。

## 决策与偏离

1. **`mark-loaded` 保留为「已移除」子命令，而不是直接落进 `unknown command`**：`$TEAM_CLI` 指向的那份 skill 由
   本仓发布，但别的项目会话里缓存的仍是旧版，撞上这个词时应当被告知替代做法而不是「未知命令」；同时
   help-surface 的 coverage 检查要求「dispatcher 的每个标签都有清单记录」，直接删标签会让那条检查红。这与仓里
   `merge`/`pr`/`gh` 的既有处理同形。
2. **digest 的那一行仍然打印**（三态）：它是「要不要 /reload」的唯一提示面；brief 只要求「没有 PM 时不说会话
   的事，只说磁盘版本」。
3. **skill 新旧在 doctor 里另起一行 `skill 新鲜度`**，没有折进 `迁移指引`：两者处置不同（一个是 `/reload`，一个
   是读迁移指南），合成一行会把两件事说成一件。原 §17「两条判据同时成立只打一行」因此改成「各说一句，迁移
   指引仍只一行」。
4. **`--select 51` 在 FAST 下只跑静态组**（`claims` 幂等探针不在 FAST 里），所以另跑了
   `help-surface.sh --select claims,coverage --flip`（121 通过 / 1 红＝翻转 ⑪，已修）。
5. **没有碰 `CHANGELOG.md` 与版本号**：`team mark-loaded` 的移除是用户可见变更，但五处版本一致性断言要求同步
   升版，那是发布流程的事。

## 边界与待办（交给 PM）

- `BLOCKED:` **面向读者的文档仍在教人跑已删的 `team mark-loaded`**（`SKILL.md` 与 `references/**` 不在本任务书
  授权的写集合内）：
  - `skills/teamsmith/SKILL.md:60`（Updates 行：`team mark-loaded` (record the version at session start)）
  - `skills/teamsmith/SKILL.md:133`（`team mark-loaded` once per session）
  - `skills/teamsmith/references/memory.md:30`（`team mark-loaded` / `team version --check` / `/reload`）
  - `skills/teamsmith/references/migration.md:23`（version bookkeeping 一行）、`:425`、`:429`（升级配方里让人跑它）
  建议改法：这三处改成「`team version --check` / `team doctor` 会告诉你磁盘上的 skill 是否比这台 PM 新」。
  另外 §14b「已删命令不得回潮」的扫描词只有 `merge|pr|gh|gl`，所以这些残留现在是绿的——等文档改完，把
  `mark-loaded` 加进那张表（同一张表、不是新守卫）就能常驻拦住回潮；这一步在我 `tests/**` 的写集合内，需要
  指令才做。
- `BLOCKED:` **README 安装 pin 漂移**（§11f 唯一一红）：`README.md:60/61/66/67` 仍是 `@v0.4.0`，`package.json` 已是
  `0.4.1`。`README.md` 属 PM 与发布清单（`docs/team/PUBLISH.md` §2）；本任务前后都在红，我没有动它。
- `BLOCKED:` **ledger-ban 的 12 处命中全在 PM 的账本文件**（两本任务书、两本复验/评审记录），不在我的写集合内。
- `skills/teamsmith/extension/team.ts:84` 里 `version` 的用途串仍是「磁盘版本 / 本会话加载版本」；`extension/**`
  不在授权路径内，未改。

## Suggested next steps

- 复验建议的独立断言：在别的工作树里 `touch` 一个 skill 文件后跑 `team doctor`（必须出现 `skill 新鲜度` 并给出
  时刻），再 `touch -d` 改回旧时间（必须静默）。这一对断言正是本任务的反向证明，且不依赖任何残留 state。
- 用户项目里旧的 `pm-loaded.env` 不需要清理（brief 明确）：它已经不再被读，下次升级后只是一份死文件。
