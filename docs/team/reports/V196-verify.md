# V196 · 任务标签与看板独立验证

agent: verify   status: BLOCKED / NEEDS CHANGES   time: 2026-11-25T02:57:42Z

branch: `task/V196-task-labels-behaviour-verify`   PR/MR: -

**候选 `6ce75ccf57002aa33724b3e0fea3c292bedd2256` 不可接受。** `team board label define --color '#0969da' -- '-Follow-up'` 拒绝了应支持的标签名；窄屏测试又因取行规则不匹配实际排版而失败，原始两帧中的同一张卡片文本实际相同。原生记录为 FAIL：636 项通过、3 项失败、3 项跳过。按任务书的 `&&`，同一终端里的键鼠操作、实际刷新与算分反例都未启动；真正的原始分数 `T2=8` 已保存。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reviews/P497.md`、`docs/team/reviews/P497-verify.log` | 原生 `team review` 写入的候选记录与日志；HEAD 干净，判定 FAIL，实际运行 182 秒。 |
| `/var/tmp/v196.6KbcGb/` | 原始 `run.sh`、`smoke.log`、`smoke.rc`、`pty-socket-path`。宿主作业 `v196-p497-candidate` 已收取，外层退出 1。 |
| `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.BmGQb8/` | 本次 smoke 保留的看板、标签表、实际列表与机器输出和两份 59 列 ANSI 原帧；`sections.tsv` 为逐段记录。 |

独立源：`/var/tmp/p497-review-6ce75ccf.buY10v`，候选执行后 `git status --short --branch` 只有 `## HEAD (no branch)`。运行记录点名隔离的 `/var/tmp/.t-1000.WfNbkq`（smoke）与 `/var/tmp/tl-pty.8jRxr8`（后续终端预留，未启动）；标签输入与输出在本次 smoke 的私有 `repo/docs/team`。无真实 Pulse、看板、巡检或设置写入；原件留待 PM 收存。

## OpenSpec assessment

固定检出与验证工作树未生成 `.pi/skills/openspec-verify-change/SKILL.md`，按 `skills/teamsmith/references/openspec.md` §6 做等价评估；未用全库结构校验代替行为结果。

| Dimension | Assessment | Evidence |
|---|---|---|
| Completeness | 不完整 | 工件 5/6 为作者完成项，3.1 未勾且本批未通过。三个新增 CLI 要求已执行正向样本，但按名字管理的选项分隔不满足；两个面板要求仅有固定画面和机器输出证据，没有实时操作证据。 |
| Correctness | FAIL | 原生 §4c 为 42/0；§6d 为 61/2，两条红来自同一 CLI 拒绝；§28 为 175/1，失败的是原帧取行，不是已证实的卡片文字回归。真算分 `T2=8`，反例未运行。 |
| Coherence | 部分 | 候选的 plain `ls/row` 与旧版同输入输出相同；可选 board 数据在缓存开关下逐字节相同；机器入口不请求标签。CLI 分隔符未从公共入口传到标签解析；共享文本函数移出面板子目录后，现有重建场景只复制了旧目录。 |

## CRITICAL

- **F1 · 承诺支持的名称被公共入口误当成选项。** §6d 真实输出 `unexpected or repeated option: -Follow-up`，接着找不到这条定义。`skills/teamsmith/scripts/team:38` 消费第一个 `--` 并把剩余形参转交，`scripts/lib/cmd-docs.sh:111` 的 `board label` 转发时已没有原分隔符，`scripts/task-labels.mjs:124–127` 因而仍按选项解析 `-Follow-up`。这不是标签内容被净化，也不是测试没带 `--`。请让公开命令的标签选项解析真正接到此分隔符，保留原有全局选项含义；用原 §6d 命令验证成功与目录实际保存的逐字名称，不把多加一个 `--` 改成用法。公共入口与本席位写权无关，交回 PM 协调修订范围。

## WARNING

- **F2 · 59 列检查的取行规则错了，实际卡片没有变。** `tests/smoke.sh:14885` 在去色后找 `› · V14 独立复验`，但两份原帧都在 `V14` 和标题之间补了 **4 个空格**；`p28h-59.card` 和 `p28h-59-labels.card` 各 0 字节。原帧离线取同一个 `V14` 焦点行，各 1 行且逐字相同，见下。请只修现有取行条件，使其容纳 ID 的固定补空，仍要求非空和逐字比较，不放宽对产品行内容的断言。
- **F3 · 重建实际失败，被误报成依赖装不上。** 这是 §28 带来的既有 §26-a，不是另开重建。保留的 `p10-build.log` 显示冻结安装完成（45 个包），紧跟着 `panel/src/sanitize.ts:13:26` 找不到 `../../text-sanitize.mjs`；`tests/smoke.sh:13659` 复制的是 `scripts/panel` 而不是现在所需的同级共享文件，现场的 `p10-panel-build/` 可查。旧分支把所有未写出 `panel.js` 的结果都记作条件 SKIP。请让既有副本具备实际相对导入的文件；能安装而构建失败时应按构建失败报告，不必新增检查。作者在完整源树上的构建回执可引用，不能抵消这个隔离重建的缺口。

## SUGGESTION

- None.

## Final assessment

- Counts: CRITICAL 1 · WARNING 2 · SUGGESTION 0。
- Readiness: 候选不能放行；3.1 保持未完成，不到合并版核对或收尾定稿阶段。
- Unverified applicable checks: `panel-b3.sh board` 未执行，实际键/鼠同卡、同一界面实时改权重和颜色、无说明文件的真实详情、标签表损坏到恢复、表外同 ID 在插入新任务后的详情刷新，以及默认历史窗口和会话选择等实际操控未验证。按约定只读过写后目录同步异常分支（`task-labels.mjs:87–93`，先重命名，再同步；失败明说可能已更新并要求先重读），没注入该错误。没有 `T2=5` 反例，也没有恢复后的通过记录。§26-a 安装后无法构建；FAST 另跳过 §6 真实派单、§26-m 真实 pane。全套其余 126 段确切键见原始日志 `选段：这次没跑的段`；包括 §38，未另跑。未重建候选、未跑结构全检、真实性能、真实模型或发布检查。

## Verification evidence

```sh
bash -n /var/tmp/v196.6KbcGb/run.sh
TEAM_GATES='bash /var/tmp/v196.6KbcGb/run.sh' bash skills/teamsmith/scripts/team review P497 \
  --dir /var/tmp/p497-review-6ce75ccf.buY10v --branch 6ce75ccf57002aa33724b3e0fea3c292bedd2256
# Runner (candidate cwd, TMPDIR=/var/tmp, private TMUX_TMPDIR, TEAM_SMOKE_KEEP=1 TEAM_B3_KEEP=1):
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 4c,6d,28 </dev/null
# 15 段收口 · ✓636 ✗3 SKIP3
# smoke_rc=1
# panel-b3 and score mutation not run: selected smoke did not pass
# team review: FAIL，182s；外层 rc=1
```

实际执行段：`0,0b,0c,0d,2,4,4c,5,3b,6,6d,18,26,27,28`。§4c 保留原拒绝重复、明确允许追加/审计、既有警告；§6d 的锁并发和真实 `EFBIG` 发布前失败通过；同名写入拒绝和重命名、分离历史任务后才可删除通过。该批没有另开 §37，§6d 保存的 `cache-on.json`/`cache-off.json` 输入整块比较通过。

| 读取证据（均来自同轮保留数据） | 结果 |
|---|---|
| `task-labels/pre-*` 对 `absent-*` / `invalid-*` | 对同一看板，从 `v0.4.8^{commit}`=`c34e1468` 提取脚本；对实现前 `6c48830e` 的 `skills/teamsmith/scripts/` 比较退出 0。12 个 stdout/stderr/状态文件 `cmp` 全同：`ls` 状态 1、保留 `TL70 ×2` 警告；`row` 0、首行 `First history`。缺失和非法标签表都不改变旧结果。 |
| `before-task.md` → `after-task.md` → `after-set.md` → `compatibility.md` | `T2.6` 新行七字段 `["T2.6", "", "third task", "dev", "-", "-", "todo"]`；Issue 真空白。`T1.1` 从 `todo` 改 `wip`，再 `dev` 改 `reviewer`；原测试验证其余行/列以及坏标签文件字节未改。 |
| `task-labels/{priority-original,filter,filter-priority,priority-edited}.tsv` | 初始 `T8 T2 T6 T9 T5 T1`，8 分同分依输入先 `T8` 后 `T2`、0 分同分先 `T5` 后 `T1`；只筛选 `T9 T2`，加排序 `T2 T9`；改权重 `T2 T8 T9 T6 T5 T1`，T2 从 8 变 11。`T1` 行 `0` 和 `[]`，缺失标签文件与有效空标签文件的显式读一致。后续独立的重复样本筛选留两条真 `T2`，普通 `ls` 仍显示后表的 `Unrelated same ID`。 |
| `p28h-{json,print}-{0,1}.{argv,out}` | 四个 `cmp` 退出 0；标签数据开关不改 `--json` 和 `--print --page 4` 的实际调用参数及输出。 |

59 列原帧仅证明排版，不代表真实刷新。离线去 ANSI 后按 `V14` 提取（各恰 1 行，等值 `True`）：

```text
p28h-59.txt        行 4: ' › · V14    独立复验：控制台表面'
p28h-59-labels.txt 行 5: ' › · V14    独立复验：控制台表面'
```

同轮带标签的帧含两个入口 `全部任务`/`看板顺序`，目标表含标签、排序和卡片点击目标；这不证明鼠标或键盘实际落在同一任务。候选现成交付 `panel.js` 的 `sha256sum` 为 `cae80ab589032b4cf44347d2963f143a62524a670391220a5eb17c6734d1aee1`，与作者记录一致；未声称隔离重建通过。

- Ledger ban（仅在本报告分支运行）：

  ```sh
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=3065 hits=0 names=ok user=resolved
  ledger_ban_rc=0
  ```

## Flip evidence

§6d 的 `priority-original.tsv` 原件有实际 T2 行 `T2\ttodo\t8\t["Bug","Urgent"]\tOffline drafts`，对应未改 `board-six.md` 与 `catalog-six.tsv` 同目录。因正向批次已失败而按任务书先交归因，私有副本的 `scores()` 求和改最大及那一次实际查询未执行；没有把预期 `5` 或不变的 ID 序列充作反例。

## Decisions and deviations

未改产品、正式测试、OpenSpec 勾选或真实团队状态，未推送。只补读原始帧、输出/状态文件和源代码归因，没有 rerun；原生中央 FAIL 和原始 0 字节 `.card` 文件均保留。

## Suggested next steps

**BLOCKED:** 请 PM 交作者修 F1、F2，并就 F3 修复所需的原 §26-a 复制和错误归类范围授权。候选重新冻结后，优先补对应 CLI、窄屏与被挡住的真实终端和一次算分反例；保留本次可复用的原件，不把首轮 FAIL 改成通过，不默认启动全套。
