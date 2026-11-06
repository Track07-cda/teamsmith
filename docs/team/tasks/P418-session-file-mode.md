---
id: P418
title: 捕获仍在多数项目里不注册：Pi 的会话文件是 664，被 regular() 判成「不安全」
agent: dev2
category: code
phase: apply
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P418-session-file-mode
---

# P418 · 0.4.1 之后 <other-project> 仍然捕获不了

## 现场（PM 在活的 PM 进程上复算，不是推测）

<other-project>（0.4.1、`team up` 重启过）里回复正文仍带着 `[[team-reply]]`、pulse 上没有对应条目、`.pi/team/state/reply-capture/` 不存在。

用同一份 `resolvePMIdentity` 对它那个 PM 进程的真实 env/context 复算：

```
REFUSED: unsafe regular file
```

定位到 `reply-capture.mjs` 的 `regular()`：要求 `nlink === 1` 且 `(mode & 0o022) === 0`。而它校验的 `context.sessionFile` 是 **Pi 自己写的会话文件**：

```
-rw-rw-r-- <user> <user>  2026-10-27T01-50-31-807Z_01a17b0d….jsonl
```

664（组可写）→ 判不安全 → 整个捕获不注册。旧的会话文件都是 664（现在的 umask 是 022，新文件才是 644），所以**任何续用旧会话的 PM 都捕获不到**，pm-skills 自己也一样。

## 判据该怎么改（2026-11-05 修订：不做权限位分析）

用户质疑威胁模型，PM 同意：单用户、组即本人，"别人会换掉我的文件"没有对象。真正的事故来源只有身份读错、并发写、崩溃写半个。按下面改，**不要**实现"他人可写/组可写/sticky"那类 mode 分析。

## 原判据（存档）

`regular()` 现在把两件事混在一起：**我们自己要写的状态文件**必须独占（`nlink===1`、无组/他人可写），而**只读的外部文件**（Pi 的会话、配置）只需要「我信得过这个路径」。分开：

1. 新增一个只读校验（例如 `readableForeign(path)`）：普通文件、不是符号链接、**他人不可写**、`gid` 属于本进程有效组（沿用 P415 的 own-group 语义），`nlink` 不限制。会话文件、配置这类只读面用它。
2. `regular()` 保持原样，只用于我们自己创建/写入的文件（journal、runtime、lock、temp）。
3. **不要**放宽到「他人可写也接受」：写别人的文件仍然拒绝。

## 红侧（每条都要能红）

- 会话文件 664（自己的组）→ 必须接受注册（本机现状）；
- 会话文件 666（他人可写）→ 必须拒绝并点名文件；
- 把 `readableForeign` 换成旧的 `regular()` → 第一条必须变红；
- 我们自己的 runtime.json 改成组可写 → 仍必须拒绝（这条不能因为本次改动松掉）。

## 验收（选段，不跑全量）

- `node skills/teamsmith/tests/reply-capture.mjs --all`（含你新加的用例）
- `bash skills/teamsmith/tests/key-replies.sh --select workflow`
- 真实流程：在 <other-project> 那样「续用旧会话」的形状下（会话文件 664）起一份捕获，`runtime.json` 必须写出来
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P418-dev2.md`，提交推分支，通知 PM。**目标 1 小时内**。

## 边界

只改 `scripts/reply-capture.mjs` 与其测试。不改 Pi 的会话文件权限、不改 P415 刚落地的目录判据语义、不改发布流程。
