# P434 · reply-observer-skip-focus 实施

agent: dev   status: delivered（3.3 留待非作者复验）   time: 2026-11-09
branch: `task/P434-reply-observer-skip-apply`   PR/MR: -

## 结论

已将缺观测器证明从完整 `bounded,flip` 重跑替换为短样本。正常 bounded 先完成全部独立文件检查及权限恢复，再进入共享观测入口；full_scan 缺席继续由正常结果消费者处理。短样本、八项反例/还原、六组外部父级消费对照、非 FAST §62 和静态验收均实际通过；没有修改产品实现或 `lib/proc-io.sh`。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/key-replies.sh` | 提取共享观测入口；以短样本、明确分类、准备顺序检查和 subshell 反例替换完整 replay/trace；父级局部判断由 7 条改为 6 条 |
| `openspec/changes/reply-observer-skip-focus/tasks.md` | 勾选 1.1–2.3、3.1–3.2；3.3 未勾选，交由另一非作者复验 |
| `docs/team/reports/P434-dev.md` | 本报告与原始证据位置 |

## 执行环境与日志

行为验收使用 `localhost/teamsmith-gate:local`，实际命令经 `distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id` 启动；`HOME=/tmp`、`TMPDIR=/logs/tmp`，工作树挂载为 `/work`。完整日志和临时根均在宿主 bind mount `/var/tmp/p434-reply-observer/`，不是只留容器内文件或管道尾部。§62 起止指纹均为提交 `011f22ed`、dirty=0、树哈希 `01ba4719…daca546b`，运行中未改树。

- 短样本最终日志：`/var/tmp/p434-reply-observer/logs/skip-path-final.log`
- 短样本原始证据：`/var/tmp/p434-reply-observer/final-evidence/`
- §62 完整日志：`/var/tmp/p434-reply-observer/logs/smoke-62.log`
- §62 内层完整日志：保留根中的 `p234-key-replies.log`
- §62 IO/命令证据：`/var/tmp/p434-reply-observer/smoke-62-evidence/`
- 外部副本及日志：`/var/tmp/p434-reply-observer/external/`
- 静态验收：`/var/tmp/p434-reply-observer/logs/static-acceptance.log`

## Verification evidence（均实际运行）

```bash
$ bash -n skills/teamsmith/tests/key-replies.sh
[rc=0]

$ bash skills/teamsmith/tests/key-replies.sh --select skip-path
  ✓ skip-path：旋钮让观测器判为不可用
  ✓ skip-path：驱动/bounded/full_scan 三条缺席诊断及理由完整
  ✓ skip-path：样本 rc=0、✓0 ✗0 SKIP2、无索引；一槽准备反例及还原创立
  ✓ skip-path：反例·三处诊断各自不可缺，无关 SKIP 不能顶数且逐项还原
  ✓ skip-path：反例·bounded/full_scan 缺席都不能误算观测通过且逐项还原
  ✓ skip-path：反例·bounded/full_scan 缺席都不能误判产品失败且逐项还原
== P234 key-replies 结果 == ✓11 ✗0 SKIP0
[rc=0；/usr/bin/time：real 0.89s，user 0.78s，sys 0.28s]
```

短样本不是手写日志，也没有只调用 `kr_io_supported`：`kr_skip_sample_collect` 依次调用正常驱动通知、`kr_bounded_observe`、`flip_probe_full_scan` 和 `kr_flip_absence_result`。健康样本的原始输出为：

```text
reply-observer-sample-before: bounded-index=absent full-scan-index=absent prepared-indexes=0
key-replies: 可见跳过 —— /proc/<pid>/io 不可读（TEAM_REPLY_NO_PROC_IO=1（夹具模拟缺工具））：bounded 的读取量断言与 flip/full_scan 会点名跳过
  SKIP bounded：缺 /proc/<pid>/io（TEAM_REPLY_NO_PROC_IO=1（夹具模拟缺工具））—— 读取量断言跳过（点名：内核计数器不可读）
  SKIP flip/full_scan：观测器缺席（TEAM_REPLY_NO_PROC_IO=1（夹具模拟缺工具））—— 该臂跳过，未得结论
reply-observer-sample-after: bounded-index=absent full-scan-index=absent prepared-indexes=0

== reply-observer absence sample 结果 == ✓0 ✗0 SKIP2
```

`skip-path-focused-controls.txt` 有 16 段：准备顺序正反例，以及缺诊断三项、误算成功两项、误判产品失败两项各自及七次真实函数还原。所有反例 judge rc=1、所有还原 sample/judge rc=0。无关 SKIP 变体仍因 `bounded诊断=0次` 和跳过数 4 被拒。一槽反例实际产生 `bounded-index=present … prepared-indexes=1`，判定点名 `准备顺序`，还原后为 0；没有恢复 400 MB 准备。

### 父级消费侧三侧对照

外部副本均复制完整 `skills/teamsmith`，因此 `tests/lib/proc-io.sh` 和产品相对路径可解析；每个副本通过原 `--select skip-path` 入口运行一次。损坏只删除对应共享处理的真实 `skip` 调用；吞错副本再把普通样本消费分支的 `bad` 改为 `:`。

```text
bounded-broken rc=1
  ✗ skip-path：缺席诊断/分类不完整（诊断[bounded诊断=0次;];完整结果行=0份;结果行不是末行;观测跳过数=1（应为2）;；样本rc=0）
bounded-discard rc=1
  named_parent=0
bounded-restored rc=0
  named_parent=0
full_scan-broken rc=1
  ✗ skip-path：缺席诊断/分类不完整（诊断[full_scan诊断=0次;];完整结果行=0份;结果行不是末行;观测跳过数=1（应为2）;；样本rc=0）
full_scan-discard rc=1
  named_parent=0
full_scan-restored rc=0
  named_parent=0
external_consumer_rc=0
```

两条吞错副本仍因内置反例的真实函数还原侧失败而 rc=1，但指定父级断言消失，证明非零退出本身没有被误当传播证据。内置反例不调用 skip-path 组或启动脚本副本，上述父级标签只由普通样本消费分支发出。

### 非 FAST §62

```bash
$ bash skills/teamsmith/tests/smoke.sh --select 62 --keep </dev/null
✓ 62 key-replies 十二组全绿（夹具结果行 ✓217 ✗0 SKIP1）
#5 62 · 关键回复存储与 CLI · 参考 用时 450s · ✓1 ✗0 SKIP0
== 选段结果 == ✓25 ✗0
[rc=0；podman /usr/bin/time：real 458.00s；后台作业含启动/收尾为 473.0s]
```

这是选段而非全套；输出列出未跑的 134 个键。未追加全量、夜间、61b 或 UI 全套。内层日志实际包含 input、paths、original、concurrency、receipts、interrupt、paging、bounded、readonly、workflow、flip、skip-path、guide、capture 全部组。

正常 bounded 的坏最新、0111 不可枚举、0000 正文不可读、权限恢复后的 list/summary/show 均先通过，随后观测入口通过以下真实检查：

```text
✓ bounded：坏最新槽 summary=unavailable 且不退回旧标题
✓ bounded：bodies 不可枚举时 list 照常（按槽读，不枚举）
✓ bounded：正文不可读时 show 失败（它确实去读了正文）（=4）
✓ bounded：同一 store 的 summary 照常（不读正文）
✓ bounded：一页读的字节数与历史规模无关（10 万槽 − 60 槽 = -44 字节 ≤ 64 KiB）
✓ bounded：一页的读系统调用数也与历史规模无关（Δsyscr=0 ≤ 100）
✓ bounded：summary 的读取量与历史规模无关（Δ=-44 字节 ≤ 8 KiB）
✓ bounded：show 的读取量 = summary + 那份正文（Δ=65 字节 ≤ 64 KiB）
```

九臂 `no_lock`、`early_saved`、`raw_tail`、`no_cursor`、`full_scan`、`symlink`、`fifo_block`、`readonly_mkdir`、`no_enumerate` 均为真实变异红、还原绿，没有转移到缺席样本。full_scan 的保留根 `flip-scan.log` 与命令台账为：

```text
flip/full_scan：big=411284272 mid=1930020 rc= Δrchar=409354252   # 变异侧
flip/full_scan：big=1889075 mid=1889064 rc= Δrchar=11              # 还原侧
flip full_scan mutant=13717df2…f69f2 restored=f350c279…8d08ea base=f350c279…8d08ea red=1 green=0
```

内层唯一 SKIP 是 `capture：缺 pi(/tmp/.bun/bin/pi)，真 Pi 段未跑（parser/source 段仍跑）`；parser/source 检查通过。它不是观测器跳过，也没有被说成已通过的真 Pi 检查。

### 静态验收

```text
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 125 reference(s) (49 distinct) in 14079 effective line(s); retired 0; undeclared 0
[rc=0]

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
[rc=0]

$ openspec validate --all
Totals: 23 passed, 0 failed (23 items)
[rc=0]

$ openspec validate reply-observer-skip-focus --type change --strict
Change 'reply-observer-skip-focus' is valid
[rc=0]
```

verification 合成块仍保留 route-page 的三项例外，并单独列出 reply-observer 退休例外；未改成冲突的 “only the three”。按任务分工，作者未执行 design 中 PM-only 的正反试归档。

## 执行删除点与计数账

相对任务基线 `bca31951` 的实际 diff 删除了：

```text
- skip "bounded：同上 —— flip/full_scan 也会点名跳过"
- TEAM_REPLY_NO_PROC_IO=1 … key-replies.sh --select bounded,flip
- TEAM_REPLY_NO_PROC_IO=1 … bash -x key-replies.sh --select bounded,flip（失败 trace）
- if [ "$skips" -ge 3 ] …
```

| 计数层 | 改前约定 | 本次实际结果 |
|---|---|---|
| skip-path 父级局部判断 | 7：强制能力、末行、三诊断、无红、SKIP 下限 | 6：强制能力、三诊断、结果/准备顺序、三类反例；standalone 总结果另含 5 条隔离守卫，故为 `✓11 ✗0 SKIP0` |
| 短缺席子样本 | 不存在；旧 replay 子计数从不并入父级 | `== reply-observer absence sample 结果 == ✓0 ✗0 SKIP2`，独立前缀，不并入父级或 smoke 通用结果读取 |
| 正常 key-replies / smoke | 正常 bounded 和九臂各一次；旧 replay 是额外子进程 | `✓217 ✗0 SKIP1`；smoke §62 只消费真实父级结果并记 `✓1`，选段总计 `✓25 ✗0` |

没有拿旧子进程计数从父级扣除，也没有凑旧全局总数。改前旧分支单独耗时未测、未知；本次只报告上述 0.89 秒短入口和 458 秒 §62，不计算节省。

## Ledger ban and final diff

```bash
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2491 hits=0 names=ok user=resolved
[rc=0]
```

```bash
$ git diff --check
[no output]
[rc=0]
```

## Decisions and deviations

- 无范围偏离；未修改 `proc-io.sh`、产品回复实现、正式规格、CI、配置或其它测试。
- 3.3 未执行、未勾选，须由另一非作者独立复验。未合并、归档、发布或推送。

## Suggested next steps

- PM 指派非作者复核本报告列出的原始日志、反例与父级消费证据；真实归档仍需用户确认。
