# P224 · P223 的换人独立验证（`--keep` 穿过 re-exec + 现场收集自证）

```
task:   P224
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P223
deltas: -
grant:  docs/team/reports/P224-verify.md · docs/team/reports/P224-verify/**
deps:   被验实现**已并入 main**（`3ec94fb9`）；apply=dev2；你没写过它 —— 合规
status: todo
budget: 小到中
priority: 中高（它管的是"CI 一红能不能拿到现场"；上一版承诺过 `--keep` 却一直空转，正是这条要防的）
```

## 要验什么（**走真入口**，不要只读它的 §40 断言）

1. **决定性影子：把修复拿掉，症状必须回来。** 在 scratch 副本里把"解析后立刻 export `TEAM_TMP_KEEP`"那一行移回锁之后（或删掉），用**真入口**跑一次 `--keep`（私有锁 + 私有 TMPDIR）→ 根**必须**被收走（也就是证明这条修复是承重的，不是白捡的绿）。
2. **两个方向（恢复修复后）**：`--keep` → 根留下且收尾行**点名路径**；去掉 `--keep` → 根不在、也没有那行。
3. **收集器自证三向**（`ci/collect-scene.sh`，自己造暂存目录）：
   - 有现场族 → 打包、逐族列出文件数与字节、把"同前缀但不算现场"的项单独点名；
   - **空**暂存目录 → **非 0 退出**，且把它找过的路径与目录实际内容列出来；
   - 影子：`--min-families 0` → 必须**大声打印**它在关掉自证（不许悄悄放过）。
4. **只收现场族**：往暂存目录里放一个**非**现场前缀的大目录（例如 `other-big/`）与一个自指软链 → 产物里**不许**出现它们（历史上整份 `/tmp` 在**上传侧**撞过 ELOOP）。
5. **工作流接线**（读 `.github/workflows/gates.yml`）：gate 步仍带 `--keep`；收集步用 `GATE_OUTCOME` 决定行为；**gate 成功时不许**因为"没有现场"而红（否则 CI 一绿就挂）。这条要给出你读到的行号与你的判断。
6. **门禁**：`openspec validate --all --strict` + 容器内 §40（含它的 P223 探针）；报告点名"哪些自己跑、哪些没跑"；证据包按 D94 留在工作树。
