# P245 · 路由变更清单：勾选 S1（§1–§5）与 S3（§7）两段

agent: dev   status: delivered   time: 2026-10-13T23:00Z
task: P245   phase: apply   category: infra   change: task-model-routing   deltas: -
branch: `task/P245-routing-checklist-s1s3`   PR/MR: -（local 模式：分支留本地，不推送、不合并）
受检树 tip：`a8b4ec82`（tasks.md 的勾选提交；本报告提交在其上，产品/夹具/规格零改动）

一句话：把我确实做过的 19 项（S1 的 §1–§5 + S3 的 §7）打勾并逐行补短证据指针，别人的阶段一行未动；每条指针
都指到本仓已提交的报告/复验记录/提交，或指到可重跑的命令，且其中很快的那些这次在**当前树**上重新跑过
（13 组路由产品套件 `2962/0`、config-cli `331/0`、routes `209/0`、death-cause `--pure 87/0`、openspec `16/0`）。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/task-model-routing/tasks.md` | §1–§5、§7 共 19 行由 `[ ]` 改 `[x]`，每行末尾补证据指针（报告 § / 复验记录 / 提交 sha / 测试组名 / 命令）；3.1、5.3 各带一条「实际做法」注记 |
| `docs/team/reports/P245-dev.md` | 本报告 |

只改这一个产品/账本文件加本报告：`git diff --stat a8b4ec82^..a8b4ec82` = `1 file changed, 19 insertions(+), 19 deletions(-)`
（19 行整体替换）。没有碰产品代码、夹具、规格，没有动 §6/§8 的行，也没有动 `openspec/changes/pulse-key-replies/`
或 `section-*.tsv`。

## 逐条勾选与依据

| 项 | 判定 | 证据指针（已写进清单行） |
|---|---|---|
| 1.1 | 勾 | P228-dev.md（输入 commit `da89f842`、私有基线 `task/P228-task-model-routing-core`、隔离 HOME/recording-agent 夹具）；V19.md 第六轮 `8bea13e` PASS + V19-done.md；落点 `e897a7d8` |
| 1.2 | 勾 | 本树复跑 `task-model-routing.sh --select policy,machine` 27/0；`config-cli.sh` 331/0（shape/json/groups）；P228-dev.md「实现与冻结接口」；落点 `e897a7d8` |
| 2.1 | 勾 | 本树复跑 `config-cli.sh` 331/0（writer/inject/cas/audit/models/seats）；P228-dev.md（`set-task-model` 与席位前门退休）；V19.md |
| 2.2 | 勾 | 本树复跑 `--select config,upgrade` 58/0；P228-dev.md「最终受检交接 · 017fbf9」升级矩阵（四键/退休键/畸形形态全拒后零写） |
| 2.3 | 勾 | 翻转臂 `fingerprint`、`expanding-quote`（P228-dev.md「Flip evidence」：各臂具名红后逐字节恢复）；本树复跑 `config-cli.sh` 331/0 |
| 3.1 | 勾（注） | 本树复跑 13 组批 2962/0；P228-dev.md「S1 场景 → 断言索引」；V19.md。实际做法：任务表头生成落在 S3（见下注 1） |
| 3.2 | 勾 | 翻转臂 `partial-publication`；本树复跑 13 组批（含 transaction,dispatch）；P228-dev.md（close 授权、状态种子适配） |
| 3.3 | 勾 | 本树复跑 `routes.sh` 209/0 与 13 组批（含 limits）；`config-cli.sh` models/seats（add-agent `--model` 退休） |
| 3.4 | 勾 | 本树复跑 13 组批 2962/0（含 `category-explicit-phase-independent:*`、`new-selection-custom-vocabulary*`）；V19.md；V29.md §61 同数 `pass=2962` |
| 3.5 | 勾 | 翻转臂 `recovery-drift`（改回按策略/base SID 重解析）与 `partial-publication`；P228-dev.md 20 臂 flip；V19.md 第六轮自设计边界探针 95/0 |
| 4.1 | 勾 | 本树复跑 `--select sid-readers` 251/0、`death-cause.sh --pure` 87/0；`--live`/`--flip`（7/0、4/0）见 P228-dev.md、V29.md；P240-dev.md、P241-dev.md（合并后读侧回归修复） |
| 4.2 | 勾 | 翻转臂 `latest-shell`、`latest-monitor`、`monitor-record-drift`（P228-dev.md「Flip evidence」，具名红 `reader-monitor-unavailable:nonce` 等）；V19.md 第五/六轮 |
| 5.1 | 勾 | 本树复跑 13 组批（含 pm）；P228-dev.md（PM 解析/参数/模板/元数据发布）；V29.md 全量门禁 PM/watch 段绿 |
| 5.2 | 勾 | 翻转臂 `pm-fallback`、`extra-shadow`、`template-shadow`、`template-unbound`、`template-roles`、`pm-literal-resplit`；本树复跑 13 组批（含 pm,boundary）；V19.md 六轮 FAIL→修链（F1–F6/OBS1） |
| 5.3 | 勾（注） | P228-dev.md 尾节（S1 报告、定向门禁、adapter 夹具断言保留、冻结 tip `13bbe5f`→`8bea13e`、释放清单）；V19.md 抬头 + V19-done.md；落点 `e897a7d8`。实际做法：接收判定由 PM 记录（见下注 2） |
| 7.1 | 勾 | P235-dev.md「Deliverables」（提交 `d5868f0`/`a60f91b`，输入 tip `611f72d`，释放清单含路由 init/rollout 夹具）；V23.md §D1–D3；本树复跑 `--select init` 44/0 |
| 7.2 | 勾 | P235-dev.md（退休键四命令在任何写入前全拒、`--print` 只诊断不写）；V23.md §C（复验者自建夹具证明旧配置零副作用） |
| 7.3 | 勾 | P235-dev.md「Deliverables」（`skills/teamsmith-init/SKILL.md`、`templates/*`、`references/*`、`README.md`、`9275e27`）；V23.md §D6（help/指引落地与退休键路线） |
| 7.4 | 勾 | 本树复跑 `--select init` 44/0 + `config-cli.sh` 331/0（completeness/docs/callers）+ `routes.sh` 209/0；V23.md §D4（§2/§12k 选段绿）与 §D5（三条独立变异 41/3、36/8、29/15 红侧）；翻转臂 `init-legacy-proceeds`、`template-retired-key` |

### 留空的 8 项及原因

| 项 | 归属 | 现状（不是我没做完） |
|---|---|---|
| §6.1–6.4 | S2，dev2 | 已由 P246 勾选（main `036d53ea`「tick the S2 checklist items with their evidence pointers」，每条带指针；PM 的 P246 复验记录随后并入） |
| §8.1–8.3 | PM/独立验证阶段 | 已由 PM 在 main 勾选（`4f22c1db`）；证据是 V19/V21/V23/V25/V29 这些复验记录 |
| §8.4 | 归档闸门 | 只有全部 apply 完成、独立复验 PASS 且用户确认后 PM 才跑真实 archive；按任务书留给 PM |

任务书规定「属于别的阶段/别人的项不要勾」，所以 §6 与 §8 我一行未动。

## 两条「实际做法」注记（原文写法与事实不同，已写进清单行）

1. **3.1 的表头生成在 S3，不在 S1**：这一项把「unique brief category extraction」和「task header generation support」
   写在同一行。类别提取、同任务恢复与严格 suffix-aware fresh 守卫在 S1（P228）；**任务书表头写 `category:`** 的
   那一步落在 S3（P235 的 `team task --category`，P235-dev.md「Deliverables」与 V23.md §D1）。两段都已并入 main，
   照实勾选并在行末注明。
2. **5.3 的「private received tip」不是作者自己标的**：任务书要求记私有接收 tip 与释放路径。作者侧记的是候选/
   受检 tip 与释放清单（P228-dev.md 尾节，`13bbe5f`→`8bea13e`）；**接收判定**由 PM 记在 V19.md 抬头（第六轮 PASS）
   与 `reviews/V19-done.md` 的两条 close 记录里。我没有把私有候选自行标 done/接收。

## Verification evidence (must have actually been run)

### 1. 清单计数：本分支剩 8 项（§6+§8），并到 main 后只剩 §8.4

工具默认读的是**主检出**的清单：`team_change_tasks_file` → `team_spec_dir_abs` → `$TEAM_MAIN_ROOT/openspec`
（`skills/teamsmith/scripts/lib/common.sh:5539`）。主检出当前只有 7 条勾（§6 的 4 + §8.1–8.3 的 3），所以默认那次
必然显示「20 项未勾」。把 `TEAM_SPEC_DIR` 指到本 worktree，同一条命令读出本分支的真实结果：

```
$ TEAM_SPEC_DIR="$PWD/openspec" bash skills/teamsmith/scripts/team change status task-model-routing
change task-model-routing · not ready
  …
  blockers
    P245 · apply · wip · 看板状态 wip；① 复验记录 docs/team/reviews/P245.md：不存在；② 分支是否已并入 main：
      task/P245-routing-checklist-s1s3（a8b4ec82d）的提交还不在里面（squash 合并不会让分支 tip 变成祖先）；
      ③ 阶段 apply 的交付证据：apply 与代码任务同规则（① 判定 PASS 的复验记录 / ② 已并入 main）；没有额外的阶段证据
    checklist · 8 项未勾 · tasks.md:33「6.1 Acquire only UI ownership and panel delta from S1's acce…」 ·
      tasks.md:34「6.2 Keep one CLI writer, fingerprint/dry-run/actor/receipt, …」 ·
      tasks.md:35「6.3 Adapt panel choices/p21/string/mirror fixtures for compl…」 · 另有 5 项
$ echo $?
1
```

（27 → 8：§1–§5 与 §7 的 19 项已从清单里消失；逐节数剩下的是 §6=4、§8=4。`grep -c '^- \[x\]'` = 19、
`grep -cE '^\s*[-*]\s+\[\s*\]\s*'` = 8，与这一行一致。上面那条 `P245 … 还不在里面` 是预期：squash 合并没有发生，
PM 复验后才会合。）

落点演练（scratch clone，**不动 main**）：main tip `4f22c1db` + 本分支 squash：

```
$ git clone --no-hardlinks <主检出> /tmp/p245-check && cd /tmp/p245-check
$ git fetch origin task/P245-routing-checklist-s1s3
$ git merge --squash origin/task/P245-routing-checklist-s1s3 && git commit -m "…"
Auto-merging openspec/changes/task-model-routing/tasks.md
Automatic merge went well; stopped before committing as requested
$ grep -c '^- \[x\]' openspec/changes/task-model-routing/tasks.md; grep -cE '^\s*[-*]\s+\[\s*\]\s*' openspec/changes/task-model-routing/tasks.md
26
1
$ bash skills/teamsmith/scripts/team change status task-model-routing 2>&1 | grep checklist
    checklist · 1 项未勾 · tasks.md:50「8.4 Only after all mapped apply tasks are complete, independ…」
```

合并干净（两分支改动的是不同行：我改 §1–§5/§7，main 已改 §6 与 §8.1–8.3），结果只剩 §8.4 一项留给归档。

### 2. `git diff --check && git status --short`

```
$ git diff --check && git status --short
$ echo $?
0
```

（勾选已提交为 `a8b4ec82`，工作树空。本报告落盘后再跑一次会多一行 `?? docs/team/reports/P245-dev.md`，
提交后再次为空——见文末「落盘后复核」。）

### 3. Ledger ban（固定验收行，在**本 worktree 本分支**的树上跑）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=1412 hits=0 names=ok user=resolved
$ echo $?
0
```

（这是本报告落盘前的树；报告提交后的那一次 `files` 会 +1，`hits` 仍 0——见文末。主检出扫不到本分支的新文件，
所以这条必须在本 worktree 跑。）

### 4.（补充，非任务书要求）`openspec validate --all --strict`

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
…
Totals: 16 passed, 0 failed (16 items)
$ echo $?
0
```

编辑只碰 tasks.md 的勾选，change 仍然有效。

### 5.（补充）本次在**当前树**上复跑的命令（勾选里引用的组，重新落地数字）

| 命令 | 结果 |
|---|---|
| `task-model-routing.sh --select policy,machine` | `RESULT pass=27 fail=0`，rc 0 |
| 同脚本 `--select config,upgrade` | `RESULT pass=58 fail=0`，rc 0 |
| 同脚本 `--select init` | `RESULT pass=44 fail=0`，rc 0 |
| 同脚本 `--select sid-readers` | `RESULT pass=251 fail=0`，rc 0 |
| 同脚本 13 组批（policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary,init） | `RESULT pass=2962 fail=0`，rc 0，454.4s（后台作业 `P245-routing-recheck`，已按工具收割；与 V29.md §61 的 `pass=2962` 同数） |
| `bash skills/teamsmith/tests/config-cli.sh`（默认全部段） | `✓ 331 ✗ 0 SKIP 0`，rc 0，1m18s |
| `bash skills/teamsmith/tests/routes.sh` | `✓ 209 ✗ 0 SKIP 0`，rc 0，4m49s |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | `✓ 87 ✗ 0 SKIP 0`，rc 0 |

没有在这里重跑 `death-cause.sh --live/--flip`（7/0、4/0）与 §61b 的 22 条变异臂：它们是 V29 全量门禁的证据
（`✓4727 ✗0 SKIP19`，§61 489s / §61b 4869s）。本任务只改清单文本，重跑它们不会有新信息；清单行里对这两处的
引用已写明来源是 P228-dev.md / V29.md，不是我这次跑的。

## Decisions and deviations

- **只勾我确实做过的 19 项**（§1–§5、§7）；§6 与 §8 一行未动（任务书的硬规则）。§8.1–8.3 在 main 上已由 PM 勾选，
  我的分支从 `1a9b3f76` 出发，那里它们仍是空的——属分支基线差异，合并时两处不冲突（演练里 `Automatic merge went well`）。
- **没有发现「清单要求了但其实没做/不完整」的项**：19 项逐条对照本仓证据与本次复跑。两处「写法与事实不同」
  已按任务书规则勾上并注明（3.1、5.3）。
- **7.1 的输入 tip 与 7.4 的落点核对过**：P235 分支输入是已接受的 S2 tip `611f72d`，释放清单（含
  `tests/lib/model-policy.sh` 那条路由 init/rollout 夹具、`tests/{task-model-routing,config-cli,install-shape}.sh`、
  `tests/smoke.sh`）在报告里逐文件列出；路由 `--select init` 现在 44/0。
- 未 push、未合并、未跑全量门禁、未改实际配置/共享源、未重启任何席位（local 模式 + 任务书边界）。

## Suggested next steps

- 归档还差的前置里有两条**不在本次勾选范围**（都不是我这 19 项的要件，提请 PM 注意）：`P243`（改产品路由逻辑时
  选段应选中 §61/§61b，看板 `todo`）与 `P244`（`change status` 认 squash 合并，看板 `wip`），都由 dev3 领。
- V29 记了两处「不是严格更强」的替换（OBS-2：§54 的 `kill-window == 2` → `≥ 2`、sid 计数 → 形状匹配），判定
  可接受但留档（V29.md §8）。归档前是否收紧，由 PM 决定；我没有在本次单元格里改夹具。
- 合并本分支后，主检出 `team change status task-model-routing` 的 checklist 行应为「1 项未勾 · 8.4」；在此之前
  它读到的是主检出的旧清单（工具按 `TEAM_MAIN_ROOT` 取文件），用 `TEAM_SPEC_DIR` 可指到分支上核对。
- 本任务无 `BLOCKED:` 项。

## 收尾复核（报告落盘前与提交后各一次）

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=1413 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
?? docs/team/reports/P245-dev.md
rc=0
```

交付收尾复核（报告已落盘、工作树干净时重跑；本段补写会再提交一次，不改变上面任何结论或数字）：

```text
$ git diff --check && git status --short
rc=0                      # 无输出：工作树干净

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=1413 hits=0 names=ok user=resolved
rc=0

$ TEAM_SPEC_DIR="$PWD/openspec" bash skills/teamsmith/scripts/team change status task-model-routing
    checklist · 8 项未勾 · tasks.md:33「6.1 Acquire only UI ownership and panel delta from S1's acce…」 ·
      tasks.md:34「6.2 Keep one CLI writer, fingerprint/dry-run/actor/receipt, …」 ·
      tasks.md:35「6.3 Adapt panel choices/p21/string/mirror fixtures for compl…」 · 另有 5 项
rc=1                      # 预期：P245 还没有复验记录、分支还没并入 main；清单本身已从 27 降到 8
```
