---
id: P399
title: 关键回复隔离守卫只比对会被污染的数据，不比对运行遥测
agent: dev2
category: code
phase: apply
change: -
specs: -
anchor: none (infra) — 修的是测试夹具的假红，不改任何产品契约
---

# P399 · 隔离守卫的比对范围（fixture 假红）

## 现象与证据（PM 实测，不是推测）

在已合入 P381/P380/P382 的 main 上跑 `bash skills/teamsmith/tests/key-replies-pty.sh --select mouse`，两次都是：

```
✗ 隔离守卫：真实仓库被改动了！inbox 4a97…（未变）｜ state a450… → 32e8…
== P234 key-replies-pty 结果 == ✓22 ✗1 SKIP0
```

`skills/teamsmith/tests/key-replies.sh:100-112` 的 `kr_tree_hash` 对 `.pi/team/state` **整棵树**取 sha256。而 Pulse 正在运行，任何 `team` 调用与信号都会往真实项目的 `.pi/team/state` 追加遥测：`signal-calls.log`、`tmux-calls.log`、`watchdog.last`、`watchdog.tick.log`、`capacity.log`、`inbox-watch/*.reg`、`_watch.env`（`find .pi/team/state -newermt '-20 minutes'` 实测这些文件在动）。

结论：在**活着的项目**上这条守卫永远红，与关键回复无关。它是在 Pulse 停着的时候通过的（P383 复验当时 Pulse 已停），所以过去是绿的。

## 要做的（窄）

把守卫的比对范围改成「夹具可能污染的产品数据」，而不是整棵树：

1. **继续逐字节比对**：编号回复存储（`TEAM_REPLY_*` 指向的真实存储）、`docs/team/inbox/`。这两处是 P388 事故的同族目标，必须保住。
2. **排除运行遥测**：`signal-calls.log*`、`tmux-calls.log`、`watchdog.*`、`capacity.log`、`inbox-watch/*.reg`、`_watch.env`，每一类在代码里写明「为什么它由本系统的正常运行写入，不是夹具泄漏」。
3. **排除必须显式列举，不能变成「全部忽略」**：除这些名字以外的任何新增文件或内容变化仍然要红。允许用「已知可变集合 + 其余全比」的写法，但空集合必须退化成现在的全比行为。
4. **负对照必须留下**：仓库里已有 26-l 型自检（故意泄漏会被抓到）。新增/保留一条具名断言，证明「往真实存储写一个字节 → 守卫变红」，并证明「只有遥测在动 → 守卫保持绿」。

## 不许做的

- 不许把守卫删掉、不许把 `bad` 降级成 `ok`、不许加 `|| true`、不许用 `sleep` 掩盖时序。
- 不许改 Pulse 的遥测写入（那是产品行为）。
- 不许把 `key-replies-pty.sh --select mouse` 的 25 秒上限、逐轮进度、耗尽归因（P383 刚落地）动一下。

## 验收（必须真跑，贴输出）

1. `bash skills/teamsmith/tests/key-replies-pty.sh --select mouse` 在 Pulse 运行、真实项目有遥测写入的情况下 **✓23 ✗0 SKIP0**。
2. 造一个受控写入（脚本里临时往真实回复存储或 inbox 写一行，再删掉）时，守卫 **必须变红**，贴出那条红。
3. 把那行写入去掉，再跑一次，恢复全绿。
4. `openspec validate --all --strict`；`bash skills/teamsmith/tests/section-select.sh --check`；`bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt`；`git diff --check`。
5. 报告写清：改前为什么必然红（贴 PM 的两次红）、改后为什么仍然能抓住泄漏（贴负对照红）。

不要跑全量 smoke。跑完写 `docs/team/reports/P399-dev2.md`，提交推分支，通知 PM。
