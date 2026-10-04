# console-project-settings · PM proposal review

time: 2026-09-20T01:5x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  console-project-settings
owner:   dev-bob（propose）
tip:     48ad664（首轮）→ 0a9871c（返工后，见文末复审；裁决以该 tip 为准）
```

## Commands run (real output)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
  → Totals: 15 passed, 0 failed (15 items)   # exit 0
$ grep -cE "AGENT_MODELS" openspec/changes/console-project-settings/specs/panel/spec.md
  → 0
```

## Findings

1. **类规则与表（brief 问题 1）— PASS。** 「谁在什么时候读这个值」定类（`apply`/`restart`/`refuse`），
   `refuse` 的理由是「控制台不得扩大自己的权限、不得搬走它正在读的账本」——判据清楚、可复核；
   完整性是测试（schema ↔ `templates/config.sh.tmpl` ↔ `references/config.md`）而不是承诺。
   `plain` vs `export` 的区分（实测 `TEAM_MONITOR_ACTIVITY` 那个坑）是真发现。
2. **写入安全（问题 2）— PASS，且价值超出本需求。** 实测既有 writer 的五个缺陷里有一个是安全级：
   值含 `'$(touch PWNED)'` 时**被 source 就执行**；design 决定「加固唯一的底层写入口」而不是另写一个，
   bootstrap/`team init` 一并受益。CAS 指纹、原子写 + `bash -n` 复核、按值类型决定的引号形式、
   危险值清单、每次尝试一行审计——都落到 requirement 里了。
3. **交互（问题 3）— PASS。** 并入设置浮层 + 一行导航；键位沿用 P20 的编辑键位。
4. **生效与只读例外（问题 4）— PASS。** 决定「只显示不执行」（不在面板里重启脉冲：控制台自己就是那个被重启
   的进程），例外清单从「三个命令」改成「其所属命令」并**逐个列出**——方向正确。
5. **审计（问题 5）— PASS。**
6. **Agent 模型配置（用户 01:1x 的追加要求）— MISSING。** 见下「Required changes」。

## Required changes (NEEDS-CHANGES)

owner: dev-bob（propose 阶段内改，改完我复审）

1. **按席位编辑模型的独立入口缺失。** 任务书追加节要求：在编辑 `TEAM_AGENT_MODELS` 那一行之外，
   有「选席位 → 选模型 → 写回配置」的入口（并列进 delta 的 requirement/scenario）。
   证据：`specs/panel/spec.md` 里 `AGENT_MODELS` 出现 **0 次**；报告只在讲「一行文本按 `agent=model` 校验」。
2. **模型来源三态必须显示。** 展示某席位当前模型时必须标出来源：`配置` / `显式`（上次派单 `--model`）/
   `历史记录`（配置改过但还没重新派单）——即 `team_agent_model_src` 的语义。裸模型名会误导 PM。
   这一条同样要进 requirement + scenario。
3. **缺三条 scenario**（可证伪）：
   - 改 `TEAM_AGENT_MODELS` 后，**运行中的席位模型不变**，下一次 `dispatch`/`resume` 才生效；
   - 来源三态正确（构造「配置与记录不一致」的现场 → 显示 `历史记录`）；
   - `TEAM_AGENTS`（名册）是 `refuse` 类，控制台**写不动**它（负向 scenario）。
4. **`TEAM_AGENT_MODELS` 的值类型要校验席位名**：`agent=provider/model` 里未知席位（拼错的 `dev4=`）
   不得静默生效——要么拒绝，要么给出醒目警告；写进 `kind` 校验与 scenario。

其余部分（类表、加固 writer、CAS、审计、只读例外）**不必改**，按现状进入 apply 即可。


---

## 复审（2026-09-20T02:0x，tip `0a9871c`）：**ACCEPTED**

四条 required changes 逐条复核（我在 checkout 里自查，不采信报告结论）：

| 要求 | 结果 | 证据 |
|---|---|---|
| ① 按席位编辑模型入口 | 有 | `team config set-agent-model <seat> <model|->` + seats 块逐行编辑（panel spec 150 起） |
| ② 来源三态 | 有 | scenario「The source tri-state matches `team ps`」（`历史记录` 与 `team ps` 同一口径） |
| ③ 三条 scenario | 有 | 「A running seat keeps its model and the next spawn uses the new one」/ 三态 / 「An unknown seat or a shapeless model is refused」；`TEAM_SESSION`、`TEAM_AGENTS` 的 refuse 有 scenario（panel spec 43 起） |
| ④ 未知席位校验 | 有 | 拒绝并点名接受形状与名册；`seats` 覆盖每个名册席位（memory-and-deps 168） |

`openspec validate --all --strict` → 15/15。其余部分（类表、加固 writer、CAS、审计、只读例外）保持原样。

**结论**：提案放行，可派 apply。
