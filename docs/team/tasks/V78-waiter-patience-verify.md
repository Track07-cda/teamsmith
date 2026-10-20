# V78 · P338 的独立验收：耐心跟随心跳，且没用墙钟

task: V78
agent: verify
phase: verify
category: verify
change: gate-waiter-patience
specs: verification#A waiter's patience follows the holder's heartbeat, not a budget nobody publishes
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V78-waiter-patience-verify

## 受检

候选 `c9869dc8`（实现 `4f11ede7`），报告 `docs/team/reports/P338-dev-bob.md`。改动：`gate-lock.sh`（删 `gate_lock_cap`/`gate_lock_cap_pair`，新增 `gate_lock_path_mtime`/`gate_lock_heartbeat_newest`/`gate_lock_patience`/`gate_lock_patience_note`）、`smoke.sh`（§34b 新增断言）、以及 `cmd-review.sh`、`perf.sh`、`references/protocol.md`、`loop-inventory.tsv` 一行。

## 要回答的四件事

**A（规则对不对、能不能喂值验证）**：`gate_lock_patience <lock> <W>` 是不是真的纯函数（时间只从 `gate_lock_now` 来、不看墙钟）？**自己写**四条喂值断言（不要抄作者的）：心跳新鲜 → 上限 `4W`；心跳过期（含 `silent == W` 这一侧）→ 判卡死、上限 `W`；记录无心跳字段 → 上限 `W`；同一份等待状态在心跳更新后给出**更晚**的截止（这就是「每轮重算 vs 排队时缓存」的 G3）。用自己的夹具、钉住 `now`、用绝对 mtime。

**B（旧记录行为逐字未变）**：在 `main` 与候选上各跑同一现场（无 `heartbeat=` 字段 / `heartbeat=-` / 公布的文件不在），三个读数必须逐个相同——这是「今天已有的行为不许被我改坏」的承重对照。

**C（README 级的诚实性）**：交付前我明确要求 delta 把那条「上限按 `expected` 算」的 SHALL 换掉并附断言（P329 删掉了它唯一的证据，见 `reviews/P329.md` 的 F1）。作者说 delta 在提案阶段已经是心跳口径、一字未改。**请逐条核对** delta 里每一条要求都能在候选的断言里找到对应行；找不到的就点名。

**D（写集扩大是否都由改动蕴含）**：`cmd-review.sh`、`perf.sh`、`references/protocol.md`、`loop-inventory.tsv` 各改了什么、为什么这个变更必须改它（例如删掉的函数还有别的调用方）。**任何没被蕴含的顺手改动都要点名**。`loop-inventory.tsv` 那一行：新增的循环必须已登记且有界。

## 另外两件

- **不许用墙钟**：全树搜候选新增的断言里有没有「sleep 若干秒再断言」或时间区间比较；有就点名。
- **断言密度**：§34b 从 75 个断言点涨到 102（+27）。逐条看那 15 条「分支表」用例：它们是**不同的输入**，还是同一个判断重复写了多遍？只报判断，不要改。这关系到我们刚确立的「夹具守行为、不守分支存在」的纪律。

## 必须做的实证

- `bash skills/teamsmith/tests/smoke.sh --select 34,34b`（**逗号**）在候选上全绿，贴段尾与 rc；
- **红侧**：在私有副本里把「每轮重算」改成「排队时缓存一次」（缓存第一次算出的上限）→ 你 A 里那条「心跳更新后截止更晚」的断言必须**红**；还原必须绿；
- 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`（`openspec` 不在 PATH 就用 `bash -lc` 并说明）、账本禁令固定验收行、`git diff --check`。

跑之前 `ps` 确认没有别人的 `smoke.sh`；不要跑整套、不要跑容器。破坏只在 `/var/tmp/…` 的私有副本里。

## 边界与交付

只读代码、只写 `docs/team/reports/V78-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。注意 §34b⑫ 是既有的不稳定断言（已有另一席在查），你遇到它红时如实记录、不要算成本次改动的缺陷。local 模式。
