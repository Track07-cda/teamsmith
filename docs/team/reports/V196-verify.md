# V196 · 任务标签与看板独立验证

agent: verify   status: CANDIDATE PASS / MERGED SHA PENDING   time: 2026-11-26T03:00:54Z

branch: `task/V196-task-labels-behaviour-verify`   PR/MR: -

**冻结候选 `f9bb3f3512e1efc96f2f21a5b5d36ce7bc77f9d8` 的 V196 独立验收通过，待 PM 接受后核对合并版本。** 真实终端 46 项通过、0 项失败；此前未到达的英文 59 列鼠标选择、草稿编辑、选择不写入项目与偏好，以及筛选刷新后焦点与 Enter 读到正确任务，均有本次原画面和回执。前四轮正式 FAIL 保留；未把候选结果当成合并版本或全量发布检查通过。

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

## 第二轮 · `4cbc5bc78eeeca78cef535c727dd22379d9360c0`（历史结果）

该候选实时终端 16 项通过、1 项失败：从 `M39 Outside` 连送三个 ↑ 后，只到 `M51 Other`，没有到 `M39 Second`。这一轮没有进入权重更新及键鼠筛选步骤。

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

**第二轮 BLOCKED 处置：** PM 另派 P509 验证并修复不带标签的连续按键，再按新方案接入。第二轮原生记录与原件保留。返修根 `/var/tmp/v196-r2.LAN0n4/` 含 `run.sh`、`results.tsv`、五项分别的日志、`finish-cli.sh`、`finish-cli.log` 和 59 列副本；此前 CLI 环境错误也留作原始记录。

## 第三轮 · 接入现行看板 `4a8bf012fe1fc0c38dfb2e359719f40206cd3b40`（历史结果）

正式记录 `docs/team/reviews/P497.md`、`P497-verify.log` 绑定该冻结 SHA，由 `verify` 实际执行，74 秒，FAIL、外层退出 1。固定检出 `/var/tmp/p497-review-4a8bf012.g5PgLX` 运行前后均干净；合并 `2494ac7b` 的实际父提交为 `4cbc5bc7` 与 `d8968556`。首两轮正式记录仍在 `.pi/team/state/evidence/P497/{round1,round2}`。

```sh
bash -n /var/tmp/v196-r3.cFA6ko/run.sh
TEAM_GATES='bash /var/tmp/v196-r3.cFA6ko/run.sh' bash skills/teamsmith/scripts/team review P497 \
  --dir /var/tmp/p497-review-4a8bf012.g5PgLX --branch 4a8bf012fe1fc0c38dfb2e359719f40206cd3b40
# preparation_s=0（整秒）
# sources_rc=0 seconds=0; legacy_rc=0 seconds=1; cache_rc=1 seconds=0
# frame_machine_rc=0 seconds=1; pty_rc=1 seconds=72
python3 /var/tmp/v196-r3.cFA6ko/check-cache-artifacts.py /var/tmp/v196-r3.cFA6ko/cache/task-labels
# cache_equal=1 bytes=2042; original_rows_equal=1; cache_artifact_rc=0（0.026s，只读原件）
```

| 独立检查 | 执行、读数与证据边界 |
|---|---|
| 旧证据可复用的范围 | 实际 `git diff --exit-code 4cbc5bc7 HEAD -- …` 确认公开入口、`task-labels.mjs`、`cmd-docs.sh`、共享清理和标签测试桥接均无差异；`common.sh` 的标签读写辅助未变。候选 §6d 的六行原输入经提取与首轮 `board-six.md` `cmp` 退出 0；保留旧 `catalog-six.tsv`、`priority-original.tsv` 和 `priority-max-local-node.tsv` 的哈希。旧真实 `T2=8`、错算法真实 `T2=5` 继续有效；未重跑分隔符、目录命令矩阵、评分或反例。V205 `b2b2785a` 仅接受方案 `f36d1e51`；V202/P509 的独立连续键对照仅证明不带标签的原看板。 |
| 构建证据边界 | `build.sh`、`package.json`、`bun.lock`、`src/sanitize.ts` 与同级 `text-sanitize.mjs` 对返修候选无差异；隔离复制配方有第二轮记录。第三轮实际使用的 bundle 981443 字节，与固定提交及作者真实构建 SHA-256 `0dbbc61704aa1f9c960c8c9fad00964cf4ca1c57ea13af307098b0412a09108e` 一致。新 `App.tsx`、`layout.ts` 等有变化；**没有重新安装依赖或在新候选隔离重建**，旧 `cmp` 不充当新包的隔离重建回执。 |
| 新旧普通命令及写入 | 从候选 §6d 源提取 `TL_BOARD` 到兼容写入结尾，用旧现场的原 `old-layout.md` 准备同一私有项目。候选与 `git archive d8968556…` 提取的 `team` 都实际读同一 `BOARD.md`；无标签文件和坏标签文件两种状态，`board ls` / `board row TL70` 的 stdout/stderr/退出状态共 12 对逐字相同。`ls` 退出 1 并保留 `TL70 ×2`；`row` 退出 0，返回 `First history`。同现场实际执行 `team task T2.6 --title 'third task' --category routine --agent dev`、`board set T1.1 wip`、`board assign T1.1 reviewer`：新行七个业务值为 `T2.6, 空 Issue, third task, dev, -, -, todo`，最右 `2030-01-01T00:00:01Z`；T1.1 仅目标业务列和最右时间变化（`…02Z`、`…03Z`），未改无关行或坏标签文件。私有时钟只固定可核的 UTC 输入，写入走真实命令。 |
| 可选 board 数据 | 候选实际执行 `team __panel-data --block board --with-labels` 两次，第二次 `TEAM_SCAN_CACHE=0`；2042 字节完全相同，SHA-256 `9732077c72c9c92e25f1ea7da84206349f2d781cc0fc676c2635b961475afe7f`。同项目实际普通 `__panel-data --block board` 的原行、原序、计数和交付与可选读法一致（剔除新增的两个字段后）。两个真 T2 保持原表序，时间分别 `2026-01-02T00:00:01Z`、`:03Z`，均为 `Bug, Urgent / 8`；后表同编号无标签、无分数、无更新时间。查看起初的红：验证辅助的 ID 预期漏掉普通读者也保留的外表表头 `Ref/State`。该表头与后两行都标为表外，无标签；在保留 JSON 上只读验证确认，无产品重跑，无正式日志覆盖。实际原序 `T9 T8 T5 T2 T2 T1 T6 Ref R1 T2`。 |
| 新 59 列画面、机器输出 | 用候选 §28-h 的实际 `panel.js --snapshot … --width 59 --height 40 --page 4` 分别各渲染一次，旧原帧没有作输入。每份恰一张 46 字节焦点卡行，去色后 ` › · V14    独立复验：控制台表面` 逐字相同；有标签画面含 `全部任务` 与 `最近更新`。同一确定输入实际调用 `panel.js --json`、`panel.js --print --page 4`，候选两种标签开关与 `d8968556` bundle 的每条调用参数清单和输出字节都一致，均无 `--with-labels`。`--json` 1044 字节、`--print` 658 字节。只运行这两帧、指定机器入口及基准各一次，不运行 §28 其余检查；这些帧不是实际刷新。 |
| 同一终端实际操作 | `TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board </dev/null` 仅一次（专用 `/var/tmp/tl-pty.X4RPnc`），退出 1，26 通过、1 失败。终端实测无标签段的更新顺序、同值不改时间、真实鼠标二次打开 M9、99/59 窄窗越界跟随、两个历史栏与滚轮、无标签同号 `Down Down` 和工作页原表序。标签段原帧 `label-history-default.txt` 显示 `M39 Second → First`、`D04 D02 D40` 与 `X04 X02 X40`，唯一光标在 `M39 Second`；Enter 后显示 `M39`、标签 `Bug / Urgent`、优先级 8 和已有任务书。下面两处缺口挡住后续。 |

**F5 · 同一终端的空详情样本被前段的任务书占用。** `tests/panel-b3.sh:1140` 在前段写 `tasks/M39-board.md`（`Board body M39 proof`），`:1274` 正常用它验证真实详情；切到标签段复用项目，未撤下这份本次测试自己创建的任务书，`:1375` 却要求 `没有关联文件`。现场私有 `board/root/docs/team/tasks/M39-board.md` 确实存在；`dup-first-detail.txt` 同时显示 `[brief]`、`优先级 8`、`● Bug ● Urgent`、`Board body M39 proof`。100 轮后再取仍稳定，不是数据来晚，也不是产品丢了文件。保留前段的有文件检查后，给标签段安排真正无文件的样本；不要把现有空详情断言改成接受有文件。

**F6 · 真实回执保存被另一入口绕过。** 同一轮 `live-labels/` 只有 `label-dup-start.focus`，虽已实际打开有文件详情，但没有 `detail.json` 或 `board.json`。`tests/panel-b3.sh:1042–1057` 为整个 `scn_board` 设本地 `panel_cli=board_cli`，由 `start_panel`（`:238–244`）传到运行中的面板；`board_cli` 对 board/detail 直接 `exec` 真实 CLI，只把其他块交给 stub。`:1306` 新设 `B3_REAL_*` 的保存分支只存在于 stub（`tests/panel-b3-stub.sh:51–57`），因此两个实际块走不到保存路径。单修 F5 也无法通过 `:1376` 的空详情回执保存、`:1499` 插入或 `:1527` 损坏后读取检查。请复用一个真实读取入口，兼顾私有身份校验与保存实际回复，不补固定 JSON 或第二套测试。

**当前 OpenSpec 评估：** 源与读写、机器及初始画面接合有证据；`2.1/2.2` 在标签段只到默认窗、焦点、标签和分数的首次详情。同批连续 ↑ 与立即 `Down Down Enter` **在有标签终端未到达**（P509 的旧无标签证据不替代）；同界面改色/权重、等分逆时序切换、跨排序与键鼠筛选、空结果、隐藏同号焦点、坏表恢复、工作页表外详情同号插入后的更新，以及后续双语与会话选择均未到达。F5/F6 是本轮两处验证阻塞，未把它们定性为产品缺陷。3.1 仍未完整，不进入合并版检查。首轮 15 段、§38、全库规格检查、新候选隔离构建、模型、安装及发布均未重跑。无真实团队界面、真实项目数据或设置改动。

**第三轮 BLOCKED 处置：** PM 让作者修同一 `panel-b3.sh board` 的 F5 与 F6；第四轮只复验实际终端，复用已取得的命令、缓存和窄屏证据。第三轮原件 `/var/tmp/v196-r3.cFA6ko/` 保存 runner、时间与各退出值、旧/新命令原件、缓存 JSON、对比器原红与离线读数、新 ANSI 帧及机器参数；真实终端原件 `/var/tmp/teamsmith-panel-b3-pm_skills-deb708fe.VC9PHK/board/`。未延长等待、重启或重跑该终端场景。第三轮报告暂存后在本任务分支执行上述 `ledger-ban.sh` 命令，回执 `scope=published files=3065 hits=0 names=ok user=resolved`，退出 0。

## 第四轮 · `2309f8c564306affaf374f67e87fb4619a1f39b4`（历史结果，仅实时终端）

**F5、F6 已闭合；新失败 F7 阻断最后一段。** 相对 `4a8bf012` 只改 `tests/panel-b3{,-stub}.sh` 和作者报告，`git diff --exit-code 4a8bf012..HEAD -- skills/teamsmith/scripts openspec/changes/task-labels` 为 0，bundle 仍是 `0dbbc61704aa1f9c960c8c9fad00964cf4ca1c57ea13af307098b0412a09108e`。前三轮中央记录保存在 `.pi/team/state/evidence/P497/round{1,2,3}/`，当前中央记录绑定新候选、不替换旧结论。

```sh
bash -n /var/tmp/v196-r4.hMakmE/run.sh
TEAM_GATES='bash /var/tmp/v196-r4.hMakmE/run.sh' bash skills/teamsmith/scripts/team review P497 \
  --dir /var/tmp/p497-review-2309f8c5.tGOIki --branch 2309f8c564306affaf374f67e87fb4619a1f39b4
# runner: TMPDIR=/var/tmp, private TMUX_TMPDIR=/var/tmp/tl-pty.5rOTkx, preparation_s=0
TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board </dev/null
# board_pty_rc=1 seconds=107；43 项通过、1 项失败（en-default）；原生 review FAIL，rc=1
```

下面的文件相对 `/var/tmp/teamsmith-panel-b3-pm_skills-deb708fe.pgzoOP/board/`。所有读取均为本次终端实际使用的输入与输出，不事后另查 CLI 补数。

| 场景 | 实际画面与回执 |
|---|---|
| 空详情（F5）及实际回执（F6） | `dup-detail.txt` 先显示 `Board body M39 proof`；同一项目内任务书移至 `live-labels/pre-label-M39-board.md` 后，`dup-first-detail.txt` 显示 `优先级 8`、`Bug / Urgent`、`没有关联文件`；`live-labels/first-detail-reply.json` 的真实 `files=[]`。同一个真实入口（`board-cli`）把数据同时交给面板和保存原件，以下三次独立刷新各留了实际 `board` JSON。 |
| 连续按键、历史位置 | `batch-detail.txt` 在一条 `Down Down Enter` 后打开 `M51` 和 `Label board M51 proof`，而非起点或中间的 `M48`；`dup-batched-up.txt` 从 Outside 连送三次 ↑ 唯一光标到 `M39 First`，下一步 `dup-priority-from.txt` 到 `M39 Second`。`label-history-default.txt` / `history-restored.txt` 的两栏开头为 `D04 D02 D40` / `X04 X02 X40`（有时间优先，然后无时间从表尾）；显式优先级 `priority-start.txt` 把 `D01/X01` 放在前面。 |
| 同终端改色、权重和焦点 | `swatch-before.txt` / `swatch-after.txt` 中 Bug 色标从 `38;2;9;105;218` 到 `38;2;51;187;119`，`swatch-plain.txt` 仍为 8 和两名称。实际 `priority-board-reply.json` 的两条 M39 均为 11，Outside 无标签与分数；`priority-start.txt` 的次序是 `Neighbor, First, Second, Outside`，`dup-back.txt` 是 `First, Second, Neighbor, Outside`，唯一光标一直在 `M39 Second`。 |
| 等分、筛选与无结果 | `tie-recent.txt` 的同分显示 `Second, First`，`tie-priority.txt` 显示 `First, Second`，选中 `Second` 和 `Bug` 筛选保留。`filter-wheel.txt` / `filter-modal.txt` 见候选列表接收滚轮和方向键；`filter-same.txt`、`filter-cross.txt` 分别在 `M48 Neighbor`、`M52 Cross lane`，`filter-no-open.txt` 的空结果按 Enter 未打开详情；`filter-renamed.txt` 回到全部任务但保留优先级，`remember-return.txt` 翻页后恢复同一筛选与排序。 |
| 表外同号、损坏和恢复 | `insert-board-reply.json` 原序的 M39 为 `First(true), Second(true), Inserted(true), Outside(false)`，计划中的第三次同号已指向新任务。开着的表外详情确实从 `Outside report before refresh` 更新为 `Outside report after refresh`，帧均无标签、无优先级。`invalid-board-reply.json` 有 88 条原行、`unavailable: true` 且无旧标签/分数，终端显示标签不可用，详情仍无文件；恢复后同终端的 `recovered-detail.txt` 又显示 `Bug / Urgent` 与优先级 11。 |

**F7 · 59 列的卡片已显示，检查拿宽屏间距找它。** `tests/panel-b3.sh:1579` 用字面 `M39 Outside` 等待；`en-default.txt` 同时有 `t Labels: All tasks` / `o Sort: Recent updates`，还确有唯一该卡行 `'   · M39    Outside'`。对该原帧离线读数：`'M39 Outside' in line → False`，`re.fullmatch(r' +· M39 +Outside', line) → True`；增加等待无效，不是产品丢卡。`:1583–1594` 和 `:1608–1618` 后面的 59 列步骤仍以单空格检查其他卡片（同一原帧的 `M48    Neighbor` 和 `M51    Other` 同理，包含／排除都会读错）。请一次改正确认窄卡行身份的方法，复用已有行匹配方式，保留完整标题、焦点和应当不出现的卡片检查，不放宽标签名本身。

**当前 OpenSpec 状态：** 沿用第三轮 CLI、缓存及新候选产物同一性；第四轮实测通过上述实时操作，不等于整个 `3.1` 通过。英文 59 列已看见重启后回到全部任务和最近更新，但随后点击精确的长标签、鼠标切换排序、`Ctrl+o` 打开草稿编辑器、配置不写入，以及筛选中刷新移除最后一条同号后的实际焦点和 Enter 未到达。无新增产品缺陷证据；该终端检查仍阻塞合并。不重跑前面通过项、§38、全套、模型或构建安装。

**第四轮 BLOCKED 处置：** PM 交作者修同一个终端案例的 F7，第五轮只补尚未达到的终端操作，不再验已保留的普通 CLI/缓存/59 列静态帧和机器输出。原始终端画面、原读取 JSON 和现场都保留，完整 `pty.log`、`pty.rc`、`pty-socket-path`、`run.sh` 在 `/var/tmp/v196-r4.hMakmE/`；未重启、重跑或延长等待。

## 第五轮 · `f9bb3f3512e1efc96f2f21a5b5d36ce7bc77f9d8`（英文 59 列收尾）

**PASS，闭合 F7。** 相对 `2309f8c5` 仅 `tests/panel-b3.sh` 和作者报告变动；`git diff --exit-code 2309f8c5..HEAD -- skills/teamsmith/scripts openspec/changes/task-labels` 退出 0，执行的 bundle SHA-256 仍是 `0dbbc61704aa1f9c960c8c9fad00964cf4ca1c57ea13af307098b0412a09108e`。现有 `board` 选段在同一函数内初始化私有项目、准备中英文阅读入口、写入待筛标签以及表外同号，因此只调用原选段一次取得前置现场，不抽取源码另做入口、不把前段重复通过计为新增覆盖。首四轮原生 FAIL 和原件不改；第四轮在 `.pi/team/state/evidence/P497/round4/`。

```sh
bash -n /var/tmp/v196-r5.i7bCWF/run.sh
TEAM_GATES='bash /var/tmp/v196-r5.i7bCWF/run.sh' bash skills/teamsmith/scripts/team review P497 \
  --dir /var/tmp/p497-review-f9bb3f35.O6jsX5 --branch f9bb3f3512e1efc96f2f21a5b5d36ce7bc77f9d8
# runner: TMPDIR=/var/tmp, private TMUX_TMPDIR=/var/tmp/tl-pty.DQLGEp
TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board </dev/null
# board_pty_rc=0 seconds=72；46 项通过、0 失败；原生 review PASS（72s），外层 rc=0
```

证据相对 `/var/tmp/teamsmith-panel-b3-pm_skills-deb708fe.oDvx5T/board/`，除明示的离线比较外均为同次运行保存的实际画面或读取：

| 本次补齐项 | 结果及原件 |
|---|---|
| 完整卡片、保留原点击坐标 | `en-default.txt` 的原行仍是 `   · M39    Outside`，同帧还有同号 `First`、`Second`、`Inserted`；`.txt.observed` 另列 `B3 card: [M39 Outside]`，按整条 ID 和标题匹配。候选只去掉 ID 和标题之间的排版空格，不改作点击定位的原帧，也不把同号卡合在一起。 |
| 两个长标签及鼠标排序 | `en-labels.txt` 同画面列出 `Shared label text beyond the control width A` 与 `… B`。鼠标选择 B 后 `en-filter-b.txt` 唯一任务是 `M51 Other`，选择 A 后 `en-filter-a.txt` 唯一任务是 `M48 Neighbor`；两次都不显示另一个任务。`en-priority.txt` 显示鼠标选择后的 `Sort: Priority`，仍仅有 `M48 Neighbor`。 |
| 普通／草稿 `Ctrl+o`，选择不写入 | 普通看板按键前后 `en-priority.txt` 和 `en-plain-only.txt` 离线 `cmp` 退出 0；画面未打开选择器或跳页。草稿 `en-compose.txt` 显示 `Enter send`，`root/.pi/team/state/editor.receipt` 保存同一项目的 `root/.pi/team/state/draft.md`，未发送。实际场景在后续故意改标签前，已用两次 `cmp` 确认选项使用前后的 `task-labels.tsv` 和 `panel.conf` 逐字相同；配置原件另比对 SHA-256 `4f7b691342621627f84f7a22de464e74a4a26883d12e0e2ec1899d96d95d7f3f` 相同。 |
| 删除最后一条匹配同号后，焦点和 Enter | `fallback-before.txt` 唯一焦点 `M39 First`，同时能看到 `M39 Second` / `Inserted`，看不到 `Outside`。删除三个表内 M39 并刷新后，同一次请求回执 `live-labels/fallback-board-reply.json` 只剩 `M39 Outside`（`taskTable:false`、无 `labels`）；匹配的 `M48 Neighbor` 和 `M51 Other` 都还在。`fallback-focus.txt` 唯一焦点为 `M48 Neighbor`，不显示任何 M39；Enter 的 `fallback-detail.txt` 标题 `detail M48`、正文 `Label board M48 proof`，真实 `live-labels/detail.json` 的 `id=M48`、`files[0].path=docs/team/tasks/M48-board.md`。 |

**验收边界：** 候选 `3.1` 的独立行为证据至此齐备，由 PM 接受并决定合并；合并版本尚未验证，`3.1` 未由 verifier 改勾。旧 CLI、缓存、机器和静态画面仍引用实际保存的记录；未新跑 §38、全套、模型、依赖安装、隔离重建或发布。候选检出前后均干净，不写真实项目。`/var/tmp/v196-r5.i7bCWF/` 保留 runner、完整 `pty.log`、退出值和 socket 路径，原终端夹具、帧与 JSON 保留。报告暂存后的 `ledger-ban.sh` 退出 0：`scope=published files=3065 hits=0 names=ok user=resolved`。
