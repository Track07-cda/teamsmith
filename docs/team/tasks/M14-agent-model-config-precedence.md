# M14 · 派单模型解析：配置必须压过名册里的旧记录

```
task:   M14
agent:  dev2
deps:   用户规则"派 dev 优先 k3-256k"（2026-09-16 配置进 TEAM_AGENT_MODELS 但没生效——实测派单仍走 deepseek）
```

## 实测现象（PM 亲手）

`.pi/team/config.sh` 里 `TEAM_AGENT_MODELS="dev=kimi-coding/k3-256k"`，但刚才 `team dispatch dev P14 --fresh`
仍按 deepseek-flash 启动。根因（cmd-agents.sh:554）：`model="${model:-$(team_state_get "$agent" model
"$(team_agent_model "$agent")")}"`——**名册 state 里的旧记录优先级高于配置**，配置改了也没用。

## 要求

1. 优先级改为：`--model` 显式参数 > 配置（TEAM_AGENT_MODELS 的 per-agent > TEAM_DEFAULT_MODEL）> 名册旧记录
   （仅作"上次用了什么"的展示，不作默认来源）。配置的变更必须立即影响下一次派单。
2. 名册里 model 字段继续照常写（展示用），但不再参与解析。
3. 夹具：配置 dev=A 模型 → 派单命令渲染出 A；改配置 dev=B → 下一次渲染出 B（名册里的旧值不影响）；
   `--model C` 显式传参压过两者。
4. `team ps`/roster 的模型列改标来源（配置 / 显式 / 历史记录），别再把旧记录显示得像当前配置。

## 边界

`scripts/lib/cmd-agents.sh`、`scripts/lib/cmd-status.sh`（展示标注）、`tests/smoke.sh`（自己的段）、
references/config.md 一句话。不动账本。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
