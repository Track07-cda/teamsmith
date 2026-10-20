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

## 返修（V78 判 PASS 但点了五处；一次收完，不重开验收）

V78（`docs/team/reports/V78-verify.md`）确认规则与喂值验证都成立，但它点出五处要我处理的东西。**只做这五件**：

1. **`cmd-review.sh:1101` 的三个死 `local`**（`cap_remaining cap_expected cap_started`）删掉；同一次改动新增的三个变量（`lock_pat` / `lock_silent` / `lock_hb`）**补 `local`**；其中从不被读取的那个（V78 点名 `lock_hb`）直接去掉，不要留一个没人读的变量。
2. **`smoke.sh:572` 与 `:650` 两处注释**仍写「expected=0，cap 退回 W」——那句描述的上限算式已经不存在了，改成现在的口径（心跳耐心；旧记录退回 `W`）。
3. **补两条断言**（V78 在 C 里找不到对应行）：① delta 明写「`heartbeat=-` 的记录 → 上限 `W`」，而 `⑨b` 只有「没有该字段」与「文件不在」两个现场，缺 `heartbeat=-` 这一个；② delta 明写失败行要说「心跳是停了还是从未公布过」，而 `none` 那一支的说明文字**全树没有断言**。
4. **delta 比测试薄的一处要补回去**：delta 把「失败行点名 `kind`/席位/工作树/已跑时长/`expected`」整段删掉了，而 `§34b⑦` 仍在断言这批字段——**规格不该比它的测试薄**。把那段要求加回 delta（只加这一条，别的不要动）。
5. **分支表的冗余**：V78 判 15 条里 4 条没有独立判别力（同一判断换数字重写）。按既有纪律处理：合并或删掉，每条写清「原文 → 处置 → 谁接管」，删掉的要说明它原来的判别力现在由哪一条覆盖。**不许**为了凑数保留。

改完只跑 `--select 34,34b`（贴段尾与 rc）+ 轻量收口，不跑整套/容器。冻结后由 V78 同一席位做第二轮定点复看（只看这五处差异）。
