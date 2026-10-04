# P13 · Apply: `pulse-console` 批 2——消息入口与三个动作

```
task:   P13
agent:  dev
phase:  apply
change: pulse-console
deps:   B1 已合并（数据层异步化；一帧 ~1s、不阻塞输入）；P11 提案 ACCEPTED
```

## 范围（tasks.md 的 B2 全段）

`m` 底部输入行（中文宽字符光标、按码点退格）；草稿持久化 `state/draft.md`（Esc 保留、重开带出、
`\r` 归一）；`C-e` 编辑器接力（挂起期间渲染回调显式门控）；Enter 经 outbox 守卫发送，三态诚实回执
（已送达 / 已入队·PM 在打字 / 滞留·副本在 held/）；`f` 冲刷 = 调 `team outbox flush`（面板仍只读队列，
冲刷动作委托 CLI）；`s` 待命开关（开时要一行理由，复用输入行）；写信期间输入区暂停刷新、其余区照刷。

## 验收（每条带能跑挂它的命令，pty 夹具照 E6 的脚本搬）

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# + B2 段的 pty 夹具：中文光标列、草稿存活于刷新、编辑器接力无损、回执三态、暂停刷新
```

## 边界

`scripts/panel/**`、`scripts/lib/cmd-watch.sh`、`tests/**`（你自有）、references/config.md（新 state 文件登记）、
`openspec/changes/pulse-console/**`（勾 tasks）、你的报告。不动 specs/、账本，不归档、不 push。
