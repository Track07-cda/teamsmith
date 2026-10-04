# P105 · 名册写入返工：空白席位名不许改状态、`--model` 的记录必须与配置同源

```
task:   P105
agent:  dev
issue:
change: roster-writer-and-route-truth        # apply 阶段返工（P104 的独立验证判 FAIL，两条 finding 我已自己复现）
specs:  memory-and-deps#（名册的唯一授权写入路径）· dispatch#（用法诚实性）· init-skill#
phase:  apply
anchor: change
deltas: memory-and-deps, dispatch
grant:  skills/teamsmith/scripts/lib/{cmd-agents,cmd-config}.sh · skills/teamsmith/scripts/team · skills/teamsmith/tests/{routes.sh,config-cli.sh,smoke.sh}（append-only）· skills/teamsmith/references/*.md · openspec/changes/roster-writer-and-route-truth/specs/{memory-and-deps,dispatch}/spec.md
deps:   P104（fail 报告 + 验证包在 docs/team/reports/P104-dev-bob/）· P99（你上次的 apply）· main 已前进（P95/P99 已在 main）
status: todo
budget: 一个工作块
priority: **高**（F1 会写脏名册并留 `result=ok` 审计）
```

> 本地模式：不 push。**先 `git merge main`**（smoke.sh 的段号 50/51 已被 P95/P99 占用，你的新段自选且不冲突）。

## F1（高）· 带空白的席位名：**失败的命令改了状态，还谎报成功**

**我的复现原文**（scratch 项目，真名册未动）：

```console
$ team add-agent 'api 1' --register
✗ 未知 agent：api 1（名册：dev verify api 1 ）
$ grep ^TEAM_AGENTS= .pi/team/config.sh
TEAM_AGENTS='dev verify api 1'      # ✗ 名册被写脏（多出 api、1 两个 token）
$ tail -1 .pi/team/state/config.log
2026-09-28T10:28:35Z result=ok actor=cli key=TEAM_AGENTS old='dev verify' new='dev verify api 1'
```

**要做**：
1. 席位名形状必须在**任何写入之前**校验并拒绝：空 · 含空白（空格/**tab**）· 含 `/` · 保留名（`pm`/`verify` 这类按你的口径）· 已在册 → **非零 + 名册字节不变 + 不写 ok 审计**；
2. `teardown` 的 present 判定改成**按 token 精确匹配**（现在 `case " $old " in *" $seat "*)` 会**跨 token** 命中 ✗ —— 这也是 `api 1` 能溜过去的半边；
3. 审计只在**真正成功**时写 `result=ok`；失败/拒绝路径要么不写，要么写明确的结果（不许 ok）；
4. 夹具补齐四种形状 `api 1` · ` api` · `api ` · `api<TAB>1`，每种都断言**三件事**：非零 · 名册字节不变 · 审计里没有 ok 行；
5. 拒绝时给两条**真实**出路（与 `add-agent` 现有的口径一致）。

## F2（中）· `--model` 留下的记录与配置不同源

**我的复现原文**：

```console
$ team add-agent dev --model vendor/m2 --no-install
$ grep ^TEAM_AGENT_MODELS .pi/team/config.sh
TEAM_AGENT_MODELS='dev=vendor/m2'                                   # 配置 ✓ 写对了
$ grep -E '^(model|model_src)=' .pi/team/state/dev.env
model=opencode-go/deepseek-v4.1-flash
model_src=config                                                    # ✗ 写盘前的旧值
$ team config list --json   （席位行）
  dev opencode-go/deepseek-v4.1-flash src=record override=True      # ✗ 显示旧模型，却说自己有 override
```

**要做**：state 记录与配置**同源**（写完要么更新成 `vendor/m2` + `model_src=explicit`，要么就**不记**这个旧值）；
`config list --json` 的席位行必须显示**配置生效**的值；把这条读回做成**真断言**（写入 → 读回 → 断言），
并覆盖"记录里先有旧值"的形状（这正是上一版漏掉它的原因）。

## 通用

- 跑：`tests/routes.sh`（走查）· `tests/config-cli.sh list validate roster` · FAST · `openspec validate --all --strict`；
- 报告里贴**红/绿原始输出**（先证明你的新断言在旧代码上会红）；
- 只动上面 grant 的路径；delta 只在措辞确实需要时改（改则说明为什么）。
