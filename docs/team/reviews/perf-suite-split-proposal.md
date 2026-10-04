# perf-suite-split · PM proposal review

time: 2026-09-21T09:1x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  perf-suite-split
owner:   dev-bob（propose）
tip:     （见交付分支 task/M57-perf-suite-split）
user:    D33（2026-09-21）「性能相关测试不要放在全量测试里，单独做一个性能的测试，全量测试只测正确性」
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 18 passed, 0 failed
$ git -C .worktrees/dev-bob status --porcelain                   → 0
# delta 完整性：panel「Frame assembly…」base 8 → delta 10，被删 = 无，新增两条见下
```

## Findings

1. **判据划得非常准（D1）— PASS。** 提案先把"什么算性能红线"定义清楚：
   **凡是"对墙钟时长或 CPU 份额设阈值"的断言 = 性能判定**；而**有界存活等待**（条件必须在期限内发生，
   预算是最坏情况的若干倍）与**确定性计数**（如 §37 的 git 调用次数）**不算**，它们留在正确性门禁。
   D1 逐段列了 today → after 的搬迁表，**这条把"拆分"从口号变成了可核对的清单**。
2. **反后门检查留在门禁里，且改成时间无关（D7）— PASS。** 原 `d-realpath`（夹具旋钮不得漏进真路径）
   与"premise 行只反映真读数"**留在正确性门禁**，通过新助手 `tests/panel-knobs.sh` 以 **premise-only** 模式驱赶，
   `smoke.sh` 自己**不再点名任何测量夹具** —— 这正是可机械检查的前提。
3. **搬迁是"移动"不是"复制"，并有双向机械守卫（D6）— PASS（本提案最好的部分）。**
   守卫是纯逻辑、FAST 安全，三条失败条件：
   ① 正确性门禁自己的文件里出现性能判定标记（帧预算常量、CPU 份额比较、或调用测量夹具）；
   ② 反后门助手缺失/丢了 premise-only 调用/反过来驱赶测量夹具；
   ③ `tests/perf.sh` **没有**这些判定标记（"偷懒式搬迁"：删了但没落地）。
   标记是 `perf.sh` 里的**命名单源常量**（`PERF_FRAME_BUDGET_MS=2000`、`PERF_CPU_MAX_PCT=1`、前提系数），
   **双向翻转**（把判定塞回 smoke → 红；从 perf.sh 移除 → 红；还原 → 绿）写进了 apply 报告要求。
4. **入口与默认环境 — PASS。** `skills/teamsmith/tests/perf.sh` 是套件本体，`team perf` 是前门（与 `team smoke` 并列，
   会出现在 `team help`）；**默认在钉死镜像里跑**（`--container`），`--host` 明确打印"不是参考环境"。
   design 给了实测对照（宿主 3445/3413/3415 → 中位 **3415ms**、CPU 0.50%、**RED**）。
5. **性能套件自己带锁（D5）— PASS。** 两次性能测量不得互相测量对方（夹具依赖真 pane 与 CPU 份额）。
6. **CI 两条独立结论 + 发版前记录（D8）— PASS。** 与 D33 的第 4 条一致：性能**不阻塞合并**，
   但**发版前必须跑一次并把数值记进记录**。
7. **不需要新增能力（D0）— PASS。** home 落在既有 `panel` 与 `verification` 两个 capability，符合 D31 的 `1 change : N tasks`。
8. **R6 冻结项明确（D10）— PASS。** 红线数值（2000ms / 1% / 2000ms）与既有语义（`ran/queued`、exit 4 可见跳过、
   CAS 与写入路径）**全都不动**，并在 design 里写明"为什么搬走后的判定不会烂掉"。

## PM 追加的两条硬要求（写进 apply 任务书）

- **A1**：**双向翻转必须真跑**（塞回/移除/还原三次），并把**原始输出**贴进 apply 报告——不接受"我看过"；
- **A2**：`team perf` 在**没有容器镜像**的机器上要**可见降级**（打印"参考环境不可用，本次为宿主判定，结论不作为验收依据"），
  不许静默按宿主结论结案。
