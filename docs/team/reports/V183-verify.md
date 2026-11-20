# V183 · 性能命令交接与两种故障的独立验证

agent: verify · status: PASS（候选及合并版定点） · time: 2026-11-20T08:02:37Z
branch: `task/V183-help-perf-entry-verify` · PR/MR: -

**候选三个样本通过，合并版 `282b9dc79dd1c1fb751e50a040f2834612ff26be` 的六个相关文件与候选逐字节一致，语法和接入点核对通过。** 正常调用把唯一参数 `--host` 交给临时记录程序，CLI 返回记录程序的 `23`，调用项目六项指纹不变。两个故障均按预期被拒绝：直接返回 `0` 但没有回执；有正确回执且 CLI 仍返回 `23`，但写了调用项目的 `state`。没有运行真实性能测量。

## Deliverables

| 路径 | 证据 |
|---|---|
| `docs/team/reviews/P483.md`、`docs/team/reviews/P483-verify.log` | 本席位从独立检出执行的原生 `team review`；当前绑定合并版，PASS。此前两轮候选中央记录由 PM 收存。 |
| `/var/tmp/v183.NO8yop/` | `run.sh`、`finish.sh`、`assess.py`、各样本 CLI 输出、原始退出码、Bash 跟踪、回执、故障差异及写入文件；`initial-review/` 保留首次原生 FAIL 的记录、日志及原始驱动。待 PM 接收再清理。 |

## OpenSpec assessment

| 维度 | 结论 | 依据 |
|---|---|---|
| Completeness | P483 实现两项有证；两阶段均有记录 | 候选 `tasks.md` 原生 2/4，本席位未勾；仅 `help-surface.sh` 改了可执行内容，三条新增 `verification#A gate that cannot judge says so` 场景均有执行证据；合并版已按任务书核对。 |
| Correctness | 三条取得预期结果 | 以下原始退出码、回执字节、六项指纹和写入文件；缺回执与写入故障各只有一条具名失败。`help-surface#Every behaviour a help page states is declared and probed` 的检查仍执行真实 CLI，而非只读帮助文案。 |
| Coherence | 一项替换；现有接入和真实测量原样 | `help-surface.sh:929,1044–1090` 只替换 `perf` 的一次判断，新路径用既有 `env_run`、记录一次结果；`scripts/team:141`、`cmd-docs.sh:148–152` 原样转发给加载来源旁的 `tests/perf.sh`，本次该目标仅为私有记录程序。`smoke --select 0` 的 300 秒分支及 §51 的组选择和结果消费不变；见差异检查。 |

- CRITICAL 0 · WARNING 0 · SUGGESTION 0（候选范围）。席位和独立检出均无生成的 `openspec-verify-change` 指引，按任务书以结构、差异和三场景执行做等价审阅。
- 未验证：完整帮助组、其他帮助组、FAST/全量、真实性能均未运行。旧检查在到达真实测量程序时能观察其准备和部分执行（旧 `help-surface.sh:1047–1061`），但假终端 `capture-pane` 不返回画面（旧第 205 行），旧分支按六项指纹判结果、不要求测量退出码或读数。它未作为本轮历史对照重跑；V174 的 705 秒是整段时间，不是单命令计时，也不据此承诺省时。新检查不观察真实测量的准备和执行，无法证明真实测量全程不写调用项目；原有独立测量只提供读数，不补这项证据。

## 实际执行与退出码

从席位工作树调用原生命令，`F=/var/tmp/p483-review-645ec4b3.WqD4p1`，`R=/var/tmp/v183.NO8yop`，`SHA` 为上述完整提交，`PATH` 加入已安装的 OpenSpec 所在目录：

```bash
OPENSPEC_TELEMETRY=0 TMPDIR="$R" TEAM_SMOKE_LOCK="$R/review.lock" \
  TEAM_GATES="bash $R/run.sh" \
  bash skills/teamsmith/scripts/team review P483 --dir "$F" --branch "$SHA"
# native_review_rc=1（首次；原件 initial-review/）
OPENSPEC_TELEMETRY=0 TMPDIR="$R" TEAM_SMOKE_LOCK="$R/review.lock" \
  TEAM_GATES="bash $R/finish.sh" \
  bash skills/teamsmith/scripts/team review P483 --dir "$F" --branch "$SHA"
# frozen_checkout_after=clean / three_cases_plus_static_rc=0 / native_review_rc=0
```

实际样本自 `F` 执行下式。正常 `tree=$F`；故障各有 `skills/teamsmith/` 的独立复制根，第二轮实际写入用 `$R/state-write-prepared/source`，未交接用 `$R/no-handoff/source`。`BASH_XTRACEFD=19` 只记录原测试的退出码及实际前后指纹；私有 `HOME`、`TMPDIR` 和空继承环境隔离现场，原测试和记录程序没有改动。

```bash
env -i PATH=/usr/local/bin:/usr/bin:/bin HOME="$d/home" TMPDIR="$d/tmp" \
  LANG=C.UTF-8 OPENSPEC_TELEMETRY=0 BASH_XTRACEFD=19 \
  TEAM_HELP_SURFACE_TREE="$tree" TEAM_HELP_SURFACE_ONLY=perf TEAM_HELP_SURFACE_KEEP=1 \
  bash -x skills/teamsmith/tests/help-surface.sh --select claims \
  19>"$d/trace.log" >"$d/fixture.log" 2>&1
```

| 样本 | `claims` / CLI 退出码 | 实际具名结果 | `claims` 计数（通过 / 失败 / 跳过） |
|---|---|---|---|
| 正常 | `0` / `23` | `claims: perf 交接已确认（rc=23），调用项目六项指纹不变：state docs config worktree skills meetings` | `2 / 0 / 0` |
| 未交接 | `1` / `0` | `claims: perf 交接：未交接：没有回执；rc=0，预期退出 23；调用项目变化：无` | `1 / 1 / 0` |
| 写入状态后照常交接 | `1` / `23` | `claims: perf 交接：已确认；rc=23；调用项目变化：state` | `1 / 1 / 0` |

三组均在真实初始化的 `p-perf` 运行（初始化 `0`、Git `HEAD` 和 `.pi/team/config.sh` 存在）。每组的另一条通过是共同声明词表检查，不是第二次运行 `perf`。实际回执各恰好一行，末尾有换行：

```text
23 /var/tmp/v183.NO8yop/healthy/tmp/.teamsmith-help-surface.3671974/fx/p-perf 1 --host
23 /var/tmp/v183.NO8yop/state-write-prepared/tmp/.teamsmith-help-surface.3942649/fx/p-perf 1 --host
```

回执位于各自 `fx/p-perf` 之外的 `logs/p-perf.receipt`；`no-handoff/tmp/.teamsmith-help-surface.3676121/logs/p-perf.receipt` 不存在。两故障仅在复制树 `scripts/team` 的 `perf` 分支改动，`diff -qr` 各只列这一文件；正常、未交接、写入三份实际暂存记录程序逐字节一致（两次 `cmp` 均 `0`），与真实 `perf.sh` 不同。实际写入文件为 `/var/tmp/v183.NO8yop/state-write-prepared/tmp/.teamsmith-help-surface.3942649/fx/p-perf/.pi/team/state/v183-write-witness`，35 字节，内容为 `V183 private calling-project write` 加换行。

| 指纹 | 正常：前 = 后 | 未交接：前 = 后 | 写入状态：前 → 后 |
|---|---|---|---|
| state | `absent` | `absent` | `absent` → `43c7dfc410890080` |
| docs | `9d96eca454acbc03` | `9d96eca454acbc03` | `9d96eca454acbc03` 不变 |
| config | `c88e1d51c708622b` | `86cf0c9d74c7c89c` | `92fda9c3842713c4` 不变 |
| worktree | `54e287f6384aa0fa` | `71ec517a9791f6e7` | `a382d79ffc66f31f` 不变 |
| skills | `absent` | `absent` | `absent` 不变 |
| meetings | `e3b0c44298fc1c14` | `e3b0c44298fc1c14` | `e3b0c44298fc1c14` 不变 |

### 首次准备失败与对照

首次写入分支往尚未建立的 `.pi/team/state/` 写文件，真实 CLI 输出 `No such file or directory`，返回 `71`，没有回执，也没有写入；**不能记作所需的写入反例**。外层取证还把状态目录预存在误当成初始化条件，首次正式记录为 FAIL。按 PM 指示，从原件读出正常、未交接两组结果，没有重跑；只在新的写入故障副本 `perf` 分支先创建调用项目的 `.pi/team/state/` 再写文件，仍转发给原 `team_cmd_perf "$@"`。第二次的 `rc=23`、有效回执和唯独变化的 `state` 共同证明该反例命中，未将准备失败算作通过。

### 静态、语法与公开文件检查

```text
$ openspec --version
1.16.0
$ openspec validate help-perf-entry-without-measurement --strict
Change 'help-perf-entry-without-measurement' is valid
strict_rc=0
$ git diff --check 9a181efc..HEAD
candidate_diff_rc=0
$ git diff --exit-code 9a181efc..HEAD -- skills/teamsmith .github/workflows openspec/specs ':(exclude)skills/teamsmith/tests/help-surface.sh'
rest_unchanged_rc=0
$ bash -n <逐个文件>
help-surface.sh, scripts/team, lib/common.sh, lib/cmd-docs.sh, smoke.sh, perf.sh: syntax_rc=0（各一次）
```

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/verify scope=published files=2939 hits=0 names=ok user=resolved
ledger_rc=0
```

## 合并版定点核对

同一验证者于 2026-11-20T08:01:47Z 取得合并版原生 PASS。`M=/var/tmp/p483-merged-282b9dc7.LctwJq`，`R=/var/tmp/v183.NO8yop`；候选仍是 `645ec4b390ace52ef4408f1fcd080782abf1d556`。两个检出在比对开始时均干净，合并检出执行后仍干净。

```text
$ OPENSPEC_TELEMETRY=0 TMPDIR="$R" TEAM_SMOKE_LOCK="$R/merged.review.lock" TEAM_GATES="bash $R/merged.sh" bash skills/teamsmith/scripts/team review P483 --dir "$M" --branch 282b9dc79dd1c1fb751e50a040f2834612ff26be
cmp_rc=0 / syntax_rc=0（逐个检查）：
  tests/help-surface.sh, tests/smoke.sh, scripts/team,
  scripts/lib/cmd-docs.sh, scripts/lib/common.sh, tests/perf.sh
integration_rc=0 (source inspection only)
merged_review_check_rc=0 (byte equality, syntax, integration only)
native_merged_review_rc=0
```

- 在合并版源码核对：`smoke.sh:23423–23432` 仍调用同一帮助检查并接收其退出码；FAST 选择不含 `claims`。`help-surface.sh:471–472,929,1045–1065,1646` 保留 `smoke --select 0`，将 `perf --host` 接到私有记录程序；`scripts/team:59,141` 和 `cmd-docs.sh:148–152` 仍把真实命令转给加载来源旁的 `tests/perf.sh`。
- 合并版首次正式核对为 `1`：六个文件与语法已通过，但私有核对脚本把 `then check_claims;` 后的空格数量也当成条件。首轮正式记录和原脚本保留在 `$R/merged-initial/`。修正只在私有脚本按 Shell 词检查，第二次正式核对为 `0`，没有改产品。
- 未重复三个行为样本、OpenSpec 或测量。报告只在任务分支本地提交；任务清单与结案由 PM 处理，私有原件继续保留。
