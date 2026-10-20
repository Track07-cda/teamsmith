# V76 · P329 的独立验收：三处减法有没有减掉不该减的东西

task: V76
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 删断言与合并推导
deltas: -
branch: task/V76-subtractions-verify

## 受检与问题

候选 `6a995d2a`（实现 `ba3b17a8` 合并推导、`33d83df0` 三处减法、`2a47156d` 路径声明），报告 `docs/team/reports/P329-dev-bob.md`。注意：**该分支落后 main**，`git diff main <候选>` 里那几份 `docs/team/tasks|threads|BOARD` 的“删除”是落后造成的，不是它的改动；你判的是产品/测试面那三个文件。

三处减法各要回答一个问题：

**A（§58 删两条内联翻转）**：删掉的「干净文件不报红」「`kill -TERM "$pid"` 不误报」这两条是否真的被 `signal-lint.pl --selftest` 的夹具表覆盖？覆盖到什么程度（同一输入？同一判定路径？）——**只看 word 不算，跑 `--selftest` 并把对应夹具名点出来**。

**B（§34⑦ 删五条基于自造 `expected=400` 的算式断言）**：算式剩下的真行为「读不到 `expected` → 退回 W」是否仍由 `§34b⑨` 钉着？删掉的那五条里有没有哪一条守的是**已发生过的事故**（查 `DECISIONS`/`reviews` 里 gate-lock 那几条记录：P281/P288/P310/P316）？逐条说明它守的是什么、今天由谁守。

**C（合并两份「席位=运行时目录」推导）**：合并后**失败语义有没有被合并**？两条必须不同：锁记录写不出去时要**仍然写**（诊断不能因为读不到席位就哑掉）；`team notify` 解析不出席位时要**拒绝**（不能猜）。自己造两个现场（不写席位目录 / 席位目录不可解析）验证这两条各自的行为与改动前**逐字相同**。

## 必须自己做的

1. 上面的 A/B/C，各给命令与原始尾部。
2. **红侧（承重）**：在私有副本里把合并后的 `team_seat_from_paths` 改坏一处（例如返回错误的席位名），要求 `§34b⑨` 或 `team notify` 那条拒绝**变红并点名**——证明合并后的单点仍是承重的，不是「两份都删了也没人管」。
3. **断言账**：自己数 §58 / §34 / §34b 的断言条数（改前 main 与候选各数一次），核对报告里的 `25→21`、`39→37`、`86→82`；数值对不上就点名差在哪一条。
4. **选段读数**：`bash skills/teamsmith/tests/smoke.sh --select 34,34b,58`（**注意逗号分隔**，任务书原文用空格是错的，会 rc=2）。要求全绿；贴段尾与 rc。
5. **PM 立的两处账**（只需确认，不用修）：(a) 报告说 main 上 §0e「循环清单不同步」是改前就有的 3 条红——在**未改动的 main** 上跑一次同段确认它确实同样红；(b) `openspec` 在登录 shell 的 PATH 里不存在这件事，用 `bash -lc 'command -v openspec'` 与当前 shell 各查一次，说明你用什么形式跑的。
6. 轻量收口：`bash -n`（三个改动的脚本）、`section-select.sh --check`、账本禁令固定验收行、`git diff --check`。

跑之前 `ps` 确认没有别人的 `smoke.sh` 在跑；不要跑整套、不要跑容器、不要抢机器级门禁锁。

## 边界与交付

只读代码、只在自己的磁盘目录里造破坏、只写 `docs/team/reports/V76-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。local 模式，PM 合并与关单。
