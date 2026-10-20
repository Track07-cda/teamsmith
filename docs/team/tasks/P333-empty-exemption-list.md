# P333 · §58 不许在空豁免清单上跳过（既有缺陷，非本轮引入）

task: P333
agent: dev3
phase: apply
category: code
change: -
anchor: openspec/specs/verification/spec.md#The gate judges behaviour only, and never reports a skip as a pass
deltas: -
branch: task/P333-empty-exemption-list
deps: P326 已并入 main（`smoke.sh` 单写者纪律）；P331 已并入（不冲突）

## 问题（PM 已核实，不是猜测）

`skills/teamsmith/tests/signal-lint-legacy.txt` 现在**零条登记**（P326 退役了唯一那条无对象记录）。而 `smoke.sh` 的 §58 这样判：

```
P159_LEGACY_ALL_INTERNAL=1   # 空清单时循环一次都不执行，仍为 1
if [ "$P159_LEGACY_ALL_INTERNAL" = 1 ] \
   && checkout_registered_paths_absent "$CHECKOUT_REPO_ROOT" "$SKILL_DIR/tests/signal-lint-legacy.txt"; then
  prereq_skip "58 lint 真树：…（豁免清单）" …
```

`checkout_registered_paths_absent`（`tests/lib/checkout-shape.sh:119`）对空清单直接 `return 0`（循环零次）。于是**清单一旦为空，这一条前提跳过就永远成立**：§58 里「仓库脚本/夹具没有按名字或模式选进程」这条主判定从此再也不会执行，而屏幕上看到的是一次可见 SKIP —— 跳过被当成了通过。

这不是 P326 引入的：清单原有一条、其对象文件早已不在检出里，所以这条 skip **在改动之前就已经在跳**。本轮只是让它从「有一条、对象不在」变成「零条」，前提本身失去了意义。

## 要做的（最小，一处语义）

只有「清单**至少有一条**登记、且每一条都不在这棵检出里」时，§58 才允许那次前提跳过。**空清单 = 可裁决**：照旧带空清单跑 lint（产品面与内部面都判），不打印那条 skip。

- 判据写在 **§58 自己的条件里**（例如另算一个「登记条数 ≥ 1」），**不要改 `checkout_registered_paths_absent` 的契约**：`checkout-shape-probe.sh` 的两条既有断言（`.log` 393 行「真实清单的路径都不在这棵检出里 → 可跳过 0」、`583` 行「有一条在位 → 1」）与 §19（`tmux-lint-legacy.txt` 同样零条）都依赖现在的契约，改共享函数会把 §19 的十条前提跳过一起翻掉——那不是本任务的范围。
- 注释要跟上（现在那段注释描述的是「清单每一条都落在内部面且都不在」的世界，补一句「空清单不算『无法裁决』」）。
- 不要新增开关、不要加第二套判据函数、不要碰 §19、不要动 lint 本身（`signal-lint.pl` 一行不改）。

## 必须交的证据（各给命令与原始尾部）

1. 空清单（当前 main 的实际状态）下 `bash skills/teamsmith/tests/smoke.sh --select 58`：**不出现** `SKIP（条件不满足）` 的 `58 lint 真树` 那一行，而是照旧出 `✓ 58 lint 真树：…（N 个历史豁免文件逐条打印）`（N=0），整段退出 0。
2. 反向①：在**私有磁盘副本**里给清单加一条「对象存在」的登记（例如 `printf '<sha256> 1 skills/teamsmith/scripts/team  # x\n' >> 副本清单`）→ 同一段必须**不跳过**、并按原规则判（这条证明「有条目」时行为未变）。
3. 反向②：在**私有副本**的扫描面里种一条 `pkill -f p333-planted`（放在 `tests/` 之外的脚本里，因为 `tests/**` 的违规必须真修、不许豁免）→ 空清单下 §58 必须**红**并点名 `file:line`；这一条证明空清单时 lint 真的在判，而不是换了个地方跳过。
4. `bash skills/teamsmith/tests/checkout-shape-probe.sh`（或它在门禁里的入口）与 `--select 19` 的读数：证明 §19 那十条前提跳过与探针两条契约断言**没有被我改动**。
5. 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

破坏只做在自己的磁盘副本里（`/var/tmp/…`，私有 `TMPDIR`），不动这棵源树；`--keep` 用到才保现场，收尾清自己的根。

## 边界

- 写集：`skills/teamsmith/tests/smoke.sh`（**只有 §58 那段条件与注释**）、`docs/team/reports/P333-dev3.md`。
- 不碰产品实现、不碰 `signal-lint.pl`、不碰 `checkout-shape.sh`、不碰 §19、不碰探针、不改任何时限或预算、不新增门禁段。
- 这是**净零**：它退役的是「空清单也跳过」这个不再成立的许可，没有新增检查器。
- 报告先说结论（空清单现在判不判），再给读数；没跑到的如实写「未验」。
