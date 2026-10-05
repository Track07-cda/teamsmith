# P223 · CI 的失败现场要真的带得出来（现在工件里只有一个锁文件）

```
task:   P223
agent:  dev2
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改 CI 的现场收集与其自证
deltas: -
grant:  .github/workflows/gates.yml · ci/** · skills/teamsmith/tests/**（若必须动 smoke 的现场目录逻辑，先在报告里说明为什么） · docs/team/reports/P223-dev2.md · docs/team/reports/P223-dev2/**
deps:   P214 的观察：失败 run 的 `gate-failure-scene` 工件里**只有**一份 285 字节的 `teamsmith-smoke.lock.tgz`，
        `m28-lint.log` / `p159-lint.log` / `p55-roster.log` / 整个 `teamsmith-smoke.*` 根**都不在**（工件清单在 P214 的证据里）
status: todo
budget: 小到中
priority: 中高（CI 一红就得靠人肉复现；现场带不出来等于每次红都从头查一遍 —— 今天我们已经吃了一次）
```

## 背景

CI 红了两次，两次都没拿到现场。P214 给了两个候选机制但没定论：① 收集步去容器 `/tmp` 拿时，容器已经停了；② smoke 根的清理时机与收集步错开。**你要把它定下来**，而不是再猜。

## 要做的

1. **在本地复刻 CI 路径**（这是唯一可接受的判据）：按 `ci/Containerfile` 构建镜像 → 用**非 `--rm`** 的容器跑一次门禁（`--name` 固定名）→ 故意造一个红 → 跑收集步 → 看 `.ci-artifacts` 里到底有什么。**先复现"只有锁文件"这个症状**，再改。
2. **修到现场真的在里面**：无论根因是①还是②，修法都要能通过第 1 项的复刻验证（例如把收集做成"容器还在时先 `docker cp` 到宿主暂存目录"，或在 smoke 侧提供一个"失败时把现场族**复制**到约定位置"的接口——由你判断哪个更稳，但要在报告里写清为什么）。
3. **自证（不许再出现"上传成功但 0 个有效文件"）**：收集步要**检查并打印**它找到的现场族与文件数；**低于阈值就让这一步红**（例如：一个现场族都没有 → 红并打印它找过的路径）。这条自证要有影子：把阈值改成 0 或把复制关掉 → 第 1 项必须红。
4. **不许扩大收集面**：只收**现场族**（`teamsmith-smoke.*`、`m28-lint.log`、`p159-lint.log`、`p55-roster.log` 这类），**不要**整份 `/tmp`（历史上整份 `/tmp` 的 `docker cp` 撞过 `ELOOP`，因为里面有自指的 HOME 缓存软链）。
5. **门禁**：`openspec validate --all --strict` + 容器内跑你改动到的东西；报告点名"哪些自己跑、哪些没跑"；**换人复验**。
