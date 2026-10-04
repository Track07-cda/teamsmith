# P12 · Apply: `pulse-console` 批 1——数据装配异步化 + 缓存化（D26 前置）

```
task:   P12
agent:  dev
phase:  apply
change: pulse-console
deps:   P11 提案 ACCEPTED（docs/team/reviews/pulse-console-proposal.md）；E6 实测数字（D26）
```

## 范围（tasks.md 的 B1 全段，0–1.6）

先做 **0.1 的"改前实测"**（计时 + 按键失真夹具的红日志贴进报告，缺了直接打回不看代码），再做异步核心
（spawnSync → 每区块独立构建写缓存、渲染只读缓存）、区块隔离（坏源显示 `—`）、读者合并（装配 ≤2s）、
按键夹具（5 秒慢读者 + pty 打字，翻转证据两侧日志）、CPU 红线 60 秒采样 <1%、26-a…26-n 回归不动。

## 路径授权（OWNERSHIP）

`skills/teamsmith/scripts/panel/**`、`scripts/lib/cmd-watch.sh`、`references/config.md`（本批显式授予）、
`tests/smoke.sh` 与 `tests/`（你自有）。不碰 `openspec/specs/**`、`docs/team/**` 账本、不归档、不 push。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
