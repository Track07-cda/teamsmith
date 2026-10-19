# P316 · 删掉「需要安静机器才能过」的测试（用户裁定，2026-10-19）

task: P316
agent: dev
phase: apply
category: code
change: -
anchor: none (infra) — 门禁口径；用户原话见下
deltas: -
branch: task/P316-delete-load-sensitive-tests
deps: 无

## 用户裁定（原话）

> 「这种需要负载条件才能过的测试直接删掉！不要过度的测试！」

**解释（PM 钉死的判据）**：一条断言如果**只有在机器空闲时才成立**，它就**不是**在测产品，而是在测机器——**删掉**。

## 第一步：先交**清单**，不许先删（照上次门禁瘦身的做法）

对 `skills/teamsmith/tests/**` 全量盘查，产出表：**文件:行 → 断言的原文 → 它判的是什么 → 处置（删 / 改判据 / 保留）**。分三类：

1. **「删」——按墙钟/负载成立的判据**：段落**时间预算与超时停跑**（`section-budgets.tsv` 的 `budget_s`/`band_s` 执行侧、`smoke.sh` 的超时杀段、`section-guard.sh --budget-check` 的时间部分）、任何 `N 秒内…`、`用时 < X`、`refresh_s` 阈值、`2000 ms 帧` 之类的**帧时**断言、`panel-cpu.sh` 这类**CPU 速率**断言、以及为它们服务的夹具分支。
2. **「改判据」——本意是行为，只是借了时间代理**：例如「等它刷新」改成**轮询到某个状态出现**（有上限但不判时长）、「tick 有跑」改成**看 tick 计数/状态文件**。**上限只用来防死等，不许把上限当判据**（超时就报「没等到」而不是「太慢」）。
3. **「保留」——纯行为**：退出码、状态字段、渲染完整、文件内容、逐字节比较、错误文案的**稳定标记**。

**不要**为了绿而放宽行为断言（那是另一回事，会被复验打回）。

## 第二步：按清单删/改

- 删掉第 1 类**及其夹具与表列**（`section-budgets.tsv` 若整列失去意义就整表退役，并在 §0e 的陈述里同步）；
- 第 2 类改成状态轮询（**上限 300 秒防死等**，超时报「没等到 X」并给最后一次状态）；
- **保留判定依据**：哪条断言守护的行为**现在由谁守**（另一条断言 / 退出码 / 状态字段），写进清单。

## 验收（**关键**：必须在**负载高**时也绿）

```bash
# 1) 负载自证：先打印 loadavg（不要求它低——要求它不一定低）
cut -d' ' -f1-3 /proc/loadavg
# 2) 整套 FAST 门禁必须绿（不管当刻 loadavg 是多少）
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 3) 红侧：随机挑 2 条你保留的行为断言，各自造一次破坏 → 必须红并点名
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
报告里必须写：**清单表**、删了多少条断言/多少行、负载读数、两次红线取证。**先交清单等我点头**，不许直接大删。
