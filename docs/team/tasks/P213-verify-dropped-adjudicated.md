# P213 · P211 的换人独立验证（看板裁决 dropped 不再算待复验）

```
task:   P213
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P211 的行为
deltas: -
grant:  docs/team/reports/P213-verify.md · docs/team/reports/P213-verify/**
deps:   被验实现 **已并入 main**（790112dd）；apply=dev（P211）；**你没写过它** —— 合规
status: todo
budget: 小
priority: 中（这条修的是"假待办"，判错会让巡逻继续每小时叫醒 PM，或反过来把真待办吞掉）
```

## 要验什么（自己造现场，不许复用 P211 的夹具或断言）

1. **同一环境对换法**（判据必须能区分"修好了"与"环境本来就不报"）：
   在**你自己的** scratch 项目里造三样东西——一份报告 `reports/T1-verify.md`、一条看板行 `T1`（状态 `dropped`）、一份 `reviews/T1.md`（或没有）——
   然后**只换一个文件**（`scripts/lib/cmd-status.sh` 的 main 版 vs 被验版）跑 `team digest`：main 版必须**列出**它（假待办），被验版必须**不列**且**点名**"已按看板跳过（…dropped）"。
   **注意**：你的现场必须让 main 版**真的报**——报不出来说明现场造得不对（P211 那次我第一版在纯克隆里就复现不出，因为分支不存在导致走了另一条路径）。
2. **不误吞**：同一条报告，看板行改成 `wip` → 两版都**必须列出**（这条是"别把真待办一起吞掉"的对照）。
3. **三处判据点一致**：`done` / `closed` / `dropped` 三种裁决都要走过（清单不列 + 跳过行点名 + `status` 的说明），且**被丢弃**时不许指一份不存在的 `reviews/<ID>-done.md`。
4. **影子（至少两条）**：① 把 `dropped` 从集合里去掉 → ① 必须红；② 把集合放大到 `wip` → ② 必须红（吞掉真待办要被抓住）。
5. **门禁**：`openspec validate --all --strict` + 容器内相关段 + 报告点名"哪些自己跑、哪些引用"；证据包放 `docs/team/reports/P213-verify/`。
