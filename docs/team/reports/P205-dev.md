# P205 · `sender-identity-refusal` apply：把提案新写的七条边界变成红侧

agent: dev   status: DELIVERED（local 模式：分支留本地、不 push；PM 复验后本地合并）   time: 2026-10-03T10:05Z
branch: `task/P205-apply`（分叉点 `2a4a70c8`；代码/夹具 tip `17a340f2`，报告/证据 tip `3d40c575`，本行所属的
提交再追加一条交付 tip 门禁日志；main 在其后只多了一条只动 `docs/team/RELEASE-PUBLIC.md` 的提交
`7259bb98`，本次没有并入 —— 见 §7 与 §10）
任务书：`docs/team/tasks/P205-sender-identity-apply.md`
change: `sender-identity-refusal`   phase: `apply`（`deltas: notify-and-inbox`）
授权路径：`skills/teamsmith/tests/**` · `docs/team/reports/P205-dev.md` · `docs/team/reports/P205-dev/**`
红线内：**零脚本层改动**（`skills/teamsmith/scripts/**` 未动；delta 与实现无矛盾，不需要 `BLOCKED:`）

## 结论

| brief 项 | 状态 | 证据 |
|---|---|---|
| 1.1 重定基线：delta 与将被替换的那条 requirement 对齐，hunk 只该是意图内的改写 + 追加 scenario | ✓（三个 hunk，逐条对上） | `P205-dev/11-rebaseline-diff.txt` |
| 1.2 场景清单两向：无丢失、十一条基线标题在、恰好七条新增 | ✓ 11 → 18，`>` 七条，无 `<` 行 | `P205-dev/12-scenario-inventory.txt`；逐字节：`12b-baseline-verbatim.txt`（11/11 原样，改写 0） |
| 1.3 `validate --all --strict` + `spec-refs.sh --check` | ✓ | `P205-dev/41-42-validate-spec-refs.log` |
| 2.1 §47 补四条运行（名册外窗口 / 名册外 `TEAM_AGENT` / 席位工作树 + 名册线索 / `--from` 带线索） | ✓ 81 ✓ 0 ✗ | `P205-dev/21-select47-green.log` |
| 2.2–2.4 三个新影子（B 名册过滤 / C 声明优先级 / D 目录前提），各要对应断言变红 | ✓ 四个影子（含 A 对照）全对 | `P205-dev/25-flip-p201.log`；逐影子的红行见 §5（`flip-logs/red-*.log`） |
| 2.5 flip 两侧 + 三个自检（budget / loop / select） | ✓ flip 21 ✓ 0 ✗；三自检全过 | `P205-dev/25-flip-p201.log`；§6 |
| 3.1 三条试跑（绿 / 丢 scenario 红 / scratch 归档） | ✓ 三条全过 | `P205-dev/31-trial-run.log`；`trial-logs/*` |
| 3.2 真树 `openspec/specs/**` 未被试写 | ✓ `git status -- openspec/specs/` 空 | §4 |
| 4.1–4.4 门禁 | 4.1/4.2 ✓（交付 tip 复跑）；4.3 宿主 = 3831 ✓/1 ✗（唯一红是环境假红，已定性）；4.3 容器（干净 clone）= **3831 ✓/0 ✗**；4.4 容器全量（干净 clone）= **4566 ✓/0 ✗**（代码/夹具 tip `17a340f2`）与 **delivered tip `3d40c575` 复跑 4566 ✓/0 ✗** | §7 |
| 5.1/5.2 报告（含逐影子红侧粘贴、四条门禁尾巴、delta→scenario 映射、改动路径、未测项的声明） | ✓ | 本文件 |

## 1 · 重定基线（1.1–1.3）

### 1.1 两个 hunk + 追加的 scenario（原始 diff 在 `P205-dev/11-rebaseline-diff.txt`）

正文只有两处改写，与 `design.md` §6 的「2 句改写 + 3 段新增」完全一致：

```diff
-- the runtime directory (`team`'s M40 identity): the project's main worktree resolves to `pm`, and a worktree
-  under the main worktree's worktrees directory resolves to that worktree's own directory name, also when the
-  process runs in one of its subdirectories;
+- the runtime directory (`team`'s M40 identity): a worktree under the main worktree's worktrees directory
+  resolves to that worktree's own directory name, also when the process runs in one of its subdirectories; the
+  project's main worktree resolves to `pm` only while no **seat clue** is present — with a seat clue the call is
+  refused instead of resolved (below);
...
-An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory
-wins and the ignored value MUST be named on stderr. An unresolved call MUST exit non-zero, ...
+A **seat clue** is a name of this project's roster (`TEAM_AGENTS`): ... (新增 3 段：线索清单 / 拒绝行为 / 例外)
+An inherited `TEAM_AGENT` MUST NOT override the runtime directory: ... — except that a roster name in
+`TEAM_AGENT` makes the main worktree's call the seat-clue refusal above ... An unresolved call MUST exit non-zero, ...
```

第三个 hunk 是**追加**的七条 scenario（diff 里全是 `+` 行，见 1.2 的清单）。
**没有意外的 hunk**：`openspec/changes/` 下除本 change 外没有任何**未归档**目录，全仓唯一一份未归档
`specs/notify-and-inbox/spec.md` 就是本 change 的 delta（`find` 清单见提交说明），期间也没有别的 change
归档过这条 requirement 的修改，所以不需要折叠别人的句子。

### 1.2 场景清单两向 + 基线逐字节

`12-scenario-inventory.txt`：`diff` 无 `<` 行（零丢失）、恰七条 `>` 行、两边各 11 条标题。

七条新增（就是 `design.md` §5 里那七行）：

1. `A seat clue in the main worktree refuses instead of claiming pm`
2. `The window clue is the caller's own pane, not the client's current window`
3. `An inherited roster name refuses the main worktree's call`
4. `A name outside the roster is not a clue`
5. `Another session's window of the same name is not a clue`
6. `An explicit --from is still honoured with a seat clue present`
7. `A seat worktree is not refused by a roster clue`

`12b-baseline-verbatim.txt`（python 逐条比对，比标题集合更强）：**11 条基线 scenario 在 delta 里逐字节保留
（改写 0、缺失 0）**。红侧（丢一条基线 scenario → validate 点名）由 3.1 的 trial 2 覆盖，不在真树上做。

### 1.3 门禁

`41-42-validate-spec-refs.log`：`Totals: 14 passed, 0 failed (14 items)`；`spec-refs: judged 104
reference(s) (49 distinct) ... retired 0; undeclared 0`。

## 2 · 夹具（2.1）：§47 case ③ 补四条运行

只动 `skills/teamsmith/tests/smoke.sh`（35 行插入；hunk 位置全在 17108–17442 的 §47 内）：

- `--agents "dev dev2"` → `--agents "dev dev2 dev3"`：让 `TEAM_AGENT=dev3` 在夹具里真的是**名册席位**
  （delta 的 GIVEN 说 "a roster seat"；原来夹具名册只有 dev/dev2，dev3 就只是「名册外名字」，影子 D 的
  「席位工作树不被拒」会失去牙齿）。§47 其余断言不受影响（81 ✓ 0 ✗ 全绿）。
- ③d 名册外的**窗口名**（`nosuch`）+ 主检出 → 退出 0、`agent:pm`、不出现 `agent:nosuch`；
- ③e 名册外的 **`TEAM_AGENT`**（`nosuch`）+ 主检出 → 退出 0、`agent:pm`；
- ③f **席位工作树 + 名册线索**：`dev2` 工作树 + `TEAM_AGENT=dev3` → 退出 0、记 `agent:dev2`、
  stderr 点名被忽略的 `TEAM_AGENT=dev3`；
- ③g **`--from` 仍胜**：主检出 + 窗口 `dev` + `--from dev3` → 退出 0、记 `agent:dev3`、
  stderr 点名与目录 `pm` 的分歧（`座位 'pm'`）。

`21-select47-green.log`（交付 tip 复跑）：`#5 47 · ... · 用时 2s · ✓81 ✗0 SKIP0 · ticks 81`，墙钟 5.7s
（改前 70 条 / 2s；全量模式里的同段见 §7：3s / 81 条）。

## 3 · 影子（2.2–2.4）：`flip-p201.sh` 四影子

`flip-p201.sh` 现在有四个影子：**A**（原装：冲突分支永不成立）是 P201 交付时就有的对照；B/C/D 是本次新增的
「新断言的红侧」。每个影子的流程：在 `/tmp` 的技能树副本里做**一处**变异（python 断言锚点恰好命中一次）→
`bash -n` 证明是行为变异不是语法错 → 跑聚焦探针（smoke 前导 + §47 + 结果行，`SKILL_DIR` 指向副本）→
逐条点红 / 点绿 → **还原** → 再跑一遍必须全绿。判据不走管道（红行先落盘再 grep：pipefail 下早退的 `grep -q`
会把生产者 SIGPIPE 掉，把「匹配到」读成「没匹配到」）。

`25-flip-p201.log`（首次，tip `2a0abdf7`）与 `25-flip-p201-final.log`（交付 tip 复跑，墙钟 33.3s）都是：
`== 结果 == ✓ 21 ✗ 0`；`flip-p201 翻转成立（四个影子 + 还原）`。下面 §5 引用的红行来自首次运行
（`flip-logs/red-*.log`）；交付 tip 的复跑逐条影子结果一致（临时目录名不同，红行措辞相同）。

## 4 · 试跑与真树保护（3.1–3.2）

`31-trial-run.log`：`== trial result: OK ==`；三条试跑的输出在 `trial-logs/`：

1. `validate --all --strict` = `14 passed, 0 failed`；
2. 删掉一条基线 scenario（`The same pointer survives a queued PM knock`）→ `13 passed, 1 failed`，
   `✗ [ERROR] ... omits scenario(s) the current spec still has: "The same pointer survives a queued PM knock"`；
3. scratch `openspec archive -y sender-identity-refusal` → `~ 1 modified` → validate 全绿；归档后 base 里
   `scenarios = 18`、退役句 `the project's main worktree resolves to \`pm\`, and a worktree` = 0 处、
   拒绝段 = 1 处、`openspec/changes/archive/2026-10-03-sender-identity-refusal` 在、未归档 change 目录 = 0。

试跑脚本（P204 的）把日志写回 `docs/team/reports/P204-dev2/`；我在复制出证据后 `git checkout --` 还原了
dev2 的目录（他们的证据文件现在与 main 逐字节一致）。真树未被试写：`git status -- openspec/specs/` 空。
`openspec/changes/sender-identity-refusal/` 里的 delta 也一字未改（本轮没有任何文件需要改它）。

## 5 · Flip evidence（红前 → 绿后；逐影子粘贴，不是摘要）

四条影子跑在 `2a0abdf7` 上；`flip-logs/baseline.log` 是变异前的基线（47 段全绿）。下面是每个影子的
**全部**红行（`✗`），随后是该影子还原后的绿跑。

### 影子 A（对照，P201 原有）：冲突分支永不成立

```
✗ P201 ① 主检出 + 窗口 dev 应当拒绝（当前退出码 0）
✗ P201 ① 拒绝时零写入：收件箱逐字节不变（期望 [4294967295:0]，实际 [2823121617:57]）
✗ P201 ① 拒绝输出点名目录说的名字（pm）（/tmp/teamsmith-smoke.0Ntc9x/p201-1.log 中找不到 [目录说 'pm']）
✗ P201 ① 拒绝输出点名线索说的名字（dev）（/tmp/teamsmith-smoke.0Ntc9x/p201-1.log 中找不到 [窗口名 'dev']）
✗ P201 ① 拒绝输出给出出路：--from（/tmp/teamsmith-smoke.0Ntc9x/p201-1.log 中找不到 [--from]）
✗ P201 ① 拒绝输出给出出路：从自己的 worktree 调用（/tmp/teamsmith-smoke.0Ntc9x/p201-1.log 中找不到 [worktree]）
✗ P201 ① 窗口名问的是调用者自己那块 pane（-t $TMUX_PANE，不是回声）（/tmp/teamsmith-smoke.0Ntc9x/p201-tmux.log 中找不到 [-t %4242]）
✗ P201 ② 主检出 + TEAM_AGENT=dev 应当拒绝（当前退出码 0）
✗ P201 ② 拒绝时零写入：收件箱逐字节不变（期望 [4294967295:0]，实际 [1565813092:57]）
✗ P201 ② 拒绝输出点名目录说的名字（pm）（/tmp/teamsmith-smoke.0Ntc9x/p201-2.log 中找不到 [目录说 'pm']）
✗ P201 ② 拒绝输出点名线索说的名字（TEAM_AGENT dev）（/tmp/teamsmith-smoke.0Ntc9x/p201-2.log 中找不到 [TEAM_AGENT 'dev']）
== 结果 ==  ✓ 70  ✗ 11
```

影子 A 判据：这 7 条预期断言在红行里、**③ 一行不红**（对照：红的必须是冲突判定，不是 ③ 的照旧路径）。
还原后 `green-A.log`：`== 结果 == ✓ 81 ✗ 0`。

### 影子 B（2.2）：`team_sender_seat_clues` 去掉名册过滤

```
✗ P201 ③ 名册外的窗口名被当成了线索（误拒）
✗ P201 ③ 名册外的窗口名 → 照旧记 pm（期望 [agent:pm · P201-SUMMARY]，实际 []）
✗ P201 ③ 名册外的 TEAM_AGENT 被当成了线索（误拒）
✗ P201 ③ 名册外的 TEAM_AGENT → 照旧记 pm（期望 [agent:pm · P201-SUMMARY]，实际 []）
== 结果 ==  ✓ 77  ✗ 4
```

判据：恰是 2.1 的两条新非名册断言（各 2 行）红；**①② 不红**（拒绝机制本身没坏，红的是名册过滤）。
还原后 `green-B.log`：`== 结果 == ✓ 81 ✗ 0`。

### 影子 C（2.3）：把冲突拒绝挪到显式 `--from` 之前

```
✗ P201 ③ 带线索的显式 --from 被拒（声明不再优先）
✗ P201 ③ 显式 --from 原样记录（线索不采纳）（期望 [agent:dev3 · P201-SUMMARY]，实际 []）
✗ P201 ③ stderr 点名与目录 pm 的分歧（/tmp/teamsmith-smoke.mJepjA/p201-3g.log 中找不到 [座位 'pm']）
== 结果 ==  ✓ 78  ✗ 3
```

判据：③g 红；**无线索 / 名册外 / 席位工作树 / 窗口 pm / 别的会话一行都不红**（拒绝跑到声明前面只伤声明路径）。
还原后 `green-C.log`：`== 结果 == ✓ 81 ✗ 0`。

### 影子 D（2.4）：去掉拒绝的目录前提 `[ "$dir" = "pm" ]`

```
✗ P201 ③ 席位工作树被名册线索误拒（线索只否决主检出的 pm）
✗ P201 ③ 席位工作树的目录赢（dev2，不是线索 dev3）（期望 [agent:dev2 · P201-SUMMARY]，实际 []）
✗ P201 ③ stderr 点名被忽略的 TEAM_AGENT=dev3（/tmp/teamsmith-smoke.L3my6N/p201-3f.log 中找不到 [TEAM_AGENT=dev3]）
== 结果 ==  ✓ 78  ✗ 3
```

判据：新工作树断言在其中；**①② 仍拒绝、③g 声明仍胜**（变异只放宽目录前提）。
还原后 `green-D.log`：`== 结果 == ✓ 81 ✗ 0`。

> 变异是刻意从宽的（D 会让任何目录的线索都拒），但实际红的是**恰好**那三条 —— ③d/③e/③f/③g 里只有 ③f
> 带「非 pm 目录 + 名册线索」这个组合。

## 6 · 三个自检（2.5）

```
$ bash skills/teamsmith/tests/section-guard.sh --budget-check
ok: 表头记录了 factor=4
ok: 表头记录了 floor=60
ok: 预算表覆盖 123/123 个 section 且每行都满足 max(ceil(band×4), 60)
section-guard --budget-check: 全过

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 72 行清单 / 72 个 while+sleep 循环，配平 72 个
section-guard --loop-check: 全过

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（123 行）
ok: 段 ↔ 行一一对应（源码 123 段 / 表 123 行）
ok: needs 声明全部存在且指向更早的段（103 条）
ok: 字面模式全部存在于工作树（524 条）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（481 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 7  bad 0  SKIP 0
```

§47 的实测带：宿主 FAST **3s**（改前 2s）、容器 FAST **3s**、容器全量 **3s** —— 所以
`section-budgets.tsv` 的 47 行按派单要求重测并已提交：band 2.00 → **3.00**（host 3.00 / container 3.00），
budget 60 不变，`--budget-check` 复跑全过（commit `17a340f2`）。

## 7 · 门禁（4.1–4.4）

### 4.1 / 4.2（宿主，逐字命令；交付 tip 复跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)
$ PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 104 reference(s) (49 distinct) in 10040 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
```

（完整输出：`P205-dev/41-42-validate-spec-refs.log`。）

### 4.3 宿主 `TEAM_SMOKE_FAST=1`（任务书逐字命令）

`P205-dev/43-fast.log`：`== 结果 == ✓ 3831 ✗ 1`。

唯一一条 ✗ **不是本 change 造成**，是真实账本污染了夹具的痕迹扫描（环境假红）：

```
✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（期望 [none]，实际 [/home/.../pm-skills/docs/team/inbox/verify.md]）
```

- 12b-j 的判据（`ob_leak_scan`）拿 `$SESSION|半句草稿 half a sentence|never lands|held body|...` 去扫
  **调用方项目**的 `docs/team/inbox` 与 `.pi/team/state`（本轮就是真项目 —— worktree 的
  `git rev-parse --git-common-dir` 指向真主检出）。
- 命中的是 `verify.md` 第 139 行（**2026-10-03T01:07:55Z**，远早于本轮）里 verify 自己的消息文本
  「…delivery-truth 漏掉 A meeting knock **never lands** on a draft…」—— 夹具模式里的 `never lands` 与这句
  合法消息撞词。
- 该文件是**未跟踪的运行时状态**（`.gitignore:4 docs/team/inbox/`），不在我的分支里；`ob_leak_scan` 与
  main 逐字节相同；我的 diff 只在 §47（17108–17442 行），离它（6920 行）很远。
- 完整定性证据：`P205-dev/43-host-fast-red.txt`。

**结论**：任何人在这个 checkout 的宿主上跑 FAST 都会吃到这条（与本次改动无关）；参考环境的 4.3 见下。

### 4.3 参考环境（钉死容器，干净 clone）

任务书的 `-v "$PWD":/work` 形态把 **worktree** 挂进容器：worktree 的 `.git` 是**文件**、gitdir 指向挂载外，
容器里 `git -C /work/skills/teamsmith rev-parse` 失败 → §0d 冲突标记守卫报
`找不到受检的 git 工作树（/work/skills/teamsmith 不在仓库里？）` → 连带把 §36 的 9 条嵌套选段断言打红
（`P205-dev/43b-container-fast-mount-shape.txt`，10 条红全指向同一个根因，没有一条在 §47）。
这是**挂载形状**的已知差异，不是改动；仓库自己的里程碑门禁跑法就是先 `git clone` 到 /tmp 再挂
（`docs/team/RELEASE-PUBLIC.md` §十六：`rm -rf /tmp/mile && git clone -q . /tmp/mile`），所以我按同一形状跑：

```
$ rm -rf /tmp/p205-mile && git clone -q --branch task/P205-apply <worktree> /tmp/p205-mile   # HEAD == 2a0abdf7，status 干净
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v /tmp/p205-mile:/work -w /work localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory "*"; TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'
```

→ `P205-dev/43c-container-fast-clone.log`（`rc=0`）：

```
#109 47 · P82 notify 发送者 = 运行时目录（notify-sender-identity） · 用时 3s · ✓81 ✗0 SKIP0 · ticks 81
账本自查： 123 段收口 · 增量 ✓3831 ✗0 SKIP36 ｜ 结果行 ✓3831 ✗0 —— 一致
== 结果 ==  ✓ 3831  ✗ 0
smoke 全绿
```

### 4.4 容器内全量（参考环境，干净 clone）

```
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v /tmp/p205-mile:/work -w /work localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory "*"; openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'
```

→ `P205-dev/44-container-full.log`（代码/夹具 tip `2a0abdf7`，`rc=0`，2216 秒）：

```
Totals: 14 passed, 0 failed (14 items)          # openspec validate --all --strict（容器内）
#108 47 · P82 notify 发送者 = 运行时目录（notify-sender-identity） · 用时 3s · ✓81 ✗0 SKIP0 · ticks 81
  ✓ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹
  ✓ 12b-j 隔离：调用方项目 inbox/state 的指纹也没变（整段夹具期间真团队没有活动）
账本自查： 122 段收口 · 增量 ✓4566 ✗0 SKIP3 ｜ 结果行 ✓4566 ✗0 —— 一致
== 结果 ==  ✓ 4566  ✗ 0
smoke 全绿
```

**交付 tip 复跑**（`3d40c575` = 代码/夹具 + 预算表 + 本报告与全部证据都在树里，干净 clone，`-v /tmp/p205-mile3:/work`）：
`P205-dev/45-container-full-delivered-tip.log`（`rc=0`，2200 秒）——同样 `Totals: 14 passed, 0 failed`、
`#108 47 · ... 用时 3s · ✓81 ✗0`、`12b-j` 两条 ✓、`账本自查 … 一致`、**`== 结果 == ✓ 4566 ✗ 0`**、
`smoke 全绿`（最慢段 `#97 36·` 的耗时未打印到尾部摘要，但全段无超时/超带记录）。
这一步专门抵消「门禁与交付 tip 差一个提交」的疑虑：报告与证据文件（`docs/team/reports/**`）都在树里，
门禁照样全绿（14b 的扫描面本来就不含 `docs/**`）。

对照说明：同一条 `12b-j` 断言在容器里两次都是绿的 —— 因为它扫的「调用方项目」是**干净 clone**（无真实账本），
恰好反证了 §4.3 宿主那条红是账本状态而不是夹具或改动。两次跑的耗时段分布一致：最慢 `#97 36 ·` 581–582s
（预算 1248s），其余段 ≤ 288s；全程无超时段、无 47 段超带记录（band 已改 3.00）。

## 8 · delta→scenario 映射（`design.md` §5 的刷新版）

| 新 scenario | 钉的条款 | 现在由谁跑 | 红侧 |
|---|---|---|---|
| A seat clue in the main worktree refuses instead of claiming `pm` | 拒绝：非 0、零写入、两个名字、两条出路 | §47 ①②（原装） | 影子 A |
| The window clue is the caller's own pane, not the client's current window | pane 目标规则（回声不算证据） | §47 ① 的 `-t $TMUX_PANE` 断言（原装） | 影子 A；无目标读会让夹具 shim 不回答 |
| An inherited roster name refuses the main worktree's call | `TEAM_AGENT` 是线索 | §47 ②（原装） | 影子 A |
| A name outside the roster is not a clue | 名册过滤（不许误伤） | **本轮新增**：§47 ③d（窗口 `nosuch`）+ ③e（`TEAM_AGENT=nosuch`） | 影子 B（去掉名册过滤 → 两组断言各 2 行红） |
| Another session's window of the same name is not a clue | 会话范围 | §47 ③c（原装） | 影子 A 下保持绿（对照）；改会话检查会打红它 |
| An explicit `--from` is still honoured with a seat clue present | 声明优先 + 分歧点名 | **本轮新增**：§47 ③g | 影子 C（拒绝挪到声明之前 → 3 行红） |
| A seat worktree is not refused by a roster clue | 线索只否决主检出的 `pm` | **本轮新增**：§47 ③f | 影子 D（去掉 `[ "$dir" = "pm" ]` 前提 → 3 行红） |

## 9 · 改动路径与未测项

改动路径（`git diff --stat main..HEAD`）：

| Path | Δ | 说明 |
|---|---|---|
| `skills/teamsmith/tests/smoke.sh` | +35 | 夹具名册 +`dev3`；§47 ③d–③g |
| `skills/teamsmith/tests/flip-p201.sh` | +187/−56 | 四影子框架（A 原样保留，B/C/D 新增）；红行落盘（pipefail 教训） |
| `skills/teamsmith/tests/section-budgets.tsv` | 1 行 | 47 行 band 2.00 → 3.00（实测重测） |
| `docs/team/reports/P205-dev.md` + `docs/team/reports/P205-dev/**` | 新增 | 本报告与证据 |

未测项（明确声明，不含混）：

- **没有真 tmux**：§47 的 `tmux` 是 shim（只回答 `-t $TMUX_PANE` 的查询）。P205 改的全是夹具与影子，
  真 tmux 的行为由 P201 的容器门禁覆盖；本轮的容器全量（4.4）里 FA**S**T 段跳过 36 个真进程段，
  但**全量**模式会跑它们。
- **没有模型调用**：这条 requirement 的任何 scenario 都不需要。
- 影子只变异 `skills/teamsmith/scripts/lib/common.sh` 的三处锚点；`scripts/**` 本体一字未改。

## 10 · 交接与复验建议

- local 模式：分支 `task/P205-apply` 留在本地 worktree，未 push（代码/夹具 tip `17a340f2`；`3d40c575` 是报告与
  证据；其后的提交只追加交付 tip 的门禁日志 `45-container-full-delivered-tip.log`）。PM 复验后可 squash 合并。
- 复验时请直接跑 §5–§7 的命令（`flip-p201.sh` 33 秒；§47 选段 6 秒；容器全量约 37 分钟）。宿主 FAST 的
  12b-j 假红若仍在，属环境账本状态，不是回归（判据见 §7 与 `43-host-fast-red.txt`）。
- main 的 `7259bb98`（只动 `docs/team/RELEASE-PUBLIC.md`，+6 行发布记录）没有并入本分支：合并时是 squash、
  与该文件无重叠，不会冲突；若 PM 要求交付分支包含它，直接 `git merge main` 即可（docs-only，无需重跑门禁）。
- `docs/team/reports/P204-dev2/` 我没有留下任何改动（试跑日志复制后已还原）。
