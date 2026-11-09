---
id: P437
title: 关键回复内部诊断不得出现在 Pi 会话输出
agent: dev
category: code
phase: apply
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P437-reply-diagnostics-ui
---

# P437 · 终端诊断泄漏修复

## 真实现场

data_ontology 的 PM 会话显示：

`[team-reply] recover-skip:ineligible; source=unbound; evidence=…/reply-capture/….json`

`team-reply.ts` 的 `diagnostic()` 同时 `process.stderr.write(line)` 和追加 `diagnostics.log`。Pi 会把扩展 stderr 显示在 TUI 中，导致内部恢复状态成为用户可见输出。这是我们的扩展问题，不是 Pi 缺陷。

截图时该回复仍在 `Working`，尚未 settled；本任务**不改变 message_end/turn_end/settled 的发布资格或时机**。

## 要做的最小修复

1. 常规捕获/恢复诊断只写 `.pi/team/state/reply-capture/diagnostics.log`，不向 Pi 的 stderr/stdout 写，不在用户会话中显示内部路径或状态。
2. 保留文件诊断用于排查，不改发布资格、恢复状态机、正文清理、writer 或存储。
3. 不新增“屏蔽某些字符串”的显示过滤；从扩展输出源头停止写入。
4. 检查同一扩展是否还有同类常规诊断直写终端；真正导致扩展不可用的错误仍由 doctor/runtime 证据呈现，不用刷屏代替状态。

## 验收

- 现有 reply-capture 相关测试与关键回复 workflow 选段；
- 增加/调整行为断言：触发 `recover-skip:ineligible` 时，诊断文件有记录，终端输出没有 `[team-reply]`；反向恢复 stderr 写入必须红；
- 用本仓库的 `live-capture-probe.sh` 或等价的私有真实 Pi 探针证明：标记清理与发布后保存仍工作，终端帧无内部诊断。不能用发布新版本到别的项目来测试；
- `bash -n`/TS 构建、结构检查、账本禁令、`git diff --check`；不跑全量/夜间/61b。

## 交付与边界

只改扩展诊断与对应测试/文档，报告 `docs/team/reports/P437-dev.md`，提交本地分支并通知 PM。之后由非作者复验；不合并、不发布。
