# V44 · 孤儿可见性三项缺口的补齐（夹具读数 / 逐字节臂 / 文档）：独立复验

task: V44
agent: -
phase: verify
category: verify
change: orphan-visibility
specs: seat-visibility
deltas: -
branch: task/V44-orphan-gaps-verify
deps: P285（apply 已并入 main，补三项）；V42（产品面已 PASS，本轮**只验补齐的三项**与「不回退」）

## 复验对象

P285 补的三项（**产品代码未动**：只改夹具 `seat-visibility.sh`、`references/config.md`、`references/troubleshooting.md`）。任务书与留空理由见 `docs/team/reports/P284-dev-bob.md` 的「留空的 3 项」一节；补齐说明见 `docs/team/reports/P285-dev-bob.md`。

## 必须自己做的（不许只复跑作者脚本）

1. **1.1 的 `ps` 读数**：作者用「`ps` 垫片 + 计数」证明普查只 fork 一次 `ps`。**你自己**装一个**你的**垫片（不要用它写的那个），跑一次普查，数调用次数；再**改一处实现**让每个 pid 调一次 `ps`（或让粗筛退化成逐 pid 查询）→ 必须红并点名。若你判断「只调一次」这个判据本身不可证伪，说出为什么。
2. **4.2 的逐字节臂**：自己造现场（关/开普查各跑 `team ps` 与 `team status`），**逐字节**比对**既有每一个块**；再自己造一次变异（把普查内容插进容量行、或插进存活块）→ 必须红并点名。
3. **7.5 的文档与事实对拍**：`references/config.md` 的 `TEAM_ORPHAN_SCAN` 行与**真行为**一致（`=0` 时 `team ps`/`status`/`up` 各打印什么、`team reap --orphans` 是否拒绝、退出码）；`troubleshooting.md` §28 里写的症状与命令（`team reap <pid> --yes`、`TEAM_ORPHAN_WARN_MB`、`team up` 那一行）**逐条真跑一遍**能对上。**不许**只看文字。
4. **不回退**：V42 已验的绿面随机抽 ≥5 条复跑（自造假孤儿、四个假阳性家族、跨项目零点名、只读性质、只按 pid）。
5. 容器纪律：先看 `/tmp` 余量；任何「既有红」同命令对照 **v0.2.0（tag）**。

## 交付

`docs/team/reviews/V44.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc + 证据路径；**你自己写的垫片与变异**的原始输出；写明运行模型）；证据包仓外；不改候选、不合并、不推送；结论按协议通知 PM。
