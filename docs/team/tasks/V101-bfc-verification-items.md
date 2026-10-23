# V101 · 独立复验 `behavior-focused-ci` 的 6.1–6.4（勾之前的最后一道）

task: V101
agent: verify
phase: verify
category: verify
change: behavior-focused-ci
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V101-bfc-verify

## 受检对象

`openspec/changes/behavior-focused-ci/`（实现 P326、返修由 V70/V71/V86 三轮验过，`2.4`/`5.1`/`7.6` 的读数由 PM 补齐）。
现在要勾的是 6.1–6.4 四条**复验项**——它们要求的是「复验改变的部分」，不是「把整套再跑一遍」。

## 要做的四件（对应清单 6.1–6.4）

1. **6.1 复验改变的部分，逐条给红→绿或「破坏实现 → 该断言必红 → 还原」**：
   - `--check` 的新规则（`⑨` 全位置划分）；
   - `--slice` 的分片与并集（`--check` 的 `N∈{2,3,4,5,6,8,12}`）；
   - 选段块的 `--floor`/`--slice`/`--paths` 正交；
   - `36⑨` 的真实执行（不再 skip）。
   每条：改坏 → 必须红并点名 → 还原 → 绿（你自己造，不复用作者的日志）。
2. **6.2 少量针对性反例**：`--floor --paths` 的**换行 / 引号 / 反斜杠**三种文件名各一次（这是 6.2 的字面要求）。
   注意：**不要跑整套地板**（PM 已跑过两次，一次干净 rc=0、一次改坏断言 rc=1）；只跑选段器能给出的形状证据 + 一次
   小选段即可，并在报告里说明你的做法与边界。
3. **6.3 不重跑重段**：在记录里引用 P316 / V65 / V66 的既成证据，写明「§61b、性能套件未重跑」及原因。
4. **6.4 复验记录**：写 `docs/team/reviews/behavior-focused-ci.md`——改变部分的命令与输出尾部、判定、未重测项的引用。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写那份 review 记录与自己的线程。**不跑整套门禁、不触发远程 CI**。
结论先写 PASS/PARTIAL/FAIL。清单条目**你不要勾**——把结论交 PM，由 PM 勾（这是本轮一直守的「勾选自留 PM」）。
