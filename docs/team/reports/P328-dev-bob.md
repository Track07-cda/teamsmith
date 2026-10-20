# P328 · 守卫清点（只读）

agent: dev-bob   status: delivered   time: 2026-10-20T06:05Z
branch: `task/P328-guard-inventory`   PR/MR: -（local 模式，不推）

## 答案先写

- **分类**：本会话归档 **19** 条（10-14 至 10-18；任务书写 20，10-13 起没有更早的归档提交，按实际 19）：
  **11 product / 8 governance**。门禁自己被吃掉的面更大：smoke.sh 共 **22 594 行 / 134 段**，其中 **5 003 行（22%）
  在守仓库自己的流程**——0c–0i 864、31/31c 909、34–34d **1 279**、35–36 668、40 429、14b/14d 201、58 122、45/48/50 531。
- **守卫套守卫**：PM 给的 4 个候选里 **2 个是真配对**（两处 panel readonly 都不跑；§58 的三条内联翻转是 lint 夹具表
  的子集），**1 个配对已经不存在**（预算表 P316 已删，只剩 cap 算式残留），**1 个是分层不是重复**（§34/34b 与
  34c/34d）。另有一个没被点名的真重复：**"席位 = 运行时目录"有两份实现**。
- **可退役**：52 个门禁与 CI 从不调用的夹具、**11 284 行**，删掉不动规格；另有 2 个（1 746 行）被 verification 的
  两条 scenario 点名，删它们要一条 spec delta。

## 一 · 分类（判据：product = 用户能多做/少做一件事；governance = 只动门禁、夹具、提示词、协议、账本）

| 变更 | 标签 | 判据一句话 |
|---|---|---|
| 10-14 pulse-key-replies | product | 新命令 `team reply` + 面板第 5 页，用户多一个可读的答复面 |
| 10-14 task-model-routing | product | 派单可选项（category→model）与配置写入路径变了 |
| 10-14 long-job-suspend | governance | 只改工人/PM 提示词、工具 description 与 bg 账本行 |
| 10-15 gate-lock-hygiene | governance | 落在 `scripts/lib/**`，但守的是门禁锁自身（用户只感知等待文案与时长） |
| 10-15 help-robustness | product | `team help` 的排版/清单/占位符判红就是用户读到的输出 |
| 10-15 orphan-visibility | product | 新增 `team reap`，`ps`/`status` 读出孤儿进程 |
| 10-15 cli-help | product | 同为 help 输出（分级菜单、语言开关） |
| 10-15 panel-preview-and-compose | product | 面板详情预览与草稿生命周期 |
| 10-15 pm-reply-discipline | governance | 只把规则写进 SKILL/协议/提示词与门禁断言 |
| 10-15 turn-notice-merge | governance | 收件箱行的合并与 knock——我们之间那条通道 |
| 10-15 panel-plain-language | product | 面板文案去黑话、删审计块：用户看到的字变了 |
| 10-15 startup-self-heal | product | 升级后 `team up` 自己完成迁移（新旗标与决策） |
| 10-16 writing-discipline | governance | 只有 protocol/workflows/模板与断言 |
| 10-16 seat-interrupt-entry | product | 新命令 `team interrupt` |
| 10-16 slash-team | product | 用户多了 `/team` 前门 |
| 10-16 replies-for-the-user-are-published | governance | 提案自述"无运行时行为变化；唯一产品代码改动是面板多画一行" |
| 10-16 gate-lock-external-deletion | governance | 同 gate-lock-hygiene：锁的归属与身份 |
| 10-17 tmux-identity-scope | product | 不再把身份写进共享 server；doctor 报历史残留 |
| 10-18 tmp-root-on-disk | governance | 落点是 `scripts/**`，改的是我们夹具的临时根放哪（用户感知=磁盘不再被塞满） |

## 二 · 守卫套守卫（逐条自己验过：段键 + 文件:行 + 断言名）

| 配对 | 证据 | 判定 |
|---|---|---|
| panel-p21 readonly × panel-b2 readonly | `tests/panel-p21.sh:1646 scn_readonly`（"契约没被控制台碰过"/"审计没长"/"wrapper 里没有 config set"）× `tests/panel-b2.sh:1120 scenario_readonly`（"3.2 只读扫描：只变了面板自己的文件"）。两条都不跑：smoke.sh 只调 panel-p21 的 `choices`（`smoke.sh:18469`）与 `groups settings wheel`（`:18606`）；panel-b2.sh 在 smoke.sh **零调用点**，只被也没人调的 `flip-p20.sh:244–250` 调 | **真配对，两条都是死守卫** |
| signal lint：夹具表 × 门禁内联翻转 | `smoke.sh:22158` 跑 `signal-lint.pl --selftest`（29 例，`tests/fixtures/signal-lint-cases.txt` 的 `pkill_f` red / `kill_term_pid` clean / `self_clean`），`smoke.sh:22163–22177` 又用三个内联文件重测同三种形状 | **真重复，弱的那份在门禁里**（3 ⊂ 29） |
| 门禁段预算 × 超时上限 | `tests/section-budgets.tsv` 已由 P316 删除（`d92f0a17`），段看门狗改成每段平 1800s（`smoke.sh:871`）；残留是 `gate_lock_expected(suite,/dev/null)`（`smoke.sh:559`/`:637` → expected=0、bound=121 500）与 `gate_lock_cap`（`scripts/lib/gate-lock.sh:466`）：实测 `gate_lock_cap(lock,1800)` → **1800**，恒等于 W；§34⑦（`smoke.sh:16461–16491`）与 §34b⑨（`:16688–16708`）仍用自造 expected=400/300 断言这条算式 | **配对已不存在，剩下"守一个没有生产者的数"** |
| §34/34b（P281）× §34c/34d（P287） | 真重复只有两处："记录住在伴生锁边上"（`smoke.sh:16556` 34b② × `:17386` 34d④）、"互斥完好"（§34①②③ × §34d③④）；其余是 P287 刻意新开段避让 P281 的写集 | **分层，不是重复删除的对象** |
| （未点名）席位 = 运行时目录 ×2 | `scripts/lib/common.sh:797 team_sender_from_dir` × `scripts/lib/gate-lock.sh:489 gate_lock_seat_of_dir`，两处注释都自称"team notify 同一条规则"；门禁各一套：§47（`smoke.sh:20165/20169/20172/20182`）× §34b⑨（`:16715/16717/16719/16720`）× §32 身份闸门 | **真重复（实现级）** |

## 三 · 可退役的最小清单（按"删掉会失去什么"从小到大；五条，全是删除或合并）

**1. 把 §58 的三条内联翻转并进 lint 夹具表** —— `smoke.sh:22163–22177`（15 行 + 3 条断言），表里已有
`pkill_f`/`kill_term_pid`/`self_clean`。它现在守什么：lint 对 `pkill -f`、`kill "$pid"`、干净文件的双向判定。
谁已守住：`--selftest`（29 例，§58 每轮都跑，`smoke.sh:22158`）。删了失去什么：**什么都失去不了**——内联三例是
表里的子集，表还多 26 例。

**2. 删掉 expected→cap 的算式残留** —— `gate-lock.sh:463–476`（cap）+ `:515–545`（expected 的预算分支）、
`smoke.sh:559`/`:637` 的 `/dev/null` 调用、§34⑦ 的 cap 断言（`:16486–16491`）、§34b⑨ 的 cap/remaining 四条
（`:16688–16708`）。它现在守什么：等待上限按持有者公布的剩余时间自适应。谁已守住：**没有人守"自适应"——它今天
不生效**（expected 恒为 0，cap 恒等于 W）；"排队超限大声失败"由 §34b①/⑦ 守，与算式无关。删了失去什么：注释里
那句假话（"expected/bound 为 0/0"，实测 bound=121 500）和"以后把预算表接回来就自动生效"的可能性。**诚实边界**：
真正要修的"80 分钟合法运行在 30 分钟排队上限处 FAIL"今天就在发生；删算式不会修它，只会让它从"残留承诺"变成
"写明的行为"。修它要改 verification 的一条 requirement → 属 change，不在本任务。

**3. 删 52 个门禁与 CI 从不调用的夹具（11 284 行）+ `loop-inventory.tsv` 里属于它们的 11 行**（不删那 11 行，
§0e 的 `--loop-check` 会红）。最大八块：`panel-b2.sh` 1 286、`flip-m4.3.sh` 378、`flip-p287-lock.sh` 342、
`flip-m7.2.sh` 324、`panel-flip-p125.sh` 318、`flip-m48.sh` 304、`flip-p217.sh` 291、`flip-p20.sh` 286。
测量：从 `tests/smoke.sh`、`tests/perf.sh`、`ci/**`、`.github/workflows/gates.yml`、`docs/team/tools`、`scripts/**`
出发的静态可达性扫描——127 个夹具文件里 **54 个不可达（13 030 行）**；其中 `panel-b3.sh` 与 `flip-m33.sh`（1 746 行）
被 `openspec/specs/verification/spec.md:651/1291` 的两条 scenario 点名，删它们要一条 spec delta → 先删不要规格的 52 个。
它们现在守什么：**不守任何东西**（没有调用点），是历史红侧证据生成器。谁已守住：归档的 change + 报告保着结论；
门禁里对应段自带影子/`--break=` 红侧（§34c①、§34d①②③、§0i、§36⑩）。删了失去什么：重跑历史变异的能力；
`references/troubleshooting.md:1123` 那句"钉住这件事的夹具是 `tests/panel-b3.sh board`"会失去所指（该文件在保留集里，
所以只是句子要改）。**重叠**：`panel-b2.sh` 在 P318 第 1 轮写集里 → 并 P318，不另派。

**4. 合并两份"席位 = 运行时目录"** —— 让 `gate_lock_seat_of_dir` 复用 `team_sender_from_dir`，删
`gate-lock.sh:489–513` 与 §34b⑨ 的五条断言（`smoke.sh:16715–16732`）。它现在守什么：席位名按运行时目录解析、
名册拼写优先、主检出=pm、判不出不猜。谁已守住：§47 的 P82 1.2/1.3 四条（`smoke.sh:20165/20169/20172/20182`）+
§32 的身份闸门。删了失去什么：锁记录"解析不出"时写 `?` 的形状——notify 那份是**拒绝并退出 1**，合并要 PM 裁
"锁记录遇到项目外 cwd 是写 `?` 还是拒绝写记录"。

**5. 收掉 panel-p21 里 7 个从不上场的场景**（`write/conflict/categories/policy/flip/choices-schema/readonly`；
门禁只跑 `choices` 与 `groups/settings/wheel`），只把 `readonly` 接进 §38-f（+2 行）。它现在守什么：设置视图的
写/冲突/分类/策略/翻转/只读面。谁已守住：`38-a panel-choices.sh` 的 86 次选择集走查 + §33 config schema；
**readonly 这一面没有别的守卫**（它与动作 3 里 panel-b2 的同名场景是同一个事实的两份书面断言）。删了失去什么：
这批书面断言（今天一条没跑）；接 readonly 进门禁后剩下失去的是"未来有人手跑全套"的便利。**重叠**：同动作 3，
P318 第 1 轮在同一文件上活动。

## 验收证据（都是本 worktree 上真跑的）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict   # 裸 openspec 不在本 shell 的 PATH 上
Totals: 20 passed, 0 failed (20 items)

$ git status --short
?? docs/team/reports/P328-dev-bob.md

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/dev-bob scope=published files=1837 hits=0 names=ok user=resolved      # rc=0
```

- 没跑任何套件、容器、计时实验。数字来自 `wc -l`、`rg`、一次静态可达性扫描（脚本落 `/var/tmp/p328/`，不进树）、
  一次纯函数探针（`gate_lock_expected`/`gate_lock_cap` 各调一次，锁文件写 `/var/tmp`）。
- 没改任何代码、夹具、门禁、规格、模板、配置；没有新增检查器、预算表、分级机制。
- 没读 `docs/team/reports/**`（不在允许读的清单里）：P318 的结论只经任务书转述，panel-b2 那一条我自己重新量过。
- 已知风险：可达性扫描按字面文件名匹配，**用变量拼出来的调用点会漏**；另行 grep 过 `tests/$`、`tests/"` 两种形状（只有 `smoke.sh:1723/1738` 的 P70 变量与 `:17754/19017` 的沙箱软链），方向上不会把不可达判成可达。

## Decisions and deviations

- 19 条而非 20：按 archive 提交日期取证（`git log --diff-filter=A -- 'openspec/changes/archive/*/proposal.md'`），
  10-13 起最早一条是 `8f638fc4`（10-14）。
- 分类按"用户可感知的能力"判，不按文件面判：`gate-lock-*`、`tmp-root-on-disk` 落在 `scripts/**` 但判 governance（理由在表里写）；按文件面判则这三条改 product，结论变 14/5。

## Suggested next steps

- 需要 PM 裁：动作 2 要不要连 verification 那条 requirement 一起提一个 change；动作 4 合并后的拒绝语义；动作 3
  一次删完还是分批。
- 动作 3 与 5 落在 P318 第 1 轮正在动的文件上，建议并入 P318 而不另派单。

## PM 裁定（2026-10-20，对守卫清点）

清点收下。**最有价值的不是那条 11 284 行的清单，而是你在动作 2 里写下的那句话**：cap 算式的输入今天恒为 0，所以「自适应上限」根本不生效。我复核了 `smoke.sh:558/637`——`gate_lock_expected … /dev/null`，P316 删预算表时把它的生产者一起抽掉了，而**没有人发现**，因为再没出现过「合法长跑 + 有等待者」的组合。这正是「A 修好了会抽掉 B 的前提」那个形状，第二次。

五条裁定的结果：**3 条接受、1 条改判、1 条并入 P318**。

### 动作 1（§58 三条内联翻转）：改判 —— 只删两条，留 flip②

你说内联三例是夹具表的子集。我核了 `signal-lint.pl` 的 `--selftest`：它对 29 例逐例跑真二进制、只判「红/净」，**不判位置**。而内联 flip② 断言的是 `p159-lint-flip/x.sh:2` ——「判红并且按 file:line 点名」，这一条**全树只有它在守**（`smoke.sh:22172`，我 grep 过）。flip①（干净文件不误报）与 flip③（`kill -TERM "$pid"` 不误报）确实是表里的 `kill_term_pid` 等例子的子集（selftest 也是把每例写成 `case.sh` 用 `--root` 扫），删。
所以：删 ①③ 与它们的 scratch 写入，**flip② 原样留**，并在注释里写明「表判红/净，本条判位置」。

### 动作 2（cap 算式残留）：**不删代码，删两句假话 + 一条断言；真缺陷另立**

删算式不会修它，只会把「不说实话的注释」变成「没有这是事」，而真缺陷（合法长跑 80 分钟 + 等待者 → 等待者按 30 分钟上限 FAIL）**今天就在**。所以：
- 保留 `gate_lock_cap` 与其分支（它是唯一记录「上限该怎么随持有者伸缩」的地方）；
- 删掉 `smoke.sh:559/637` 那两行注释里的「expected/bound 为 0/0」（实测 bound=121500，是假话），改成「P316 之后没有生产者 → expected=0，cap 退回 W」；
- 删掉 §34⑦ / §34b⑨ 里**只为自造 expected=400/300 服务**的那几条断言（守一个没有生产者的数），但**保留** §34b①/⑦（排队超限大声失败、点名持有者）与「读不到 expected 时退回 W」这条**真**行为。
- 真缺陷（等待者的耐心应跟随持有者**心跳**而不是预算投影）我另立 P329，等 P326 放开 `smoke.sh` 再动 —— 它与动作 1/4 撞同一批文件。

### 动作 3（52 个从不调用的夹具 / 11 284 行）：接受，一次一批，但有四条硬约束

这是今天唯一一处「删掉不可能减少覆盖」的减法（它们从不运行）。约束：
1. **不碰** `panel-b2.sh`（P318 写集）、`panel-b3.sh` 与 `flip-m33.sh`（verification 的两条 scenario 点名，删它们要 delta）、`panel-p21.sh`（P318 的 D-3 正在改）；
2. 每删一个，先用**你自己的扫描**确认零引用，并在报告里给「文件 → 行数 → 扫描命令 → 零引用输出」；删完再跑一次扫描，剩下的引用数必须是 0；
3. `loop-inventory.tsv` 里属于被删文件的行同时删（否则 §0e 会红），删完 `bash skills/teamsmith/tests/smoke.sh --select 0e` 必须绿；
4. **凡是 `references/*.md`、`SKILL.md`、`openspec/**` 或 `docs/team/tools/**` 里点到名的夹具，先列出来给我，不许自己判断要不要删** —— 那类删除要么改文档、要么改规格，不在这一批。
另外：报告开头就写清「这批删掉的是 52 个从不执行的翻转/深水夹具；它们守的行为现在由 X 段的自带红侧承接」，并给一条**反例**：随机挑 2 个被删夹具原本能造红的场景，用门禁里对应的段跑一次，证明那个行为今天仍被抓住。

### 动作 4（席位=运行时目录两份实现）：接受，按「共享推导、各自决定失败语义」

合并**推导**（一份函数），不合并**失败语义**：锁记录的写入永不失败（解析不出就写 `?`，它是诊断），`team notify` 解析不出必须拒绝（发给谁的都不知道）。你的问题就是这个答案。§34b⑨ 的五条断言里，「解析不出写 `?`」保留，「与 notify 逐字同源」改成「调用同一函数」的断言。这一条与动作 1/2 一样撞 `smoke.sh`，**排进 P329 同一批**。

### 动作 5（panel-p21 七个不上场的场景）：并入 P318

`panel-p21.sh` 已在 P318 的写集里（D-3 要把 `readonly` 搬进 §38-f）。所以整条并进 P318：七个不上场的场景该删就删，`readonly` 按 D-3 搬进 §38-f 再删。**但先确认它们各自真的零调用**（含 `flip-p*.sh` 与 `docs/team/tools`），写进 P318 的报告。

### 一条给你自己的话

你把 19 条归档按「用户可感知」分了 11/8，同时算出 smoke.sh 里 22%（5 003 行）在守仓库自己的流程。这两个数字放在一起，就是用户那句「为保证 Agent 不犯错，逐渐构建了一套软件系统来管理 Agent」的量化版本。下一轮清点的口径改成：**每一条 governance 变更，必须在当时就说明「它替掉了什么」**（净零），没有说明的，标出来给我。
