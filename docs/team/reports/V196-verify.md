# V196 · 任务标签与看板独立验证

agent: verify   status: BLOCKED / NEEDS CHANGES   time: 2026-11-25T03:11:01Z

branch: `task/V196-task-labels-behaviour-verify`   PR/MR: -

**返修候选 `4cbc5bc78eeeca78cef535c727dd22379d9360c0` 仍不能合并。** 标签名称、59 列卡片、隔离重建和故意算错四项已取得通过证据。实时终端 16 项通过、1 项失败：从 `M39 Outside` 连送三个 ↑ 后，只看到焦点上移一张到 `M51 Other`，未到目标 `M39 Second`。看板尚未进入权重更新及键鼠筛选步骤。详见下方第二轮；两轮正式 FAIL 都保留。

## 首轮 `6ce75ccf` 历史结果

**首轮候选 `6ce75ccf57002aa33724b3e0fea3c292bedd2256` 不可接受。** `team board label define --color '#0969da' -- '-Follow-up'` 拒绝了应支持的标签名；窄屏测试又因取行规则不匹配实际排版而失败，原始两帧中的同一张卡片文本实际相同。原生记录为 FAIL：636 项通过、3 项失败、3 项跳过。按任务书的 `&&`，同一终端里的键鼠操作、实际刷新与算分反例都未启动；真正的原始分数 `T2=8` 已保存。

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

**首轮 BLOCKED 处置：** PM 让作者修 F1、F2、F3，并限定下面五项补验。首轮原件与 FAIL 保留；15 段未重跑。

## 第二轮 · `4cbc5bc78eeeca78cef535c727dd22379d9360c0`

对照 `6ce75ccf..4cbc5bc7`，只变更 `scripts/team`、`tests/smoke.sh` 与作者报告。`git diff --exit-code` 比较其余 `scripts/**`、实时测试与桥接脚本、OpenSpec 工件退出 0；面板和评分实现不变。下列各项分别执行，首轮与返修检出均不写。

```sh
bash -n /var/tmp/v196-r2.LAN0n4/run.sh
TEAM_GATES='bash /var/tmp/v196-r2.LAN0n4/run.sh' bash skills/teamsmith/scripts/team review P497 \
  --dir /var/tmp/p497-review-4cbc5bc7.jNvU9J --branch 4cbc5bc78eeeca78cef535c727dd22379d9360c0
# actual executor: verify; review FAIL, 63s; review rc=1
# cli_rc=127 narrow_rc=0 rebuild_rc=0 pty_rc=1 flip_again_rc=1
bash /var/tmp/v196-r2.LAN0n4/finish-cli.sh
# cli_local_node_rc=0; board_ls_max_rc=0; T2 original=8 mutated=5 original_assertion_rc=1
# flip_local_node_rc=0; finish_cli_runner_rc=0
```

| 补验 | 结果与证据 |
|---|---|
| 1 · 命令分隔符（F1） | 私有项目执行公开的 `board label define --color '#0969da' -- '-Follow-up'`，退出 0；`--help`、`--root` 也作为分隔符后的**字面名称**写入。`label-file.tsv` 与 `label-ls.tsv` 各有三个精确值，原 `BOARD.md` `cmp` 退出 0。源码只在已有参数前两项是 `board label` 时转发 `--`；其它命令仍走旧的 `shift; ARGS+=("$@"); break`。没有重跑帮助组。 |
| 2 · 59 列（F2） | 将原 ANSI 帧复制到新根 `narrow/`，直接从候选提取并执行 §28-h 原句，不重绘。两文件各恰一行 ` › · V14    独立复验：控制台表面`，`cmp` 退出 0，SHA-256 同为 `b31eb5e2d2fddf27c167eb2bc4a242c72e03c1de07da711c3d5767484d3ec872`。 |
| 3 · 隔离重建（F3） | 带同级 `text-sanitize.mjs` 复制原面板目录，先确认副本无既有 bundle。`bun install --frozen-lockfile` 退出 0（45 个包），`BUN=… bash build.sh` 退出 0，真正生成 979784 字节；`cmp` 退出 0，SHA-256 与候选均为 `cae80ab589032b4cf44347d2963f143a62524a670391220a5eb17c6734d1aee1`。源码 `tests/smoke.sh:13662–13672`：安装失败才跳过；安装后构建失败进入 `bad`，未另造故障安装。 |
| 4 · 真实终端 | 在 `/var/tmp/tl-pty.ovdvlv` 隔离，`TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board </dev/null` 首次实际运行，退出 1，16 通过、1 失败。三张同编号卡片、真实空详情及同一界面直接改色已看见；连送 ↑ 后焦点不在预期位置，后续未执行。详见下。 |
| 5 · 算分反例 | 私有副本的 `BOARD.md` 和标签表分别与原 `board-six.md`、`catalog-six.tsv` `cmp` 退出 0。只改 `scores()` 为最大值，差异在 `sum-max.diff`。实际执行一次 `team board ls --sort priority`，命令退出 0，第三列 T2 从原 8 变成 **5**；原 `T2=8` 判据退出 1。没有重复 8 分正向查询。 |

**验证脚本准备错误与产品分开：** 正式 runner 的项目隔离环境清掉了 `CONTAINER_ID`。`PATH` 第一个 `node` 是 Distrobox 转发脚本，先失败在 `/usr/bin/distrobox: not found`，CLI 写入与算分 JS 尚未运行；首个 `priority-max.tsv` 不构成反例。只对这两项，在相同私有目录明确使用 `/usr/bin/node`（`v24.22.1`）补跑实际命令；原 127 及正式 FAIL 未覆盖，其他三项未重跑。实际最大值输出：

```text
board_ls_max_rc=0
T2 original=8 mutated=5 original_assertion_rc=1
T2    todo    5    ["Bug","Urgent"]    Offline drafts
```

**真实终端证据。** `/var/tmp/teamsmith-panel-b3-pm_skills-deb708fe.zYvwoN/board/` 的 `live-labels/board.json` 中，`M39 First`、`M39 Second`（第 1、2 条）都属任务表，名字是 `Bug`、`Urgent`，分数原文 `"8"`；后表 `M39 Outside`（第 87 条）不属任务表且无标签字段。`first-detail-reply.json` 实际为 `id=M39, count=0, files=[]`。`dup-{first,second}-detail.txt` 均显示优先级 8 和无关联文件；`dup-outside-detail.txt` 仍显示原无关联文件提示，无标签和分数。`swatch-before.txt` → `swatch-after.txt` 中 Bug 色标 ANSI 从 `38;2;9;105;218` 变成 `38;2;51;187;119`；同一详情的 `swatch-plain.txt` 仍显示两个名称和 8。真实 board 回执的 `Bug` 颜色为 `#33bb77`。

**F4 · 实时终端仍阻塞。** `dup-outside-back.txt` 有唯一光标 `› · M39 Outside`。`tests/panel-b3.sh:1171` 一次 `tmux send-keys` 发 `Up Up Up`；下一份 `dup-priority-from.txt` 的唯一光标是 `› · M51 Other`，位置仅向上一步；100 轮后立即再取，画面未变。单次 `Down` 走过 First、Second、Neighbor、Other、Outside 的各自画面已保存。`App.tsx:974–1018` 的单次移动从最近渲染的 `kanbanRef.current` 取目标再更新焦点，该引用在渲染处更新（`:2099`）；若三键同批且回调都看到同一行，也会得到现场的一步。现有原件不能区分按键是否只到达一次、还是多次处理共用同一焦点；未归成机器慢，也不宣称已经定位到产品或夹具。请用可观察的逐次焦点位置区分输入与焦点更新，别把当前失败改成更长等待；如分开发键能走通，也不等于本次连键问题不存在。

**当前 OpenSpec 评估：** 分隔符纠正、窄屏取行、隔离重建及 8→5 反例已闭合；实时结果仍不满足 `Board labels and priority are optional read-only views` 的完整可用路径。未观察到改权重后同卡聚焦和重排、键鼠筛选同卡、会话选择与历史切换、损坏/修复实时替换，以及从工作页打开后同号插入的刷新。保留 3.1 未勾；不进入合并版核对、未运行 §38 或首轮 15 段。当前计数：CRITICAL 1（现场路径未完成，F4）· WARNING 0 · SUGGESTION 0；已完成的四项可直接复用，不重跑。

**BLOCKED:** PM 交作者定位 F4 并冻结新候选；只安排必要的终端补验。原生返修记录 `docs/team/reviews/P497.md`、`P497-verify.log` 与两次私有证据原件均保留。返修根 `/var/tmp/v196-r2.LAN0n4/` 含 `run.sh`、`results.tsv`、五项分别的日志、`finish-cli.sh`、`finish-cli.log` 和 59 列副本；此前 CLI 环境错误也留作原始记录。
