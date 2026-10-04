# P102 · `model-id-shape` 提案 · **propose** · dev

agent: dev   status: **DELIVERED（propose 四件套）**   time: 2026-09-28T15:45Z
branch: `task/P102-id-model-propose`   PR/MR: -（本地模式：不 push）
change: `model-id-shape`（本任务 = **propose**，不写实现）
specs: `memory-and-deps`（提案 header 的 `specs:` 行）
deltas: `memory-and-deps`（本任务写 `openspec/changes/model-id-shape/specs/memory-and-deps/spec.md`）
phase: propose

## 0. 交付物

| Path | What |
|---|---|
| `openspec/changes/model-id-shape/proposal.md` | why / what / 事实核对 / flip / 边界 / 验收命令 / 报告必含证据 |
| `openspec/changes/model-id-shape/specs/memory-and-deps/spec.md` | 1 条 ADDED requirement + 7 个可证伪场景 |
| `openspec/changes/model-id-shape/design.md` | 形状规则与取舍、单一判定实现、读取方切分、窗口修复、被拒备选、测试落位 |
| `openspec/changes/model-id-shape/tasks.md` | 4 组 9 条可验证步骤 + 场景→命令对照表 + 路径授权 |
| `docs/team/reports/P102-dev.md` | 本文件（commit `741dbfd1` 为四件套） |

## 1. 事实核对（对 brief 的「事实」节，全部实测）

1. **多段 id 合法（fact 1 复核）**：`pi --provider openrouter --model amazon/nova-lite-v1 -p …` → rc 0。
   附带发现：`--provider openrouter --model nova-lite-v1`（只给末段）也 rc 0，但那是 Pi 的**模糊匹配**
   兜底（Pi 源码 `parseModelPattern`：先精确匹配，再按 **last colon** 拆思考档并要求后缀在
   `off|minimal|low|medium|high|xhigh|max` 里，再模糊）——不是精确命中。
2. **校验器全拒（fact 3 复核）**：`model` kind、`pairlist` token、`set-agent-model`（共用
   `team_config_model_shape_ok`）、`add-agent --model` 四路都把 ≥3 段当非法，错误文案是「恰好一个 /」。
3. **窗口解析 premise 修正（重要）**：brief 写 `team_model_window` 现为 `prov=${want%%/*}` /
   `model=${want##*/}` ✓ ——这只对 `TEAM_MODEL_WINDOWS` 显式覆盖分支成立。**Pi 目录分支对三段 id 返回空**
   （`team_model_window_from_pi` 用 `${want##*/}` 去对 Pi 目录里的 `id`，而 openrouter 的 id 本身带
   `/`）。夹具实测见 §2。因此我把 `${want#*/}` 修复纳入 change——否则 brief 要求的「窗口解析必须对多段
   id 正确」在 Pi 目录路径下不成立。已在 proposal 的 fact-check 节点名，提案复核可否决。
4. **同一末段切分还在启动渲染器里**：`team_pi_args`（`cmd-agents.sh`）、`team_pm_pi_args` 与 `{model}`
   （`common.sh`）都是 `${model##*/}`。对三段 id，派单会渲染 `--model nova-lite-v1`——精确模型被降级为
   Pi 的模糊选择。也纳入 change（proposal 点名，复核可否决）。
5. **今天能写进契约的非法值**（新规则的修复面）：`config set TEAM_DEFAULT_MODEL "a b/c" --yes` → rc 0
   （空格进契约，之后渲染进 `--provider a b --model c` 形状）；`config set TEAM_DEFAULT_MODEL p:q/model
   --yes` → rc 0。新规则拒空格（修复）与 provider 段里的 `:`（唯一新增精度，proposal 点名）。
6. **读面本来就容多段**：手改 `TEAM_DEFAULT_MODEL="openrouter/amazon/nova-lite-v1"` 后
   `config list --json` 正常给出 `default` / `known` / `choices`（`source=known`）——红的只是写路径；
   面板 `known[]`/`choices.values` 是纯字符串，选择器只把 owner 命令的错误显示出来（现状如此 ✓）。

## 2. 红侧证据（propose 阶段实测，真命令真输出）

夹具：`mktemp` 下的 git repo + `team init`（私有 `TEAM_*` 环境，退出即删）。

三条写路径 + 后缀 + 精度：

```
$ team config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes
✗ TEAM_DEFAULT_MODEL=openrouter/amazon/nova-lite-v1 不合法：必须形如 provider/model（恰好一个 /）      rc=4
$ team config set-agent-model dev openrouter/amazon/nova-lite-v1 --yes
✗ 模型必须是 provider/model 形状（恰好一个 /）：openrouter/amazon/nova-lite-v1                        rc=4
$ team config set TEAM_AGENT_MODELS dev=openrouter/amazon/nova-lite-v1 --yes
✗ TEAM_AGENT_MODELS=dev=openrouter/amazon/nova-lite-v1 不合法：席位 dev 的模型必须形如 provider/model  rc=4
$ team config set-agent-model dev openrouter/amazon/nova-lite-v1:high --yes
✗ 模型必须是 provider/model 形状（恰好一个 /）：openrouter/amazon/nova-lite-v1:high                   rc=4
$ team config set TEAM_DEFAULT_MODEL kimi-coding/kimi-for-coding:high --yes                           rc=0
$ team config set TEAM_DEFAULT_MODEL "a b/c" --yes                                                    rc=0  ← 空格今天能进契约
$ team config set TEAM_DEFAULT_MODEL p:q/model --yes                                                  rc=0  ← provider 带 : 今天能进
$ team config set TEAM_DEFAULT_MODEL a//b --yes
✗ TEAM_DEFAULT_MODEL=a//b 不合法：必须形如 provider/model（恰好一个 /）                               rc=4
$ team config set-agent-model dev a/b/ --yes
✗ 模型必须是 provider/model 形状（恰好一个 /）：a/b/                                                  rc=4
```

窗口解析（`models.json` 夹具：`openrouter` → `stealth/union-alpha` contextWindow 131072，
`TEAM_PI_AGENT_DIR` 指向它）：

```
3seg-from-pi=[空]           ← openrouter/stealth/union-alpha 从 Pi 目录解析不到
2seg-from-pi=[8192]         ← openrouter/plain-model（对照）
3seg-explicit=[300000]      ← TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000'（该分支本来就对）
```

Pi 侧精确 vs 模糊（设计依据）：

```
$ pi --provider openrouter --model amazon/nova-lite-v1 -p "Reply exactly OK"   → rc 0（精确 id）
$ pi --provider openrouter --model nova-lite-v1         -p "Reply exactly OK"   → rc 0（模糊兜底）
```

## 3. Flip（本任务只 propose，绿侧是 apply 的验收）

- **红 → 绿**（apply 要交付）：上面的三个 rc=4 变成 rc=0、id 原样落盘并在 `config list --json`/
  `team ps` 回读；`3seg-from-pi` 从空变成 Pi 目录里的窗口值；两个 `--print` 渲染器从
  `--model nova-lite-v1` 变成 `--model amazon/nova-lite-v1`。
- **break-it**（apply 的 `flip-shape` 夹具）：把唯一判定放宽成「含 `/` 即过」→ `a//b` 在 model kind、
  pairlist、`set-agent-model` 三路都变绿，`config-cli.sh shape` 在 scratch 树上必须红并点名 `a//b`；
  恢复后绿。
- 证据位置：`tasks.md` §3.1/§3.2 与 proposal 的「Evidence the report must contain」。

## 4. 门禁（交付前在本 tip 上跑）

```
$ export PATH="$HOME/.bun/bin:$PATH"; openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
✓ spec/memory-and-deps / ✓ change/model-id-shape / … / ✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)
（排队等另一套全量 smoke，上限 1800s 后开跑）
== #111 15 · 完成 == 2026-09-28T16:14:45+00:00 · 预算 60s
== 结果 ==  ✓ 3596  ✗ 0
smoke 全绿
```

exit 0（1942s，含排队；`team review` 复验时可对着 `main` 的同一套比对）。原始日志：
`.pi/team/state/bg/p102-gate.log`（本 worktree，state 不入库）。

## 5. 决定与偏差（相对 brief）

- brief 的窗口 premise 修正 + 启动渲染器修复：brief 未列，但它们是「多段 id 真的能用」的同一形状问题
  （proposal/design 都点名，PM 提案复核可否决或收窄）；没有它们，change 会产出假绿（写进去、起不来 / 窗口未知）。
- `provider:suffix/model` 由接受改为拒绝（唯一新增拒绝）：思考档只能挂在 model 段。
- 不改 brief、不改实现代码（propose 边界）、不改 `openspec/specs/**`、不 push；`openspec validate
  --all --strict` 在写完后绿（16/0，含 `change/model-id-shape`）。
- 说明：proposal 的验收命令 `bash skills/teamsmith/tests/config-cli.sh` 现在就能跑（3 秒左右，vacuous 的
  `shape` 选择器不会让整跑变红）；`config-cli.sh shape` 这个**定向**选择器在 apply 写 fixtures 之前是
  0 断言的空跑（exit 0），复核时别把它当绿侧证据。

## 6. 给 PM 的下一步

- 按 `references/openspec.md` §4 的十点清单写 `docs/team/reviews/model-id-shape-proposal.md`。重点看：
  ① 新增的启动渲染器/窗口修复是否在授权范围内（我的建议：在，且必要）；② `provider:...` 这条新增拒绝；
  ③ `tasks.md` 的 6 个路径授权是否照抄进 apply brief。
- 接受后派 apply（不能是本 agent）。apply 交付要求：红/绿矩阵 + `flip-shape` 转录 + 全量门禁摘要。
- 本分支 tip：四件套 `741dbfd1`，本报告与门禁结果在其后的 commit 上（`git log` 看 tip）。
