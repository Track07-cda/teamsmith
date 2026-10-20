# P338 · apply：等待者的耐心跟随持有者心跳（不再有一个没人生产的上限）

task: P338
agent: dev-bob
phase: apply
category: code
change: gate-waiter-patience
specs: verification#A waiter's patience follows the holder's heartbeat, not a budget nobody publishes
anchor: none (infra) — change 自己带 delta
deltas: verification
branch: task/P338-waiter-patience-apply
deps: P329 已并入 main（`6d6b87db`；§34⑦ 里那五条自造 `expected=400` 的算式断言已删）

## 上下文（必须知道的两件事）

1. 提案（P332）已通过独立审阅（`docs/team/reviews/gate-waiter-patience-proposal.md`，审阅记录 `reviews/V68`）。本任务是它的 apply，单独一个 ID（与 P325→P326 同一个规矩）。**照提案实现，不要重新设计方案**；下面只是把裁决口径与验证方式钉死。
2. **今天那条规格 SHALL 没有任何断言**：`openspec/specs/verification/spec.md` 里 `clamp(remaining+60, W, 4W)` 的 `expected` 生产者在 P316 退役，P329 删掉了它唯一的执行证据（V76 的 F1 记录了这个窗口）。**这次变更就是来收这个窗口的**：你的 delta 要把那条 SHALL 换成心跳耐心规则，并附上钉住新规则的断言。

## 行为（提案里的定义，照抄不改）

- **心跳新鲜**（记录里的心跳在 `W` 之内）→ 继续等，硬顶 `4 × TEAM_SMOKE_LOCK_WAIT`。
- **心跳过期**（超过 `W` 没更新）→ 判定持有者卡死，**大声失败并点名持有者**（席位/工作树/已跑时长，沿用既有队列行的形状）。
- **记录里没有心跳字段**（旧记录）→ 行为与今天**逐字相同**（上限就是 `W`）。

## 硬性要求

1. **净零**：删掉上限算式里 `expected` 那条分支与它的生产者路径（今天恒为 0 的死分支），不留「兼容」开关；没有新增监测器、没有第二个等待循环、没有新进程。要新增的东西只有「读心跳、算还等不等」这一段。
2. **判定是纯函数**：把「现在还该不该等 / 该等到哪一刻」做成对 `(记录内容, 现在时刻, W)` 求值的**纯函数**，调用方只管拿它的结果。这是本任务的可验证性关键，理由见下条。
3. **不许用墙钟区间做判据**：`sleep` 两秒再断言「等了至少两秒」这种写法一律不接受（这台机器的负载会让它抖动）。用第 2 条那个纯函数**喂值**证明：
   - 心跳新鲜 → 继续等（返回的上限是 `4W`，不是 `W`）；
   - 心跳刚过期 → 失败并给出「卡死」的理由；
   - 记录无心跳字段 → 上限仍是 `W`；
   - **「每轮重算」而不是「排队时缓存」**：同一份「等待状态」喂两次不同的「现在时刻」（中间让心跳内容更新一次）→ 后一次必须给出**更晚**的截止；再喂一个心跳不再更新的时刻 → 必须判卡死。这一条正是提案里留到实施阶段解决的那个缺口（V68 审阅的 G3），**不许用 elapsed 时间带代替**。
4. 端到端只跑**一条**真实排队路径（沿用 §34b 既有的 stalled 现场形状，不要新建夹具）：心跳新鲜的长跑不被误杀、心跳停跳的持有者被点名。真实路径的读数只作参考，判据是第 3 条那几条喂值断言。
5. 不动 §34b⑨（没有 `expected` → 退回 `W` 那条）与 §34⑥；不动 `team review` 的排队记账；不提高任何时限常量；不改容器门禁任何东西。

## 验收命令

- `bash skills/teamsmith/tests/smoke.sh --select 34,34b`（**逗号**；整段必须全绿，贴段尾与 rc）
- `bash skills/teamsmith/tests/section-select.sh --check`
- `openspec validate --all --strict`（若 `openspec` 不在当前 shell 的 PATH，用 `bash -lc` 形式并说明你用的哪种）
- 账本禁令固定验收行、`git diff --check`
- 不动 `openspec/changes/gate-waiter-patience/` 之外的其他 change 目录

## 交付

报告 `docs/team/reports/P338-dev-bob.md`：先给结论（新规则的四条喂值断言各自成立与否），再给命令与原始尾部；**明确写出旧记录（无心跳）行为与今天逐字相同**的证据。不要跑整套门禁、不要跑容器、不要抢机器级门禁锁（你只需要 §34/§34b）。
