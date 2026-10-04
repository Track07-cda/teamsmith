# M66 · perf.sh `--in-container` 不得把宿主谎报成参考环境（M64 F2 返工，apply 侧）

agent: dev   status: DONE   time: 2026-09-21T17:55Z
branch: `task/M66-perf-sh-in-container-m64-f2`（HEAD 见下；local 模式：不 push，分支留在 `.worktrees/dev`）

## Deliverables

| Path | What |
|---|---|
| `ci/Containerfile` | 新增 `ENV TEAM_PERF_PINNED_CONTAINER=1` + 注释（身份信号，不是调优旋钮；调用者不得用 `-e` 伪造）。加在末尾，重建全走缓存（实测 58.8s） |
| `skills/teamsmith/tests/perf.sh` | ① 判定函数 `perf_pinned_signal_rc` + 响铃拒绝 `perf_require_pinned_container`（exit 3，点名出路）；② 入口在**拿锁/建临时目录/任何测量之前**验信号；③ 自检新增 6 条（函数级 ×3 + 真 CLI 接线级 ×3）；④ 头部/usage/`perf_print_build_run`（原 215 行）/`perf_run_in_container`（原 248 行）/入口注释与新语义对齐 |
| `skills/teamsmith/tests/smoke.sh` | **未动**（见「边界说明」） |

## 修法（对应任务书五条）

1. **可信信号**：`ci/Containerfile` 末尾 `ENV TEAM_PERF_PINNED_CONTAINER=1`，注释写明「identity signal, NOT a tuning knob… callers must not pass it in via `-e`」。
2. **校验信号**：`--in-container` 入口先验信号，缺失/不符 → 可见拒绝 exit 3，点名「不在钉死容器里：要么进镜像跑（--container / CI 的 podman run 形状），要么改用 --host（非参考环境）」，绝不继续。拒绝发生在 `perf_lock_or_continue` 之前——宿主误叫连锁都不沾（瞬时返回，这点也被自检钉住）。
3. **真容器不受影响**：信号由镜像 ENV 自己带着，`perf_run_in_container` 故意**不**加 `-e` 透传（代码里有注释说死）。CI 形状实测照常（见下「真容器证据」）。
4. **宿主直跑变红**：任务书里的 PM 复现命令现在 exit 3（前后对比见下）。
5. **翻转证据**：见专节——信号被删/被改 → 红；真容器（安静机）→ 全绿 exit 0。

## 边界说明（smoke.sh 为什么一行没加）

任务书：「smoke.sh 只在确有必要时加一条断言（优先把检查做进 perf.sh 自检，别动门禁结构）」。实地查证后
**确无必要、且被既有守卫禁止**：`tests/gate-guard.sh` ① 把 `perf\.sh` 列为测量夹具点名，`smoke.sh` 里出现即红
（「门禁不许调用测量夹具」），任何拼出 perf.sh 路径的写法都命中。因此检查全部做进 `perf.sh` 自检
（函数级 + 真 CLI 子进程接线级，见下），门禁结构零改动，§35 守卫照绿。

原 215/248 两行（`perf_print_build_run` 的打印命令与 `perf_run_in_container` 的容器内调用）语义不变
（镜像内跑依然合法），各补了一句/一段说明，不留教唆直跑的旧话。

## 修复前后对比（同一条命令，宿主直跑）

**修复前（`75d1f2c`，谎报现场）**：

```
$ timeout 15 bash skills/teamsmith/tests/perf.sh --in-container   # rc=124（继续往下测量，被超时杀掉）
== 环境自述（performance suite） ==
  模式          : container（参考环境：钉死镜像）（参考环境）          ← 谎报
  可见逻辑核数   : 32（nproc）
  JS 运行时      : <home>/.local/bin/node v24.19.0          ← 宿主路径
  tmux          : <home>/.../scripts/shim/tmux tmux 3.7b    ← 宿主 shim
  被测版本       : 75d1f2c（<home>/.../.worktrees/dev）       ← 宿主 checkout
  ② 帧装配线：… → OK                                              ← 宿主读数照常进判定
```

**修复后（`98d6c6e`）**：

```
$ bash skills/teamsmith/tests/perf.sh --in-container ; echo rc=$?
perf: 拒绝以参考环境自居 —— --in-container 只认钉死镜像的身份信号 TEAM_PERF_PINNED_CONTAINER=1（当前：缺失）。
      不在钉死容器里：要么进镜像跑（--container 会自己起容器，缺镜像时打印 build/run 命令；或 CI 形状
      podman run … bash -c '… perf.sh --in-container'），要么改用 --host（非参考环境，结论不作为验收依据）。
      宿主读数绝不记在参考环境名下。（exit 3）
rc=3                                                            ← 瞬时，锁/临时目录/测量都没碰
```

## 翻转证据（缺陷类任务专节）

**① 信号被删 → 红**：上面「修复后」就是（宿主缺信号 → exit 3）。
**② 信号被改 → 红**：

```
$ TEAM_PERF_PINNED_CONTAINER=0 bash skills/teamsmith/tests/perf.sh --in-container ; echo rc=$?
perf: 拒绝以参考环境自居 —— …（当前：值是「0」而不是 1）。…
rc=3
```

**③ 容器内剥信号 → 红**（新镜像 + `-e TEAM_PERF_PINNED_CONTAINER=` 把信号抹掉）：

```
$ distrobox-host-exec podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \
    -e TEAM_PERF_PINNED_CONTAINER= -v "$PWD:/work:ro" -v "$MAIN:$MAIN:ro" -w /work \
    localhost/teamsmith-gate:local bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container --tree /work'
perf: 拒绝以参考环境自居 —— …（当前：缺失）。…
rc=3
```

**④ 拆守卫 → 自检必红 → 还原**（「break the implementation → the guard test must fail → restore it」）：
自检里钉接线的断言原形是 `timeout 10 env -u TEAM_PERF_PINNED_CONTAINER … bash perf.sh --in-container` 期望 rc=3。

```
修复态探针        : rc=3（可见拒绝）                                  ✓
sed 拆除入口接线  : # 守卫拆除（翻转试验）
拆除后探针        : rc=124（不等锁/套件 10s 被杀；日志重新出现谎报的
                   「模式: container（参考环境：钉死镜像）」）           ← 自检接线断言在此形态必红
git checkout 还原 : git diff --stat 为空；探针 rc=3                    ✓ 恢复
```

**⑤ 真容器里绿**（有镜像：重建后 `localhost/teamsmith-gate:local` = `7031817c3499`，
`image inspect` 确认 `TEAM_PERF_PINNED_CONTAINER=1` 在镜像 ENV 里；旧镜像 `:m51` 无此信号——
用它跑 `--in-container` 会被拒并点名重建，符合设计）。dogfood 全路径（外层 `--container` 自己起容器，
内层 `--in-container` 验信号通过）：

```
$ bash skills/teamsmith/tests/perf.sh --container        # 安静机复跑（loadavg ≈3.9）
参考环境：镜像 localhost/teamsmith-gate:local（引擎 distrobox-host-exec podman）
  模式          : container（参考环境：钉死镜像）（参考环境）   ← 这次是真的：/usr/local/bin/node、
                                                                  /usr/local/bin/tmux 3.7b、/work、98d6c6e
  ① 交互首帧：1954 1957 2061 -> median 1957 < 2000 → OK
  ② 帧装配线：中位 436ms ≤ 2000 → OK
  ③ 稳态窗格 CPU：median 0.00% < 1% → OK
== 结果 ==  ✓ 3 绿  ✗ 0 红  SKIP 0（自检失败 0）；参考环境：是
perf: 三条判定全绿 → exit 0
```

（同形首跑在门禁并发负载下 ① 中位 2064ms 踩线 exit 2——测量红、非身份/接线问题；安静复跑即全绿。
性能判定本就不阻塞合并，见 workflows.md。）

## 自检（每次套件运行都跑，宿主/容器同绿）

```
✓ 自检 · 身份信号：=1 → 通过（实际 0）
✓ 自检 · 身份信号：缺失 → 拒绝（实际 1）
✓ 自检 · 身份信号：=0（被改）→ 拒绝（实际 1）
✓ 自检 · 入口接线：缺信号 → 真 CLI 可见拒绝 exit 3（实际 3）
✓ 自检 · 入口接线：拒绝点名身份信号与 --host 出路
✓ 自检 · 入口接线：错信号（=0）→ 真 CLI 可见拒绝 exit 3（实际 3）
```

接线级用真 CLI 子进程 + `timeout 10`：拒绝必须先于拿锁瞬时返回；若有人把接线改回「信口头声明」，
子进程会走进锁/套件被 timeout 杀掉 → rc≠3 → 自检红（④ 已实证该形态 rc=124）。

## 验收命令（任务书三条，逐字实跑）

| 命令 | 结果 |
|---|---|
| `bash skills/teamsmith/tests/perf.sh --in-container`（宿主直跑） | **exit 3**，点名身份信号缺失与 `--host` 出路（输出见上） ✓ |
| `bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?` | **2**——宿主语义不变：照常跑完整套件、标注「非参考环境」，退出码来自测量（本机首帧 ~3.4s 真红）。对照旧代码（`75d1f2c` 抽出到 /tmp 同机跑）：exit 4（SKIP 形态），同一语义族；红线数值/`--host`/锁均未动 ✓ |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | **✓ 2205 ✗ 0**，rc=0 ✓ |

协议门禁另跑：`openspec validate --all --strict` → 17 passed 0 failed；全量 `smoke.sh` → **✓ 2703 ✗ 0**，rc=0。

## 残余风险（如实记录）

- 信号是「镜像自证身份」，不是密码学证明：人在宿主显式 `TEAM_PERF_PINNED_CONTAINER=1 bash perf.sh
  --in-container` 仍能伪造（实测会放行进套件）。这正是任务书指定的形状——把「无意的谎报」（CI/发版叫错
  地方）变成「必须显式伪造」；不能用 `/.dockerenv`/`/run/.containerenv` 加深校验，distrobox 也带这些标记，
  会把开发容器误当参考镜像（代码注释已说死）。
- 旧镜像（`:m51` 等无信号的）跑 `--in-container` 现在可见拒绝 exit 3 并点名重建——有意为之的失效方式。

Agent: dev
