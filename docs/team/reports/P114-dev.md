# P114 · `model-id-shape` apply · dev

agent: dev   status: **DELIVERED**   time: 2026-09-28T18:25Z
branch: `task/P114-id-apply`   PR/MR: -（本地模式：不 push）
change: `model-id-shape`（proposal 已 ACCEPTED：`docs/team/reviews/model-id-shape-proposal.md`）
specs: `memory-and-deps#A model id is a single-segment provider plus a model that may contain /`
deltas: `memory-and-deps`（本任务未改 delta 字节：7 条场景的实现与规格逐字一致，见 §4）
phase: apply

## 0. 交付物

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-config.sh` | `team_config_model_violation`（唯一判定）；`model` kind + `pairlist` token + `set-agent-model` 走它；`team_config_model_shape_ok` 退化成布尔包装；拒绝文案点名段落 |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | `team_pi_args` / `dispatched … model=` / `add-agent --model` 走同一判定；worker 渲染 `--model ${model#*/}` |
| `skills/teamsmith/scripts/lib/common.sh` | `team_pm_pi_args`、`{model}` 占位符、`team_model_window_from_pi` 都按**第一个** `/` 切 |
| `skills/teamsmith/tests/config-cli.sh` | 新 `shape` 段（接受/拒绝矩阵、读面、渲染器、窗口两条来源）+ 新 `flip-shape` 段（F-S1/F-S2 红绿两侧） |
| `skills/teamsmith/tests/panel-choices.sh` | `known` 夹具带三段 id；`walk` 夹具默认三段 id（每个 offered 值都过写校验器） |
| `skills/teamsmith/tests/panel-p21.sh` | `seats` 场景：选择器列出并选中三段 id（回执与契约行带完整 id）；附带修掉 `choices-schema` 里一条**先存的针碰撞**（见 §4） |
| `docs/team/reports/P114-dev.md` + `P114-dev/` | 本报告与原始日志（`10-route-parity.log`、`00-gates-fast.log`、…） |

Commit：`d20e6228`（判定）→ `809fe9bb`（渲染器/窗口）→ `8e887dd3`（config-cli 夹具）→
`49f9e319`（panel-choices）→ `d4d501e0`（panel-p21 夹具）→ `3c5092e8`（先存针碰撞的修复）；
每个可验证小步一笔。

## 1. 硬要求逐条兑现（brief §硬要求 1–7）

| # | 要求 | 兑现 | 证据 |
|---|---|---|---|
| 1 | 三段 id 在**三处写入器**都过 | `openrouter/amazon/nova-lite-v1` → rc 0/0/0（+ `add-agent --model` 第 4 路 rc 0） | §2.1、`shape` 段 50 条断言 |
| 2 | **先剥 `:思考档` 再判形状**、值里保留后缀 | `kimi-coding/kimi-for-coding:high` 与 `…/nova-lite-v1:high` rc 0、行内逐字带 `:high` | §2.1、`shape` 后缀块 |
| 3 | 拒绝集闭（无 `/`、前导/尾随 `/`、空段、空白）且**点名段落** | 8 条 model-kind + 3 条 seat + pairlist + add-agent，全部 rc 4，原因以 `provider …` / `model …` 开头 | §2.2 |
| 4 | **只有一处判定** | `team_config_model_violation` 被 4 条写路共用；`flip-shape` 放宽这一处 → 三条路同时变红并点名 `a//b` | §3 F-S1 |
| 5 | 渲染器按**第一个** `/` 切 | dispatch/up `--print`、`{model}`、窗口解析全用 `${x#*/}`；`TEAM_MODEL_WINDOWS` 三段 key → 300k | §2.3 |
| 6 | 读面不崩（完整 id） | `config list --json` 的 `models.default`/`known`/席位行、`choices.values` 逐字；面板选择器列出并写入完整 id（真 pty） | §2.4 |
| 7 | 红侧两态 | F-S1 放宽判定 → `a//b` 三条路红；F-S2 最后一个 `/` 切 → 窗口解析红；还原 → 绿 | §3 |

## 2. 绿侧原始输出

### 2.1 三处写入器同一裁决（接受）

```
$ config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes          rc=0
$ config set TEAM_AGENT_MODELS 'dev=openrouter/amazon/nova-lite-v1' --yes     rc=0
$ config set-agent-model dev openrouter/amazon/nova-lite-v1 --yes             rc=0
$ add-agent api --register --model openrouter/amazon/nova-lite-v1 --no-install  rc=0
TEAM_AGENT_MODELS='dev=openrouter/amazon/nova-lite-v1 api=openrouter/amazon/nova-lite-v1'
TEAM_DEFAULT_MODEL='openrouter/amazon/nova-lite-v1'
```

全文：`docs/team/reports/P114-dev/10-route-parity.log`（脚本 `10-route-parity.sh`，夹具仓库 + 私有 `TEAM_*`）。

### 2.2 拒绝集闭 + 点名段落（同一输入三条路同一裁决）

```
$ config set TEAM_DEFAULT_MODEL a//b --yes
✗ TEAM_DEFAULT_MODEL=a//b 不合法：model 有空段（/ 分隔的每一段都必须非空）                            rc=4
$ config set TEAM_AGENT_MODELS 'dev=a//b' --yes
✗ TEAM_AGENT_MODELS=dev=a//b 不合法：席位 dev 的模型：model 有空段（/ 分隔的每一段都必须非空）        rc=4
$ config set-agent-model dev a//b --yes
✗ 模型必须是 provider/model 形状（model 有空段（/ 分隔的每一段都必须非空））：a//b                     rc=4

$ config set TEAM_DEFAULT_MODEL '/a' --yes    → rc=4  provider 为空（/ 前没有内容）
$ config set TEAM_DEFAULT_MODEL 'a/'  --yes    → rc=4  model 为空（/ 后没有内容，或 :思考档 后缀前为空）
$ config set TEAM_DEFAULT_MODEL 'a/:high' --yes→ rc=4  model 为空（… :思考档 后缀前为空）
$ config set TEAM_DEFAULT_MODEL 'a:q/b' --yes  → rc=4  provider 不能含 :（:思考档 后缀只属于 model 段）
$ config set TEAM_DEFAULT_MODEL 'a b/c' --yes  → rc=4  provider 含空白（空格/制表符/换行）
```

`shape` 段额外钉住：拒绝矩阵后契约 sha256 不变、`state/config.log` 无新增 `result=ok`；`a`/`a:b` 类
provider 缺失/含 `:` 也各一条。

### 2.3 渲染器与窗口

```
$ team dispatch dev SHP <brief> --print   → --provider openrouter --model amazon/nova-lite-v1
$ TEAM_PM_MODEL=openrouter/amazon/nova-lite-v1 team up --print
                                          → --provider openrouter --model amazon/nova-lite-v1
$ team_agent_expand launch '{model}' …    → amazon/nova-lite-v1
$ team ps（TEAM_PI_AGENT_DIR→scratch models.json: openrouter/stealth/union-alpha, 131072）
openrouter/stealth/union-alpha   0   -   131k        ← 不再是 ?
$ TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000' team ps
openrouter/stealth/union-alpha   0   -   300k
```

`config-cli.sh shape`（真命令的 tail）：

```
$ bash skills/teamsmith/tests/config-cli.sh shape
  ✓ 窗口[Pi 目录]：三段 id 的 catalogue 窗口 → 131k
  ✓ 窗口[TEAM_MODEL_WINDOWS]：三段 key 命中 → 300k
== 结果 ==  ✓ 50  ✗ 0  SKIP 0
```

### 2.4 读面与选择器

- `config-cli.sh shape`：`models.default` 是完整三段 id；`known` 带 `…/nova-lite-v1` 与
  `…/nova-lite-v1:high` 两种形态；dev 席位行 = 配置覆盖的完整 id。
- `panel-choices.sh`（headless）：`✓44 ✗0`；三段 id 进 `models.known`、`TEAM_DEFAULT_MODEL` 与
  `TEAM_AGENT_MODELS` 的 `choices.values`，`walk` 夹具的默认就是三段 id，每个 offered 值都过
  `team config set … --dry-run`。
- `panel-p21.sh`（真 pty + 真 bundle + 私有 tmux server）**全场景**：`rc=0 ✓280 ✗0`（第一跑
  ✓279 ✗1 是 §4 的先存夹具缺陷，修后全绿）。其中 `seats` 的 23 条含
  `picker 列出命令报告的三段已知模型`、`写入回执带完整三段 id（不是最后一段）`、
  `契约里 dev 的 token 落盘（完整三段 id）`。原始日志：`P114-dev/41-p21-full.log`。

## 3. Flip 证据（F-S1 / F-S2：破坏实现 → 守卫红 → 还原 → 绿）

`flip-shape` 段在 scratch 树上改唯一判定 / 窗口切分，原样跑 `config-cli.sh shape`：

```
$ bash skills/teamsmith/tests/config-cli.sh flip-shape
  ✓ F-S1 绿侧：scratch 树原状 shape 段绿（rc=0，红不是因为缺文件）
  ✓ F-S1 mutant：唯一判定被放宽成「含 / 就过」
  ✓ F-S1 红侧：放宽后 shape 段非 0（rc=1），三条路都点名 a//b
    --- F-S1 红侧尾部 ---
      ✗ 拒绝[set-agent-model] dev a//b 没有点名 [model 有空段]（）
      ✗ 拒绝[pairlist] dev=a//b → 4（期望 [4]，实际 [0]）
      ✗ 拒绝[pairlist] dev=a//b 没有点名 [model 有空段]（）
      ✗ 拒绝[add-agent --model] api2 a//b → 4（期望 [4]，实际 [0]）
      ✗ 拒绝[add-agent --model] a//b 没有点名 [model 有空段]（…）
    == 结果 ==  ✓ 22  ✗ 28
  ✓ F-S2 mutant：窗口解析改成最后一个 / 切
  ✓ F-S2 红侧：最后一个 / 切分让窗口断言红（rc=1）
    --- F-S2 红侧尾部 ---
      ✗ 窗口[Pi 目录]：三段 id 的 catalogue 窗口 → 131k（期望 [131k]，实际 [?]）
    == 结果 ==  ✓ 49  ✗ 1
  ✓ F-S1/F-S2 还原：两处改动都撤销 → shape 段重新绿（rc=0）
== 结果 ==  ✓ 6  ✗ 0  SKIP 0
```

F-S1 红侧日志里 `拒绝[model-kind] a//b` 也在（段内用三条 `grep -q` 分别点名三条路，三条都命中才给
✓；缺任一条就 ✗）。全部原始输出：`docs/team/reports/P114-dev/30-flip-shape.log`。

### 3.1 修复前 → 修复后（同一 `shape` 段，脚本换实现）

同一份测试代码，`TEAM_CONFIG_TREE` 分别指向 `HEAD~5`（修复前的 scripts）与本 tip：

```
$ git archive HEAD~5 skills/teamsmith/scripts skills/teamsmith/templates skills/teamsmith/references | tar -x -C "$old"
$ TEAM_CONFIG_TREE="$old" bash skills/teamsmith/tests/config-cli.sh shape
  ✗ 拒绝[model-kind] a b/c 没有点名 [provider 含空白]（）      ← 旧规则接受带空白的 value
  ✗ 拒绝[set-agent-model] dev /a 没有点名 [provider 为空]（✗ 模型必须是 provider/model 形状（恰好一个 /）：/a）
  ✗ 拒绝[set-agent-model] dev a/ 没有点名 [model 为空]（…（恰好一个 /）：a/）
  ✗ 拒绝[set-agent-model] dev a//b 没有点名 [model 有空段]（…）
  ✗ 拒绝[pairlist] dev=a//b 没有点名 [model 有空段]（…）
  ✗ 拒绝[add-agent --model] a//b 没有点名 [model 有空段]（…）
  ✗ 拒绝矩阵后契约 sha 不变（期望 […]，实际 […]）
  ✗ 拒绝矩阵没有新增 result=ok 审计行（期望 [1]，实际 [4]）
  ✗ 渲染器：{model} 占位符 = 第一个 / 之后的全部（期望 [amazon/nova-lite-v1]，实际 [c]）
  ✗ 窗口[Pi 目录]：三段 id 的 catalogue 窗口 → 131k（期望 [131k]，实际 []）
  ✗ 窗口[TEAM_MODEL_WINDOWS]：三段 key 命中 → 300k（期望 [300k]，实际 []）
== 结果 ==  ✓ 14  ✗ 36  SKIP 0

$ bash skills/teamsmith/tests/config-cli.sh shape          # 本 tip
  ✓ 窗口[Pi 目录]：三段 id 的 catalogue 窗口 → 131k
  ✓ 窗口[TEAM_MODEL_WINDOWS]：三段 key 命中 → 300k
== 结果 ==  ✓ 50  ✗ 0  SKIP 0
```

全文：`docs/team/reports/P114-dev/20-flip-before-after.log`。同一段在旧实现上 36 条红，在本 tip 上 0 条红。

## 4. 决定与偏差

- **delta 未改**：7 条场景的实现与 `openspec/changes/model-id-shape/specs/memory-and-deps/spec.md` 逐字
  一致（含 `provider:suffix/model` 拒绝、`:high` 先剥后判、`a//b` 三条路点名）；`openspec validate
  --all --strict` 17/17 ✓。没有为了过测试去改规格文字。
- **`references/*.md` 未改**：`references/config.md` 与 `agent-adapters.md` 的 `provider/model` 例子仍准确
  （`{model}` 的语义就是「provider 之后的全部」），没有「恰好一个 `/`」的表述可改。
- `panel-p21.sh seats` 夹具把 PM 席位模型设为三段 id（一个手改契约行），让 `known` 里出现三段 id；
  这改变了既有挑选目标（原来是记录来源的 `kimi-coding/k3-256k`，仍一并断言在列表里）。
- brief 允许 `skills/teamsmith/tests/**`（append-only 的 smoke.sh 未动：本次不需要改 smoke，config-cli 的
  新段自动进入既有 §33 全跑）。
- **发现并修掉一条先存的夹具缺陷（不是 P114 引入，请 PM 知悉是否要单独记账）**：
  `panel-p21.sh` 的 `choices-schema` 场景用**裸针** `assert_not … "自由输入"` 断言「封闭域没有自由输入项」，
  而选择器的页脚帮助行（M68 `a36a7c0c` 起，已在 main 上）本身就写着「『自由输入』才进编辑器」——
  针把页脚当命中，场景在 main 上就红（旧针 `78fc8808` M55，也在 main 上）：

  ```
  $ git archive main skills/teamsmith | tar -x -C "$mk"
  $ bash "$mk/skills/teamsmith/tests/panel-p21.sh" choices-schema
    ✗ enum 是封闭域：没有自由输入项（不该出现 [自由输入]）
  == 结果 ==  ✓ 8  ✗ 1  SKIP 0            ← main（P114 之前）自己的树

  $ grep -c '自由输入' choices-schema/zzz-picker.txt      → 1   ← 页脚「『自由输入』才进编辑器」
  $ grep -c '…（自由输入）' choices-schema/zzz-picker.txt  → 0   ← 封闭域确实没有那个条目

  $ TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh choices-schema   # 本 tip
    ✓ enum 是封闭域：没有自由输入项
  == 结果 ==  ✓ 9  ✗ 0  SKIP 0
  $ bash skills/teamsmith/tests/panel-p21.sh                                  # 本 tip 全场景
  == 结果 ==  ✓ 280  ✗ 0  SKIP 0          rc=0
  ```

  修法：针改成与另三条同一形状的 `"…（自由输入）"`（关的是**条目**，不是页脚文案），附一行注释说明
  为什么不能裸词。原始日志：`P114-dev/42-choices-schema-before.log`、`41-p21-full.log`。
  `choices-schema` 不在 smoke 的固定选段里（smoke 跑 `choices` + `groups settings wheel`），所以此前没被闸门抓到。
- 这条修复动了 `panel-p21.sh`（在我获权的 `skills/teamsmith/tests/**` 内）；它与 model-id-shape 无关，
  PM 可以接受（它就在本报告与分支里）或要求单独开局重做 —— 无论如何先让 PM 看见。

## 5. 门禁（本 tip 上的真跑）

### 5.1 定向

```
$ openspec validate --all --strict
Totals: 17 passed, 0 failed (17 items)                                    rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 7  bad 0                                              rc=0
$ section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh   → decision=RUN sections=113
（config-cli.sh / panel-choices.sh / panel-p21.sh 同样 decision=RUN sections=113：受影响面=全量，见 5.3）
```

### 5.2 FAST

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 3002  ✗ 0
smoke 全绿                                                                 rc=0    （949.9s）

# 最终代码 tip（含 §4 的 panel-p21 针修复）再跑一次：
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 3002  ✗ 0
smoke 全绿                                                                 rc=0    （909.5s）
```

### 5.3 全量

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
#84 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） · 用时 78s · ✓1 ✗0
#97 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 用时 298s · ✓22 ✗0 SKIP0
#76 26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离） · 用时 109s · ✓142 ✗0
账本自查： 112 段收口 · 增量 ✓3667 ✗0 SKIP0 ｜ 结果行 ✓3667 ✗0 —— 一致
== 结果 ==  ✓ 3667  ✗ 0
smoke 全绿                                                                 rc=0    （1561.2s）

# 最终代码 tip（`3c5092e8`）重跑（panel-p21.sh 改过，所以闸门重跑）：
$ bash skills/teamsmith/tests/smoke.sh </dev/null
#84 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） · 用时 78s · ✓1 ✗0
#97 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 用时 300s · ✓22 ✗0 SKIP0
账本自查： 112 段收口 · 增量 ✓3667 ✗0 SKIP0 ｜ 结果行 ✓3667 ✗0 —— 一致
== 结果 ==  ✓ 3667  ✗ 0
smoke 全绿                                                                 rc=0    （1567.6s）
$ openspec validate --all --strict
Totals: 17 passed, 0 failed (17 items)                                    rc=0
```

原始日志：`docs/team/reports/P114-dev/00-gates-full.log`（首跑）与 `00-gates-full-final.log`
（最终代码 tip）+ `00-gates-fast.log` / `00-gates-fast-final.log`；`panel-p21.sh seats` 的真实 pty 轨迹：
`40-p21-seats.log`；全场景 p21：`41-p21-full.log`。

## 6. 给 PM 的下一步

- `team review P114 --strong`：§3 F-S1/F-S2 是 --strong 要的翻转证据（破坏两处实现 → 对应守卫红 →
  还原 → 绿），§3.1 另给同一段在旧/新实现上的 36 → 0 对照；§5.3 是本 tip 上的全量。
- 请顺带看一眼 §4 的**先存夹具缺陷**（`choices-schema` 的裸针碰撞，main 上就红，顺手在本分支修了）：
  若不希望它混在 P114 里，可在复验时把它当作独立发现处理（改回去或另立任务）。
- 复验重点建议：`bash skills/teamsmith/tests/config-cli.sh shape flip-shape`、`panel-choices.sh`、
  `panel-p21.sh seats`，以及 `git diff <base>..tip -- skills/teamsmith/scripts/lib/` 确认渲染器三处都
  改成 `${x#*/}`（无残留 `${x##*/}` 的 model 切分）。
- 本地模式：分支留在 `.worktrees/dev`（`task/P114-id-apply`），未 push。
