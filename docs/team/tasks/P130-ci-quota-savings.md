# P130 · CI 结构性省额度（paths-ignore + 只构建一次镜像）

```
task:   P130
agent:  dev
issue:
change: -                        # 无 change：CI 触发条件与作业拓扑（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改 `.github/workflows/gates.yml` 的触发条件与镜像构建次数，不改任何产品行为与门禁语义
deltas: -
grant:  .github/workflows/gates.yml · ci/**（若确有必要）· docs/team/reports/P130-dev.md · docs/team/reports/P130-dev/**
deps:   D54（**CI 不是接受判据**，接受判据 = 本地门禁 ✓；push 带 `[skip ci]` ✓）· 现场：2026-09-29 我 ~30 次 push → 每次全量 CI + **两个作业各构建一次镜像** → 账号额度烧光 ✗（之后作业 2–3 秒零步骤失败、无日志 ✓ = 账号层 ✗ 不是工作流 ✗）
status: todo
budget: 一个工作块
priority: 中高（用户点名 ✓；直接影响额度 ✓）
```

> **不要为了验证本任务去触发 CI** ✓（那正是要省的 ✓）：用**静态证明**（YAML 解析 ✓ + 触发矩阵推理 ✓）交付 ✓；
> 下一次真实 CI 自然会体现 ✓。**也不要把 CI 变回判据** ✗（D54 ✓）。

## A · `paths-ignore`（纯文档 push 不再触发）

- 目标：**纯文档/账本**改动不触发 CI ✓（至少 `docs/**` ✓）；
- **必须仍然触发** ✗：`skills/**`、`openspec/**`、`ci/**`、`.github/**`、根目录脚本等 ✓ ——
  用**反例**证明 ✓（例如"改 `skills/teamsmith/scripts/team` 时工作流**必须**触发" ✓、
  "改 `docs/team/BOARD.md` 时不触发" ✓，逐条给出**判定依据** ✓）。

## B · 两个 gate 作业**只构建一次镜像**

两条路，**你选一条并给理由** ✓（成本/失效模式都要写 ✓）：
- **① 合并成一个作业** ✓：perf 作为 `continue-on-error` 的步骤 → **仍然不阻塞** ✓（这是它当初独立的唯一理由 ✓；**不许**把它变成硬门 ✗）；
- **② 保留两个作业 + GHCR 缓存镜像** ✓（需要 registry 与权限 ✓ 成本更高 ✓ 若选它，写清认证与失效回退 ✓）。

**不变项**：正确性作业仍是**硬门** ✓（失败即红 ✓）；perf 失败**不阻塞合并** ✓（给出你的证明方式 ✓，例如静态推理 + `continue-on-error` 语义 ✓ 或模拟步骤 ✓）。

## 证据

1. **触发矩阵表**（≥6 行：改动路径 → 触发/不触发 ✓ 含 ≥3 条"必须触发"的反例 ✓）；
2. **作业拓扑**：一次运行里镜像**构建 1 次** ✓（画出来 ✓）；
3. **perf 非阻塞**的证明 ✓；
4. YAML 可解析 ✓（`python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' .github/workflows/gates.yml` 或等价 ✓）；
5. 本地门禁**不受影响** ✓（**不动** `smoke.sh` / `openspec` / `config.sh` ✓）。
