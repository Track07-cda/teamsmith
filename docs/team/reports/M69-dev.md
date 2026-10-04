# M69 · perf.sh `--in-container`：身份信号必须来自镜像自身（M64 F2 复验逃逸的封堵，apply 侧）

agent: dev   status: DONE   time: 2026-09-21T20:05Z
branch: `task/M69-perf-sh-in-container-f2`（HEAD `9361851`+报告提交；local 模式：不 push，分支留在 `.worktrees/dev`）

## Deliverables

| Path | What |
|---|---|
| `ci/Containerfile` | 新增 `RUN printf 'teamsmith-gate:1\n' > /etc/teamsmith-gate-image`（镜像 rootfs 里的标识文件，封闭 token，版本变动跟着变）+ 注释重写（双重身份证明、为何 `/run/.containerenv` 不能用、token 与 perf.sh 同步升版的约定）。加在末尾，重建全走缓存（实测 4.3s，STEP 18/21） |
| `skills/teamsmith/tests/perf.sh` | ① 常量 `PERF_IMAGE_IDENTITY_FILE`/`PERF_IMAGE_IDENTITY_TOKEN` + 判定函数 `perf_image_identity_rc`（cmp 逐字节；0=相等 / 1=缺失 / 2=不符）；② `perf_require_pinned_container` 重写为**双重校验**：① ENV 信号 + ② 标识文件，缺哪个/错哪个逐条点名（两条都缺就两条都点）→ exit 3，老镜像点名重建命令；③ 自检新增 6 条（函数级 ×4：逐字节相等过 / 缺失拒 1 / token 改拒 2 / 缺尾换行也拒 2；接线级 ×2：宿主伪造形状 → exit 3 且点名标识文件 —— 在真镜像里则换成钉「镜像里的文件逐字节等于 token」）；④ 头部/usage/`perf_print_build_run`/`perf_run_in_container`/入口注释与新语义对齐 |
| `skills/teamsmith/tests/smoke.sh` | **未动**（同 M66 的边界论证：gate-guard 禁止 smoke 引用 perf.sh；检查全在 perf.sh 自检里） |

## 修法（对应任务书四条）

1. **镜像自带证明**：`ci/Containerfile` 落 `/etc/teamsmith-gate-image`，内容封闭 token `teamsmith-gate:1`。
2. **双重校验**：`--in-container` 入口（拿锁/建临时目录/任何测量**之前**）验 ① `TEAM_PERF_PINNED_CONTAINER=1` 且 ② 标识文件存在且内容逐字节等于 token；缺哪个/错哪个点名哪个（exit 3）。宿主 distrobox 没有这个文件 → verify 的复现命令自然 exit 3（见下）。
3. **翻转**：见专节——红前（HEAD 版谎报）→ 绿后（exit 3）；改 token → 拒「不符」；真镜像（重建后）→ 全绿 exit 0 且自述全真；老镜像 → 拒「缺失」并点名重建。
4. **`perf_run_in_container` 语义不变**：两个证明都靠镜像自己带着（ENV + RUN），代码注释说死「故意不用 -e/挂载透传任何一个」；内层调用在真镜像里文件本就在。实测 `--container` 全路径绿（见专节⑤）。

顺带关闭 M66 报告「残余风险」里如实记录的那条：「人在宿主显式导出信号仍能伪造（实测会放行进套件）」——现在放进套件还需要伪造镜像 rootfs 里的标识文件，宿主直跑已不可能。

## 修复前后对比（verify 的原样复现命令，宿主）

**修复前（HEAD `5d6a003` 的 perf.sh = M66 版，只有 ENV 校验；抽出到假树 /tmp/m69-rb 跑，让它自洽地走进套件）**：

```
$ timeout 40 env TEAM_PERF_PINNED_CONTAINER=1 TEAM_PERF_ENGINE=/definitely/not/an-engine \
    bash /tmp/m69-rb/skills/teamsmith/tests/perf.sh --in-container ; echo rc=$?
rc=2                                                            ← 没拒绝，跑完了整套件
== 环境自述（performance suite） ==
  模式          : container（参考环境：钉死镜像）（参考环境）          ← 谎报
  可见逻辑核数   : 32（nproc）
  JS 运行时      : <home>/.local/bin/node v24.19.0          ← 宿主 node
  tmux          : <home>/.../scripts/shim/tmux tmux 3.7b    ← 宿主路径
  被测版本       : unknown（/tmp/m69-rb）                           ← 宿主侧假树
  ② 帧装配线：5 次采样 391, 393, 406, 408, 401 → 中位 401ms … → OK  ← 宿主读数记在「参考环境」名下
```

（与 verify 的 F2 复验逐字同形：宿主 node 被自述成「参考环境」。）

**修复后（本分支）**：

```
$ TEAM_PERF_PINNED_CONTAINER=1 TEAM_PERF_ENGINE=/definitely/not/an-engine \
    bash skills/teamsmith/tests/perf.sh --in-container ; echo rc=$?
perf: 身份证明 ② 缺失 —— 镜像标识文件 /etc/teamsmith-gate-image 不存在/不可读；钉死镜像的 rootfs
      里带着它（ci/Containerfile 的 RUN）。老镜像没有它 → 请按下面命令重建镜像。
perf: 拒绝以参考环境自居 —— --in-container 要求双重身份证明都在且都来自镜像自身（① 环境信号 + ② 标识文件），
      上面点名的就是缺的/错的。
      不在钉死容器里：要么进镜像跑（--container 会自己起容器，缺镜像时打印 build/run 命令；或 CI 形状
      podman run … bash -c '… perf.sh --in-container'），要么改用 --host（非参考环境，结论不作为验收依据）。
      重建参考镜像：<engine> build -f ci/Containerfile -t teamsmith-gate:local . ；宿主读数绝不记在参考环境名下。（exit 3）
rc=3                                                            ← 瞬时，锁/临时目录/测量都没碰
```

## 翻转证据（缺陷类任务专节）

**① 红前 → 绿后**：见上节（同一条命令：M66 版谎报 rc=2 跑完整套件 → 本分支 exit 3 点名缺标识文件）。

**② 老镜像（有 ENV=1、无标识文件）→ exit 3 点名重建**（重建前的 `:local`，`7031817c3499`）：

```
$ distrobox-host-exec podman run --rm -v "$PWD:/work:ro" -w /work \
    localhost/teamsmith-gate:local bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container' ; echo rc=$?
perf: 身份证明 ② 缺失 —— 镜像标识文件 /etc/teamsmith-gate-image 不存在/不可读；…老镜像没有它 → 请按下面命令重建镜像。
perf: 拒绝以参考环境自居 —— …
rc=3
```

更老的 `:m51`（`e907617229d1`，连 ENV 都没有）→ ①② 两条都被点名，同样 rc=3（输出在 §设计里不再展开，已实跑）。

**③ 标识文件内容被改 → exit 3 点名「不符」**（老镜像 + 挂载错误 token，证明比较的是内容不是存在性）：

```
$ printf 'teamsmith-gate:999\n' > /tmp/m69-wrong-token
$ distrobox-host-exec podman run --rm -v /tmp/m69-wrong-token:/etc/teamsmith-gate-image:ro \
    -v "$PWD:/work:ro" -w /work localhost/teamsmith-gate:local \
    bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container' ; echo rc=$?
perf: 身份证明 ② 不符 —— 标识文件 /etc/teamsmith-gate-image 的内容不是期望的封闭 token「teamsmith-gate:1」
     （逐字节比较）；这不是本套件认的钉死镜像。
perf: 拒绝以参考环境自居 —— …
rc=3
```

**④ 拆守卫 → 谎报回归 → 还原**（「break the implementation → the guard test must fail → restore it」）：
`perf_image_identity_rc` 第一行插 `return 0`（其余原样），自检里钉这条接线的断言原形是
`timeout 10 env … TEAM_PERF_PINNED_CONTAINER=1 bash perf.sh --in-container` 期望 rc=3。

```
破坏后同一条宿主伪造命令 : rc=124（10s 超时杀掉 = 没拒绝、走进了套件）；
                          日志重新出现谎报「模式: container（参考环境：钉死镜像）（参考环境）」
                          + 宿主 node <home>/.local/bin/node   ← 自检接线断言在此形态必红（rc≠3）
还原（cp 回备份）        : git diff --stat 为空；同一条命令 rc=3        ✓ 恢复
```

**⑤ 真镜像（重建后）→ 绿，自述全真**：
重建：`distrobox-host-exec podman build -f ci/Containerfile -t teamsmith-gate:local .` → 4.3s（STEP 18/21 =
`RUN printf 'teamsmith-gate:1\n' > /etc/teamsmith-gate-image`，其余全缓存），新镜像 `a55ccdacb577`。
镜像内双证明实测：`ENV=1` + `cat /etc/teamsmith-gate-image` → `teamsmith-gate:1`，`cmp` 逐字节相等 ✓。
dogfood 全路径（外层 `--container` 自己起容器，内层 `--in-container` 双重校验通过）：

```
$ bash skills/teamsmith/tests/perf.sh --container ; echo rc=$?
参考环境：镜像 localhost/teamsmith-gate:local（引擎 distrobox-host-exec podman）
  模式          : container（参考环境：钉死镜像）（参考环境）   ← 这次是真的：
  JS 运行时      : /usr/local/bin/node v24.19.0                 ← 镜像内 node（不是宿主 .local）
  tmux          : /usr/local/bin/tmux tmux 3.7b                 ← 镜像内 tmux
  被测版本       : 9361851（/work）                              ← 容器挂载
  ② 帧装配线：中位 459ms ≤ 2000ms ｜ 前提成立 → OK
  ① 交互首帧：1849 2062 1954 -> median 1954 < 2000 ｜ 前提成立 → OK
  ③ 稳态窗格 CPU：median 0.00% < 1% ｜ 前提成立 → OK
== 结果 ==  ✓ 3 绿  ✗ 0 红  SKIP 0 没结论（自检失败 0）；参考环境：是；面板夹具：✓ 18 ✗ 0 finding 0
perf: 三条判定全绿 → exit 0
rc=0
```

## 自检（每次套件运行都跑；宿主形态全绿，容器形态同理）

```
✓ 自检 · 身份信号：=1 → 通过（实际 0）
✓ 自检 · 身份信号：缺失 → 拒绝（实际 1）
✓ 自检 · 身份信号：=0（被改）→ 拒绝（实际 1）
✓ 自检 · 标识文件：内容逐字节等于 token → 通过（实际 0）
✓ 自检 · 标识文件：缺失 → 拒绝（缺失）（实际 1）
✓ 自检 · 标识文件：token 被改 → 拒绝（不符）（实际 2）
✓ 自检 · 标识文件：缺尾换行（非逐字节相等）→ 拒绝（不符）（实际 2）
✓ 自检 · 入口接线：缺信号 → 真 CLI 可见拒绝 exit 3（实际 3）
✓ 自检 · 入口接线：拒绝点名身份信号与 --host 出路
✓ 自检 · 入口接线：错信号（=0）→ 真 CLI 可见拒绝 exit 3（实际 3）
✓ 自检 · 入口接线：有 ENV 信号但缺标识文件（宿主伪造形状）→ 真 CLI 可见拒绝 exit 3（实际 3）
✓ 自检 · 入口接线：拒绝点名缺镜像标识文件
```

接线级都是真 CLI 子进程 + `timeout 10`：拒绝必须先于拿锁瞬时返回；若有人把接线改回「信口头声明」，
子进程走进锁/套件被杀 → rc≠3 → 红（翻转④已实证 rc=124）。最后两条在真镜像里换成钉
「本机即钉死镜像 —— 标识文件逐字节等于 token」（镜像构建错了在那里红，不是 SKIP）。

## 验收命令（任务书三条，逐字实跑）

| 命令 | 结果 |
|---|---|
| `TEAM_PERF_PINNED_CONTAINER=1 bash skills/teamsmith/tests/perf.sh --in-container`（宿主） | **exit 3**，点名「身份证明 ② 缺失 —— 镜像标识文件 /etc/teamsmith-gate-image」+ 重建命令（输出见上） ✓ |
| `bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?` | **2**——宿主语义不变：照常跑完整套件、标注「非参考环境」，退出码来自测量（本机首帧真红，同 M66 交付时）；红线数值/`--host`/锁均未动 ✓ |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | **✓ 2205 ✗ 0**，rc=0 ✓ |

协议门禁另跑：`openspec validate --all --strict` → **18 passed 0 failed**；全量 `smoke.sh </dev/null` 两轮
（见下「FULL smoke 记录」）。

## FULL smoke 记录（如实两轮）

- 第 1 轮（19:16–19:40，门禁链自动跑）：**✓ 2703 ✗ 1**，唯一红 = `38-b panel-p21.sh choices`
  （PTY 夹具「选择器没有打开」一族 14 条子项，FAST 显式跳过的 ~2.5 分钟慢段）。单跑该夹具两轮
  **✓ 74 ✗ 0 / ✓ 74 ✗ 0**；且本分支相对分支点 `5d6a003` 的 diff 只有 `perf.sh` + `ci/Containerfile`
  两个文件，38-b 用的 bundle/`team`/fixture 全都与分支点逐字节相同 —— 构不成因果，判为 PTY 抖动。
- 第 2 轮（报告交付前复跑）：**✓ 2704 ✗ 0**，rc=0，38-b 同轮全绿（✓ 74 ✗ 0）——第 1 轮那红确认为
  PTY 抖动（总数对齐：2703+1 = 2704，第二轮一项不少）。最终门禁：openspec 18/18 + FAST ✓2205 ✗0
  + FULL ✓2704 ✗0，全绿。

## 边界执行

- 只碰 `grant:` 的 `perf.sh` + `ci/Containerfile`；`smoke.sh` 一行未加（gate-guard 禁止 smoke 引用 perf.sh，
  M66 已论证；检查全在 perf.sh 自检）。红线数值、`--host`、锁零改动（`git diff 5d6a003 --stat` 可证）。
- 未 push（local 模式）；`docs/team/**` 只新增本报告。
- token 升版约定写在 Containerfile 注释：镜像身份变动时 `RUN` 的 token 与 perf.sh 的
  `PERF_IMAGE_IDENTITY_TOKEN` 同步改（两处常量同名同值，`teamsmith-gate:1`）。

## 残余风险（如实记录）

- 双重证明仍非密码学证明：能改镜像 rootfs 或挂个伪造文件进容器的人理论上仍能伪造——但那已经
  是「显式构建一个假参考镜像」，远超「无意谎报」的防护目标（M64 F2 的逃逸 = 宿主导出一个环境
  变量，现已不可能）。宿主侧没有任何一个文件路径组合能同时满足两条（无 `/etc/teamsmith-gate-image`，
  PM 实测 `/run/.containerenv` 在 distrobox 宿主也存在所以没被采用）。
- 镜像与 perf.sh 的 token 是两处手工同步的常量：靠 Containerfile 注释里的约定约束；若只改一处，
  真镜像会 exit 3 点名「不符」——失效方式是可见的，不会静默谎报。

Agent: dev
