# P333 · 空豁免清单不该打印「无法裁决」那次 SKIP（是文案与计数，不是漏判）

task: P333
agent: dev3
phase: apply
category: code
change: -
anchor: openspec/specs/verification/spec.md#The gate judges behaviour only, and never reports a skip as a pass
deltas: -
branch: task/P333-empty-exemption-list
deps: P326 已并入 main（`smoke.sh` 单写者纪律）

## 问题（PM 已核实；先纠正一条我自己的错判）

`signal-lint-legacy.txt` 现在零条登记，而 §58 那段的本意是「这一册账在检出里无法裁决时，用一份空清单跑、并记一次前提跳过」。PM 先前的判断说它「让主判定再也不会执行」——**这是错的**，已更正：

`prereq_skip` 只累加 SKIP 计数并打印一行（`smoke.sh:736`），它**不返回、不跳过**；紧随其后的

```
if perl "$P159_LINT" ${P159_LEGACY_ARGS...}; then ok "58 lint 真树：…（N 个历史豁免文件逐条打印）" else bad "…判红" fi
```

是**无条件执行**的，而且此时 `--legacy` 指向一份空清单 —— 也就是语义上没有任何豁免、按完整扫描面判。所以 §58 主判定**一直在跑**，并没有漏判。

真正的问题只有两个，都是「屏幕上说了不真的话」：

1. 清单零条时，那行前提跳过说「豁免清单注册的路径逐条不在（冻结的证据层）」——**空集谈不上无法裁决**，这句话对读者是假的。
2. 同一条检查会同时出现一行 `SKIP（条件不满足）` 和一行 `✓`，SKIP 计数也因此虚高——按本项目「跳过不许当成通过」「屏幕上不写不真的话」两条纪律，这属于该修的账。

## 要做的（一处条件，最小）

只有「清单**至少有一条**登记、且每一条都不在这棵检出里」时，§58 才走那份空清单 + 前提跳过。**空清单照样带空清单跑 lint，只是不再打印那行 SKIP**。

- 判据写在 **§58 自己的条件里**（另算「登记条数 ≥ 1」），**不要改 `checkout_registered_paths_absent` 的契约**：`checkout-shape-probe.sh` 的两条既有断言（`.log` 393 行、583 行）依赖它现在的返回值。
- **不碰 §19**（`tmux-lint-legacy.txt` 同样零条、同样这条形状）：它与 §58 是同一个既有小账，但改它要连带探针 ⑤b 的期望值，属另一件，不在本任务写集里。
- 注释补一句「空清单不算『无法裁决』」；不要新增开关、不要加第二个判据函数、不要动 `signal-lint.pl`。

## 必须交的证据（各给命令与原始尾部）

1. 当前清单（零条）下 `bash skills/teamsmith/tests/smoke.sh --select 58`：**不出现** `SKIP（条件不满足）` 的那行 `58 lint 真树`，而 `✓ 58 lint 真树：…（0 个历史豁免文件逐条打印）` 照旧出现；整段退出 0；段尾 SKIP 计数比改动前少 1。
2. 反向①：在**私有磁盘副本**里给清单加一条「对象在位」的登记 → 同一段**不跳过**、按原规则判（证明有条目时行为未变）。
3. 反向②：在私有副本的扫描面里（`tests/` **之外**，因为 `tests/**` 的违规必须真修）种一条 `pkill -f p333-planted`，清单清零条 → §58 必须**红**并点名 `file:line`；证明空清单时判的是完整扫描面，不是换个地方跳过。
4. `--select 19` 与 `checkout-shape-probe.sh` 的读数：证明 §19 与探针两条契约断言**没有被这次改动影响**（§19 仍打它那行 SKIP，探针仍绿）。
5. 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

破坏只做在 `/var/tmp` 下的私有副本里，不动源树；收尾清自己的根。

## 边界

- 写集：`skills/teamsmith/tests/smoke.sh`（**只有 §58 那段条件与注释**）、`docs/team/reports/P333-dev3.md`。
- 不碰产品实现、`signal-lint.pl`、`checkout-shape.sh`、§19、探针、任何时限与预算；不新增门禁段。
- 净零：退役的是「空清单也算无法裁决」这个不再成立的许可，没有新增检查器。
- 报告先说结论（空清单下是否还打那行 SKIP、主判定是否照旧跑），再给读数；没跑的如实写「未验」。
