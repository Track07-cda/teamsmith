# V90 · §61b 进度接线的独立验收（发布阻塞项）

task: V90
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 挂住判据的进度证据
deltas: -
branch: task/V90-61b-progress-verify

## 背景：这是发布阻塞项

0.3.1 的冻结验收（冻结克隆 + 钉死镜像，整套门禁）在 **#128 §61b** 被停：

```
✗ 段落 #128（61b · 任务类别模型路由：翻转变异自检）挂住：已 1800s 没有进度
```

诊断（PM 已核代码，你要独立复核）：§61b 是 4946 s 的变异矩阵，原来是一整段阻塞调用、输出全进文件、
**八十二分钟内一个 tick 都没有**；P316 把「每段预算表」换成「统一的 1800 s 挂住上限」后，合法长跑与真挂住
在证据上无法区分。移植判断：**判据没错**（停跑看「没有进度」），缺的是这一段没有把进度交出来。

修法（`ca98f874`）：矩阵放后台跑，**它的日志在长**＝本段进度（每长一行 `section_guard_check` 一次）；
硬上界 7200 s 只回答「它没动」；循环按规矩登记进 loop inventory。

## 要回答的

**A · 两个方向都要有（承重）**
`P238_SUITE` 可用环境变量指向替身。用 `SG_FIXTURE=1 SG_HANG_CAP_OVERRIDE=5 SG_STUCK_SECTION=61b` 把守卫的挂住上限压到 5 秒，然后 `bash skills/teamsmith/tests/smoke.sh --select 61b`：

1. **动的替身**（每 1 秒写一行、跑 20 秒）→ **不许被停**，本段必须正常收口（贴段尾、退出码）。
2. **不动的替身**（20 秒一行不写、末尾 rc=0）→ 必须在 ~5 s 被守卫停掉、**一行**点名「61b 挂住」，并且**只红一次**（不要同时冒出「有失败 rc=…」那条）。贴原始尾部。
   两个替身都放 `/var/tmp/…` 私有目录，不要往 `tests/` 加文件。

**B · 到硬上界那条路**：把替身改成永不退出，用 `SG_FIXTURE=1 SG_HANG_CAP_OVERRIDE` 压不到 7200 秒——所以这一条只能**读代码**判断：到 7200 s 时它 `break`、`kill` 子进程、打一条 `bad`「没等到结果…（挂住，不是慢）」，并且**不再**判 rc（不重复红）。逐句核对这三件事在代码里成立。

**C · 没有把别的东西带坏**
- `section-guard.sh --loop-check` 83/83 全过；新增循环在清单里、上限字面量在循环体内；
- `--select 61b` 用**真**套件跑一次（约 82 分钟）——**这一条由 PM 在发布门禁里跑，你不要重复**；你只跑替身；
- 段内 `ok`/`bad` 的收口行格式没变（ticks 现在会非零，这是本修法的目的：贴一次「动的替身」收口行里的 ticks）。
- 生产代码、别的段、`section-paths.tsv` 逐字节未变（`git diff ca98f874^ ca98f874 --stat` 只应有两文件）。

## 边界

只读代码、只在 `/var/tmp` 造替身、只写 `docs/team/reports/V90-verify.md` 与自己的线程。不跑整套、不跑容器、不抢机器级门禁锁（`--select 61b` 用私有 TMPDIR 与私有锁）。结论先写 PASS/PARTIAL/FAIL。
