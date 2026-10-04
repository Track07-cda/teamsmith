# P122 · `tmp-hygiene --sweep` 的三个可用性/正确性缺陷（今天真挡了用户的清理）

```
task:   P122
agent:  dev-bob
issue:
change: -                        # 无 change：既有工具的行为修复（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改 `tests/tmp-hygiene.sh` 的候选判定与输出，不改清扫判据的安全要求
deltas: -
grant:  skills/teamsmith/tests/tmp-hygiene.sh · skills/teamsmith/tests/smoke.sh（append-only 一段）· skills/teamsmith/references/troubleshooting.md（需要时一句）· docs/team/reports/P122-dev-bob.md · docs/team/reports/P122-dev-bob/**
deps:   P53/P60（本工具与它的验证）· 今日现场（2026-09-29 用户要求清理 /tmp，97% 满）
status: todo
budget: 一个工作块
priority: 中高（直接挡了"清理 /tmp"这个真实操作）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。

## 现场（PM 今天实测，逐条可复现）

1. **把别的项目的 `review-*` 当成我们的** ✗✗：`--status` 的清单里包含 `/tmp/review-M7.35`（884M）、
   `/tmp/review-M7.36`、`/tmp/review-M8.2`（879M）—— 它们的 `.git` **指向 `<peer-project>`** ✗（PM 已读证 ✓）；
   其中 `review-M8.2` 的 mtime 是**今天** ✓（很可能在用 ✓）。→ 判定「是不是我们的」目前只靠**名字前缀** ✗。
2. **一处拒绝 → 一个都不删** ✗：114 个合格候选（2.3 GB）被 **2 个** review 拒绝项**全部阻塞** ✗
   （PM 实测：`拒绝：有 2 个候选的安全前提不成立 —— 一个都没删`，rc=3 ✓）。
3. **拒绝不点名** ✗：那句消息**没有列出**是哪两个候选、为什么 ✗（PM 只能自己读源码才找到原因 ✓）。

## 要做

1. **"是不是我们的"要有证** ✓：`review-*` 这类**按名字**判定的候选，必须**再加一条证明**才能进清单 ——
   至少二选一（写成哪种都行，但要有反例）：① 该 ID 在**本项目的**看板/`docs/team/reviews/` 里有记录 ✓；
   ② 目录里能读到**本仓库**的痕迹（如 `.git`/`gitdir` 指向本仓库、或本仓库的 `skills/teamsmith/` 结构 ✓）。
   —— **并**在台账（`.teamsmith-tmp-ledger.*`）里**记录仓库身份**（例如仓库绝对路径或它的哈希 ✓），
   让"归属"从此**可证** ✓（别只靠前缀 ✗）。
2. **拒绝不阻塞** ✓：安全前提不成立的候选 → **跳过并点名**（路径 + 原因 ✓），**其余照常回收** ✓；
   退出码语义写清：**做了事但有跳过** → 0（并把跳过逐条列出 ✓）；**一个都没做** → 3 ✓。
3. **可见性**（D57 缺口 A ✓）：`--status` 增一行 tmux 侧残留的**计数** ✓（(i) 孤儿私有 server（socket 目录已消失 ✗）、
   (ii) 共享 socket 目录里的**陈旧 socket**（判据：`ss -xl` 无监听 ✓ + 非 `default` ✓ + 年龄下限 ✓））；
   **清扫默认不动** ✓，给一个**显式开关** ✓（例如 `--tmux-sockets` ✓）；**绝不动 `default`** ✓。
4. **证据**：两个方向各一次（(a) 造一个"别项目的 `review-*`"影子 → 它**不进清单** ✓；
   (b) 造一个"我们自己的、且安全前提不成立"的候选 → **其余候选照常回收**且它被点名 ✓）+ 红侧 ✓；FAST 全绿 + `openspec validate` ✓。

---

## 复验返工（2026-09-29 PM，细节见 `docs/team/threads/dev-bob.md`）

- **F1（严重）**：`--sweep` 计划把 **<peer-project> 的** `/tmp/review-M8.1`、`/tmp/review-M8.2` 标成 `[reclaim]` ✗
  （它们的 `.git` gitdir 指向 <peer-project> ✓；只因我们 `docs/team/reviews/` 里有同名 `M8.1.md`/`M8.2.md` 才被当成"记录可回收" ✗）。
  → 归属必须**读 git 痕迹**：指向别的仓库 → 拒并点名 ✓；证据不足 → 拒 ✓。
- **F2**：拒绝/young/occupied **仍然阻塞全部** ✗（真 /tmp：8 个可回收 1.7 GB → 实删 0 ✓，rc=3 ✓）。
  → **跳过并点名**，其余照常回收 ✓；**做事了但有跳过 → 0** ✓ / 一个都没做 → 3 ✓。
- **证据要求**：(a) 影子"真 ID + 指向别仓库" → 被拒 ✓；(b) 1 个拒绝 + ≥2 个合格 → **合格的真被删** ✓（别只验计划 ✗）。
