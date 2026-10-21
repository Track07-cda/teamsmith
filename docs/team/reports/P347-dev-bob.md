# P347 · 给 P342 那条豁免配一个常驻的证伪者（V83 的 F1）

agent: dev-bob   status: delivered   time: 2026-10-21
branch: `task/P347-pin-exemption-boundary`（`5ab8a377` 之上，含 P342 全部提交）   PR/MR: -（本仓 local 模式）

**结论**：P342 的 `release-*` 豁免现在有常驻证伪者了。在 M16 隔离对照段里加了五条对**合成根**的直接断言
（四条边 + 一条「恰三条命中」总数），不新增段、不加夹具文件，`--select 25,30` 一次全绿（✓113 ✗0，M16 段
27 → 32 条）。红侧按 V83 描述的那次放宽实测：把豁免改成「路径里含 `release-` 就跳过」→ **三条变红**
（同前缀的 `release-scan.log`、嵌套的 `nested/release-x/a.log`、以及总数腿），还原即绿；再把豁免收窄成
「必须正好是 `release-030`」→ **仍全绿**，说明这组断言钉的是边界、不是把某个目录名硬编码进测试。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | M16 隔离对照段新增合成根 `$TMP/m16-scope-probe` 的五条断言（P342 边界腿：同前缀文件命中 / 嵌套目录命中 / `release-030/a.log` 静默 / 普通账本命中 / 恰三条命中），注释写清这组存在的理由与「合成根名字不带 release」的原因 |
| `docs/team/reports/P347-dev-bob.md` | 本报告 |

写集内：**没有**改豁免逻辑本身（`real_ledger_hits` 的过滤一字未动，P342 的提交原样保留）、没有新开段、没有
新增夹具文件。

## Verification evidence (must have actually been run)

**1. 本树选段门禁（改动面上全绿）**

```
$ bash skills/teamsmith/tests/smoke.sh --select 25,30
  ✓ M16 隔离对照·P342：同前缀的普通账本文件 release-scan.log 必须被点名（豁免是目录前缀，不是「含 release-」）
  ✓ M16 隔离对照·P342：nested/release-x/a.log 必须被点名（前缀没锚上就不是发布证据目录）
  ✓ M16 隔离对照·P342：发布证据目录 release-030/a.log 不命中（取样范围，不是账本痕迹）
  ✓ M16 隔离对照·P342：普通账本 plain.log 仍被点名（豁免没有把判断关掉）
  ✓ M16 隔离对照·P342：release-* 边界腿恰三条命中（只有发布证据目录那一条静默）
  #6 30 · 代号必须带名字（M16） · 参考 用时 6s · ✓32 ✗0 SKIP0 · ticks 32
账本自查： 6 段收口 · 增量 ✓113 ✗0 SKIP0 ｜ 结果行 ✓113 ✗0 —— 一致
== 选段结果 ==  ✓ 113  ✗ 0
```

（M16 段从 27 条变 32 条，正是新加的五条；这一段以前没有一条断言会因 `release-*` 的边界被放宽而变红。）

**2. 红侧/还原（私有副本，四个变体各跑一次 `--select 30`）**

副本 = `git archive HEAD` 出来的完整检出（HEAD 含本任务提交），每个变体只改 `in_release_dir()` 的函数体：

```
$ bash /var/tmp/p342-flip/run-p347b.sh
== strict ==                        # 树上原样：前缀 + 目录名后必须有路径分量
  exit=0   ✓ 55  ✗ 0
== widened ==                       # 放宽成「路径里含 release- 就跳过」（V83 的那次放宽）
  function in_release_dir(p) { return index(p, "release-") > 0 }
  exit=1
  ✗ M16 隔离对照·P342：同前缀的普通账本文件 release-scan.log 必须被点名（…）（期望 [1]，实际 [0]）
  ✗ M16 隔离对照·P342：nested/release-x/a.log 必须被点名（…）（期望 [1]，实际 [0]）
  ✓ M16 隔离对照·P342：发布证据目录 release-030/a.log 不命中（…）
  ✓ M16 隔离对照·P342：普通账本 plain.log 仍被点名（…）
  ✗ M16 隔离对照·P342：release-* 边界腿恰三条命中（…）（期望 [3]，实际 [1]）
  == 选段结果 ==  ✓ 52  ✗ 3
== prefix-plus ==                   # 半放宽：前缀还在，但「目录名后还有分量」换成「含 release-」
  exit=1
  ✗ 同前缀的普通账本文件 release-scan.log 必须被点名（期望 [1]，实际 [0]）
  ✓ nested/release-x/a.log 必须被点名（前缀没锚上，仍命中）
  ✓ release-030/a.log 不命中 ｜ ✓ plain.log 仍被点名
  ✗ 恰三条命中（期望 [3]，实际 [2]）
  == 选段结果 ==  ✓ 53  ✗ 2
== narrowed ==                      # 收窄成「必须正好是 release-030」
  exit=0   ✓ 55  ✗ 0
```

- `widened` 是任务书要求的红侧：**第 1、2 条按预期变红**，总数腿同时红（实际只命中 1 条）。
- `prefix-plus` 是额外的一份定位证据：它说明第 2 条腿钉的是「前缀必须锚在 `<root>/.pi/team/state/release-`」，
  第 1 条腿钉的是「目录名之后必须还有路径分量」——两个条件各有一条腿，少任何一个都会变红。
- `narrowed` 是任务书要求的反向确认：把豁免写死成只认 `release-030`，五条腿**仍全绿**（第 3 条静默、第 1、2
  条照旧命中），说明这组断言没有把测试变成「某个目录名的特例硬编码」，更窄的实现不会被判红。

**3. 轻量收口**

```
$ bash -n skills/teamsmith/tests/smoke.sh && echo OK
OK
$ git diff --check && echo diff-check-OK
diff-check-OK
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 9  bad 0  SKIP 1          （rc=0）

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/dev-bob scope=published files=1969 hits=0 names=ok user=resolved
$ echo $?
0
```

没跑整套（任务书说的：不跑整套）。`--floor`/全套的既有阻塞（§61b 挂住上限）已在 P342 报告第 7 节记过，与本任务无关。

- Verdict: pass
- Notes: 这组断言落在 §30（M16 隔离对照），与 M9.8/M16 同一族、`--select 25,30` 可选到；M9.8 段（25）没有
  重复加一份——同一份函数、同一组边界，加两处只会让下一次改口径要改两个地方。

## Flip evidence (required for defect-fix tasks)

"break the implementation → the guard test must fail → restore it" 的完整读数见上面第 2 节：

- 放宽（V83 的那次放宽）→ **✗3**（第 1、2、总数腿），退出码 1；
- 半放宽（只拿掉「目录名后还有分量」）→ **✗2**（第 1、总数腿）；
- 还原（`strict`）→ **✓55 ✗0**，退出码 0；
- 收窄成只认 `release-030` → **✓55 ✗0**（断言不禁止更窄的实现）。

## Decisions and deviations

- 断言放在 §30 的**既有**隔离对照块之后（`rm -rf "$M16_NEG"` 之后、§31 之前），用的是**另一个**合成根
  `$TMP/m16-scope-probe`，而不是把四个文件塞进既有的 `$M16_NEG`：后者会改变该块最后那条「三条真痕迹腿恰三条
  命中」的计数，等于顺手改写别人的断言。
- 合成根的名字**故意不含 `release`**：若根路径本身带这个词，「放宽」那侧的变红会全部由根路径造成，钉不住
  文件路径本身的边界（实测 `widened` 的红来自三条相对路径，见第 2 节）。
- 关于「净零」（AGENTS.md）：这一组不是新守卫，它是一条**新行为的证伪者**——P342 引入的取样豁免此前没有任何
  断言会因它被放宽而变红（V83 实测）。它也没有新增检查器：仍然只有 `real_ledger_hits` 一个判据，增加的是对
  它边界的断言。
- 第一次跑变异体时踩了一个坑，记下来免得下一个人重踩：私有副本是 `git archive HEAD` 建的，所以**未提交**
  的断言不会出现在副本里，三个变异体当时都跑了旧树、显示全绿。变异体只认已提交的树。

## Suggested next steps

- PM 复验：`--select 25,30` 一次即可（约 45 s），外加 `/var/tmp/p342-flip/run-p347b.sh`（四个变体，约 40 s）
  即可独立重现红侧。
- P342 与 P347 在 `task/P347-pin-exemption-boundary` 上是可以一起合入的一条线：`5ab8a377`（P342 报告）之后是
  `2069f863`（本任务的断言）与本报告提交。若 PM 更愿意按任务分开合并，先把
  `task/P342-ledger-leak-release-logs`（`5ab8a377`）合进 main，再把本分支 `merge --ff-only` 上去也可。
