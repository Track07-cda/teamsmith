# V103 · 独立复验 `gate-waiter-patience` 的 7.1–7.4

task: V103
agent: dev3
phase: verify
category: verify
change: gate-waiter-patience
specs: verification#A waiter's patience follows the holder's heartbeat, not a budget nobody publishes
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V103-gwp-verify

## 受检

`gate-waiter-patience` 的实现（P338）与缓存反例（P372）都已并入 main。要勾的是清单 `7.1–7.4`：
定点执行、一条反向对照、确认没有回归、写复验记录。

## 要做的

1. **7.1**：在自己的克隆上定点**执行** `--select 34,34b,34d,36`（不是查表），贴结果行；这四段覆盖了心跳耐心规则的
   正面、边界、stalled 现场与旁路。
2. **7.2**：只做一条反向对照——把心跳来源改回「只读 `.holder`」→ `§34b` 的正向断言必须红（「读全部活登记」是这条规则的
   唯一来源），还原必须绿。
3. **7.3**：确认没有回归——`§34b①/⑦` 的排队超限语义仍是 `rc=2`、点名、`没有运行`、`FAIL` 不是 `TIMEOUT`；贴这两条的读数。
4. **7.4**：写 `docs/team/reviews/gate-waiter-patience.md`（命令、输出尾部、判定、未测项与引用）。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写那份 review 与自己的线程。不跑整套、不跑容器、不抢机器级门禁锁。
清单条目**不要勾**，交 PM。结论先写 PASS/PARTIAL/FAIL。
