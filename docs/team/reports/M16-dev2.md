# M16 · 沟通纪律：代号必须随身带人话名字

agent: dev2   status: DONE   time: 2026-09-17T05:05:00Z
branch: `task/M16-pm-cli`   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

用户反馈（2026-09-17）：“PM 喜欢只用代号（M2、T1.2）指代事务，但用户不一定记得这些编号。” 规则落成两半：
**面向人的输出里代号必须随身带名字**（PM 提示词 + 协议 §11），以及**CLI 自己先做到**（digest / status /
roster；名字来源 = BOARD 任务列 → 任务书 H1 → 报告 H1；查不到名字就只印代号，绝不编名字、绝不藏代号）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | 新增 `team_task_name`（三级名字来源）/ `team_task_label`（`<ID>（名字）`）/ `team_task_name_suffix`（`（名字）`）。digest 四处补名字：[3] 待复验行与「已按看板跳过」行、[4] 待收尾两行（squash 已合并 / 脏·未 push）、[5] 建议行；`team status <ID>` 抬头 `任务 <ID>：<名字>`；roster 任务列 `<ID>（名字）` |
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | 新增「Talking to the user: a code never stands alone」段（user-facing output / 长列表每行自成阅读单元 / 命令里代号是钥匙；名字优先取 BOARD 任务列）；loop 第 6 步「Report」的示例改成 `M12 (fix the smoke flake)` |
| `skills/teamsmith/references/protocol.md` | 新增 §11（英文）：规则的理由、豁免（可复制命令里的裸代号）、机制（三个 CLI 出口 + 三级来源 + 查不到就只印代号） |
| `skills/teamsmith/tests/smoke.sh` | 新第 30 节（20 条断言，纯逻辑、快慢都跑）：自建沙箱仓库 + 写盘前 `team paths` 身份断言，假 BOARD + 假报告集五种形状（看板有名字 / 只有任务书有 / 只有报告 H1 有 / 哪里都没有 / 看板已裁决），泛扫「凡含代号的行必须含名字」+ 空转扫描报红 + 负对照（不编名字） |
| `skills/teamsmith/tests/flip-m16.sh` | 独立翻转包（红树 = 分支分叉点 / 绿树 = 本树 / 变异树 = 绿树副本把 `team_task_name` 改成永远返回空）：同一份夹具三棵树，判据独立实现（不复用 smoke 的夹具与断言） |

**范围自查（brief 的边界）**：只动了 `templates/`、`references/`、`scripts/lib/cmd-status.sh`（digest/status/roster 输出）、
`tests/smoke.sh`（自己的第 30 节）与 `tests/flip-m16.sh`（新增）。**账本（BOARD/ROADMAP/DECISIONS/OWNERSHIP/reviews/
tasks）一个字节没动**；既有 smoke 断言一条没改（见「Decisions」的名字摆放决定）。

## Verification evidence (must have actually been run)

```
$ openspec validate --all --strict
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ spec/pm-lifecycle
✓ change/pulse-console
✓ spec/verification
✓ spec/watchdog
Totals: 13 passed, 0 failed (13 items)
```

```
$ bash skills/teamsmith/tests/smoke.sh          # 全量（含真 tmux/真进程段落）
...
== 30 · 代号必须带名字（M16） ==
  ✓ M16 夹具仓库 init 成功
  ✓ M16 隔离：team paths 的 main_root 就是 M16 夹具仓库
  ✓ M16 隔离：身份用的是本轮临时 session
  ✓ M16 夹具：M16E 已按看板裁决
  ✓ M16：digest 退出码 0
  ✓ M16-① 待复验行：M16A 出现的 2 行都带名字「夹具甲：代号必须带名字」
  ✓ M16-① 待收尾/建议行：M16B 出现的 3 行都带名字「夹具乙：收尾行也要带名字」
  ✓ M16-① 报告 H1 兜底：M16C 出现的 1 行都带名字「报告里的短名」
  ✓ M16-① 看板跳过行：M16E 出现的 1 行都带名字「夹具戊：跳过行也要带名字」
  ✓ M16-①：待复验行是「代号（名字）」形状
  ✓ M16-①：名字从报告 H1 兜底取得
  ✓ M16-①：跳过行也带名字
  ✓ M16-①：待收尾/建议行带名字
  ✓ M16-①：[5] 建议行带名字
  ✓ M16-①：跳过行仍然说明了为什么没列
  ✓ M16-②：查不到名字时照旧只印代号（不编名字、不藏代号）
  ✓ M16-②：M16D 所在的行没有凭空造出名字
  ✓ M16-③：team status 抬头行带名字
  ✓ M16-③：roster 任务列带名字
  ✓ M16 隔离：真实账本的 inbox/state 里没有夹具的痕迹

== 结果 ==  ✓ 1824  ✗ 0
smoke 全绿
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
...
== 30 · 代号必须带名字（M16） ==
  （同上 20 条全绿）

== 结果 ==  ✓ 1421  ✗ 0
FAST 模式：跳过 18 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
```

一次性整条门禁（brief 的验收命令）实际执行（rc=0）：

```
$ openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
Totals: 13 passed, 0 failed (13 items)      # openspec
== 结果 ==  ✓ 1824  ✗ 0                       # 全量 smoke
smoke 全绿
== 结果 ==  ✓ 1421  ✗ 0                       # FAST smoke
smoke 全绿
$ echo $?
0
```

注：本容器里 `openspec` 在 `~/.bun/bin`（不在默认 PATH），执行时 `export PATH="$HOME/.bun/bin:$PATH"`；
二进制版本与 `team doctor` 用的是同一个（`which openspec` → `<home>/.bun/bin/openspec`）。

人工现场（同一夹具在真终端里的样子，证明不是只有断言能看见名字；digest 相关行）：

```
  [3] 待复验
  M16A-dev（夹具甲：代号必须带名字）  →  team review M16A
  M16C-dev（报告里的短名）  →  team review M16C
  M16D-dev  →  team review M16D                      ← 哪里都没名字：只印代号（负对照）
  已按看板跳过 1 份报告（任务已 done/closed）：M16E-dev（夹具戊：跳过行也要带名字） · …
  [4] 待收尾
  dev        脏 1 ｜ 无 upstream（未 push 无法判定）    ｜ task/M16B-fixture ｜ M16B（夹具乙：收尾行也要带名字）
  [5] 建议
  · dev 未在跑但仍有任务 M16B（夹具乙：收尾行也要带名字） → team dispatch 续跑，或 close M16B

任务 M16B：夹具乙：收尾行也要带名字                  ← team status M16B 抬头
dev  · 无窗口  task/M16B-fixture  1  0  -  …  -  M16B（夹具乙…）   ← roster 任务列
```

## Flip evidence (required for defect-fix tasks)

两条方向都跑了：**破坏实现 → 守卫（smoke §30）必红 → 恢复 → 绿**；以及独立包 `tests/flip-m16.sh`
的**红树 → 绿树 → 变异红**（判据独立实现，不复用 smoke 夹具）。

### 1) 破坏实现 → smoke §30 必红 → 恢复（真实执行）

改动点：在 `cmd-status.sh` 的 `team_task_name()` 第一行插入 `return 0`（“永远解析不到名字”），其余不动。

```
$ awk '{ print; if ($0 ~ /^team_task_name\(\) \{/) print "  return 0  # M16 flip: break the implementation" }' \
      skills/teamsmith/scripts/lib/cmd-status.sh > /tmp/mut && cp /tmp/mut skills/teamsmith/scripts/lib/cmd-status.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh      # rc=1
== 30 · 代号必须带名字（M16） ==
  ✓ M16 夹具仓库 init 成功
  ✓ M16 隔离：team paths 的 main_root 就是 M16 夹具仓库
  ✓ M16 隔离：身份用的是本轮临时 session
  ✓ M16 夹具：M16E 已按看板裁决
  ✓ M16：digest 退出码 0
      缺名字的行：[  M16A-dev  →  team review M16A]
  ✗ M16-① 待复验行：M16A 有 1 行没带名字
      缺名字的行：[  dev        脏 1 ｜ 无 upstream（未 push 无法判定）    ｜ task/M16B-fixture ｜ M16B]
      缺名字的行：[  · dev 未在跑但仍有任务 M16B → team dispatch 续跑，或 close M16B]
  ✗ M16-① 待收尾/建议行：M16B 有 2 行没带名字
      缺名字的行：[  M16C-dev  →  team review M16C]
  ✗ M16-① 报告 H1 兜底：M16C 有 1 行没带名字
      缺名字的行：[  已按看板跳过 1 份报告（任务已 done/closed）：M16E-dev · 证据在 board set 时核对（M9.2），这里不重复质疑]
  ✗ M16-① 看板跳过行：M16E 有 1 行没带名字
  ✗ M16-①：待复验行是「代号（名字）」形状（… 中找不到 [M16A-dev（夹具甲：代号必须带名字）]）
  ✗ M16-①：名字从报告 H1 兜底取得（… 中找不到 [M16C-dev（报告里的短名）]）
  ✗ M16-①：跳过行也带名字（… 中找不到 [M16E-dev（夹具戊：跳过行也要带名字）]）
  ✗ M16-①：待收尾/建议行带名字（… 中找不到 [M16B（夹具乙：收尾行也要带名字）]）
  ✗ M16-①：[5] 建议行带名字（… 中找不到 [未在跑但仍有任务 M16B（夹具乙：收尾行也要带名字）]）
  ✓ M16-①：跳过行仍然说明了为什么没列        ← 只坏名字、不坏别的信号（破坏点单一）
  ✓ M16-②：查不到名字时照旧只印代号（不编名字、不藏代号）
  ✓ M16-②：M16D 所在的行没有凭空造出名字
  ✗ M16-③：team status 抬头行带名字（… 中找不到 [任务 M16B：夹具乙：收尾行也要带名字]）
  ✗ M16-③：roster 任务列带名字（… 中找不到 [M16B（夹具乙：收尾行也要带名字）]）

$ cp /tmp/m16-cmd-status.orig skills/teamsmith/scripts/lib/cmd-status.sh   # 恢复（grep 计数 0）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh      # rc=0
== 结果 ==  ✓ 1421  ✗ 0
smoke 全绿
```

红时共 11 条断言红，全部落在 §30 的名字断言上；恢复后同一命令全绿 —— 守卫确实在守这次改动。

### 2) 独立包 `tests/flip-m16.sh`（红 → 绿 → 变异红）

```
$ bash skills/teamsmith/tests/flip-m16.sh
flip-m16 · 红树=3f28e49130e9e18800f4953b319dfd1fe6c71359 绿树=…/.worktrees/dev2/skills/teamsmith
  ✓ 红（修复前）：夹具代号在同一行没有名字（判据会红）
      红树 [3] 待复验：
        M16A-dev  →  team review M16A
        M16C-dev  →  team review M16C
        M16D-dev  →  team review M16D
        · dev 未在跑但仍有任务 M16B → team dispatch 续跑，或 close M16B
  ✓ 红树确实印了 M16A-dev（代号没丢，只是没有名字）
  ✓ 绿（本树）：所有夹具代号都在同一行带上名字
  ✓ 绿树：看板任务列的名字
  ✓ 绿树：任务书 H1 的名字
  ✓ 绿树：报告 H1 兜底的名字
  ✓ 绿树：查不到名字时照旧印代号
      绿树 [3] 待复验：
        M16A-dev（夹具甲：代号必须带名字）  →  team review M16A
        M16C-dev（报告里的短名）  →  team review M16C
        M16D-dev  →  team review M16D
        · dev 未在跑但仍有任务 M16B（夹具乙：任务书里的名字） → team dispatch 续跑，或 close M16B
  ✓ 变异：去掉名字解析后同一判据变红（守门断言可被证伪）
      变异树 [3] 待复验：
        M16A-dev  →  team review M16A
        …（与红树同形）

== 结果 == flip 全绿（红→绿→变异红）
```

### 3) 反例也要红：夹具本身不许假绿

§30 的泛扫不是「有关键词就算过」：夹具代号一次都没出现时单独报红（扫描空转 = 假绿），
「查不到名字」的负对照禁止凭空造名字（`M16D` 行不得出现 `（`）。红阶段的输出里
`M16-②：查不到名字时照旧只印代号`、`M16-②：M16D 所在的行没有凭空造出名字` 两条在破坏实现时**仍然绿**，
正说明这两条守的是「不要乱来」而不是「名字在不在」。

## Independent verification package

- `skills/teamsmith/tests/flip-m16.sh` — 自建夹具仓库（自行 `team init`，先证明 `team paths` 指向它）、
  自带三棵树对比，**不复用** smoke §30 的夹具与断言（判据在包里独立实现一遍）。
- PM 复跑：`bash skills/teamsmith/tests/flip-m16.sh`（默认红树 = `git merge-base HEAD main`）；
  指定修复前 revision：`TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m16.sh`。
  传进来的 base 若已含实现，包会 rc=2 直接拒绝（避免报一个假的翻转）。
- 门禁里的守门断言：`tests/smoke.sh` 第 30 节（全量/FAST 都跑；纯逻辑，不写真实账本）。

## CLI 自查（brief 第 3 条）

| 出口 | 改前 | 改后 |
|---|---|---|
| digest [3] 待复验行 | `M16A-dev` | `M16A-dev（夹具甲：代号必须带名字）` |
| digest [3]「已按看板跳过」行 | `M16E-dev` | `M16E-dev（夹具戊：跳过行也要带名字）` |
| digest [4] 待收尾（脏/未 push、squash 已合并） | 只有任务 ID | `<ID>（名字）` |
| digest [5] 建议（停了的 agent） | 只有任务 ID | `<ID>（名字）`（命令行 `close <ID>` 保持裸代号） |
| digest [5] 任务板回显 | BOARD 行本来就带「任务」列 —— 不改 | 同左 |
| `team status <ID>` 抬头 | `任务 M16：` | `任务 M16：<名字>` |
| `team roster` 任务列 | 只有任务 ID | `<ID>（名字）` |
| 面板 `scripts/panel/src/layout.ts`（**边界外**） | agent 表 `task` 是 7 列定宽格，只放代号 | **未动**（pulse-console/P14 的列计划领地）→ 见「Suggested next steps」 |

## Decisions and deviations

1. **名字贴在哪：显示单元的末尾**（`<报告名> [stale: …]（归属）（名字）`），而不是紧贴报告名。
   原因：`T1.1-dev [gates: none]`、`M94E-m94z（在 m94z 分支上）` 这类显示串是**别的里程碑留下的回归断言**
   （smoke 3b / 10b×2 / 21 / 23 共 5 条）钉住的；把名字插在中间会让那些断言红，就得去改别的段落——超出本任务书的边界，
   也会动到历史的守门证据。贴末尾同样满足 brief 的判据（「代号同行的同一行上有该任务的名字」），
   且名字与代号之间只隔报告名自带的标记/归属。`roster`/`status` 没有这些标记，名字就紧贴代号。
   `team status` 保持 `任务 <ID>：` 前缀不变（前缀是既有断言与 PM 习惯），名字跟在冒号后。
2. **名字来源三级**（BOARD 任务列 → 任务书 H1 → 报告 H1）：看板是 PM 维护的正式短名，优先；
   报告 H1 是叠分支/任务书还没写名字时的兜底。查不到就返回空 → **只印代号**：
   不编名字（假名字比没名字更糟），也不因为没名字就不印代号（代号丢了账本就对不上人）。
3. **不动 docs 账本**：BOARD/ROADMAP/DECISIONS/OWNERSHIP/reviews/tasks 与本任务的 `docs/team/*` 只读。
4. 文档里新增的例子用 `team close M12`（不是 `team review M12`）：smoke 15b 的用法守卫禁止文档出现
   不带 `--dir` 的 review —— 第一版文案被它抓红（`✗ 文档在教「没有 --dir 的 review」`），已改。
5. `templates/prompt-pm.md.tmpl` 在 brief 里写的是这个名字，仓库里实际是 `templates/pm-prompt.md.tmpl`
   （同一件东西，按实际路径改）。

## Suggested next steps

- 面板的 agent 表任务列（`scripts/panel/src/layout.ts` 的 `task: 7` 定宽 + `a.task`）仍是裸代号，
  但它属于 P14 的列计划（PM 领地），本任务未动；若要「面板也带名字」需要 PM 决定列的宽度/截断优先级。
- `team dispatch/close/review` 这类**命令回显**保持裸代号（代号是钥匙，命令里改名会破坏可复制性）——
  协议 §11 已把这条豁免写清楚；如果 PM 想要命令回显也带名字，需要单独的决策（会牵动这些命令的输出契约）。
