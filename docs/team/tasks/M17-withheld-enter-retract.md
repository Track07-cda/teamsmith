# M17 · 打字后没按 Enter 的兜底：不许把自动消息留在用户输入框里

```
task:   M17
agent:  dev2
deps:   用户实测（2026-09-17）：一条 [auto] 消息被自动打进 PM 输入框但没发送，用户手动按了 Enter 才发出去
```

## 实测现象与推断机制（PM 复盘）

守卫判定框空 → 打字 → 按 Enter 前的指纹复检没确认"框里只有我们这段"（最可能是撞上折叠占位符的
渲染中间帧，或那一瞬我这边 UI 自己重绘）→ 按设计**放弃按 Enter** → 条目进 held/（有持久副本）。
安全语义是对的（没把混合内容发出去），但**打进去的字留在了用户的框里**——这就是用户看到的形状。

## 要求

1. **放弃按 Enter 时的收回纪律**：复检失败且框里仍**逐字只有我们的 payload** → 清掉我们打进去的内容
   （全选删除这个状态是安全的），条目进 held/；复检发现**混入**了人的字 → 一个字都不碰
   （宁留不删），条目进 held/ 且日志写明"框里已有人的内容，未动"。
2. 夹具三种形状：① 复检撞中间帧（可复现的半占位符）→ 收回 + held；② 打字后用户抢打 → 不动 + held；
   ③ 正常路径不受影响（仍然 Enter 发出）。
3. held 条目在 digest 与面板的可见性里带"留在框里/已收回"的区分（现在只有 held 一态，人不知道框里
   有没有残留）。
4. 翻转证据：破坏收回逻辑 → 夹具 ① 红。

## 边界

`scripts/lib/outbox.sh`、相关夹具、`tests/smoke.sh`（自己的段）、references/troubleshooting.md 一节。
不动账本。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
