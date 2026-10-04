# M73 · perf.sh：镜像标识文件不得是挂载点（堵住 M64 F2 第三轮「挂载伪造」）+ 信任边界成文

agent: dev   status: DONE   time: 2026-09-22T00:20Z
branch: `task/M73-perf-sh-m64-f2`（HEAD 见下；local 模式：不 push，分支留在 `.worktrees/dev`）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/perf.sh` | ① 新校验 `perf_image_identity_mounted_rc`：解析 `/proc/self/mounts` 第 2 列（八进制转义先 `printf '%b'` 解开再逐字节比），标识文件 `/etc/teamsmith-gate-image` 是挂载目标 → 0（伪造形状）；读不到 mounts 表 → 这一条判不了、不据此拒绝（伪装 mounts 表要控制容器运行时，已在信任边界外）；② `perf_require_pinned_container` 在 ② 之后加 ③：文件存在且是挂载点 → 点名「标识文件是挂载的，不是镜像烘焙的」→ exit 3（内容错且挂载时两条都点，守「缺哪个/错哪个点名哪个」）；③ 自检新增 7 条：函数级 ×5（空表 / 真镜像形状 overlayfs+work+resolv.conf / 伪造形状 / `\040` 转义不误判 / 表读不到）+ 接线级 ×2（①②齐但挂载 → exit 3 且点名；①②③全齐 → rc=0 放行，函数覆盖全在子壳）；④ 头部/usage/`perf_print_build_run`/`perf_run_in_container`/总结行文案从「双重」对齐为「①信号 + ②内容 + ③非挂载」；⑤ 信任边界（PM 裁定精简版）写进身份证明段的代码注释 |
| `skills/teamsmith/references/troubleshooting.md` | 新增 **§24**：三份证据各是什么、**在范围内**（裸宿主/导出变量/陈旧镜像/内容被改/挂载伪造——一切非故意误用都可见拒绝）与**范围外**（调用者控制容器运行时、故意把公开 token 烘进自建镜像或伪装 mounts 表——容器内自检有硬上限，是「自述可信对抗意外」不是「证明」），以及复核路径（每条判定都带完整环境自述，可疑结论永远能看来源）+ exit 3 时的两条出路 |
| `skills/teamsmith/tests/smoke.sh` | **未动**（同 M66/M69 的边界论证：gate-guard 禁止正确性门禁引用 perf.sh；全部钉都在 perf.sh 自检里，FAST/FULL 两轮佐证无回退） |

## 修法（对应任务书三条）

1. **标识文件不得是挂载点**：`--in-container` 校验加 ③——真镜像里标识文件落在 overlayfs 的 `/` 上，
   `/proc/self/mounts` 没有它的条目；套件自己的 wrapper（`perf_run_in_container`）只挂 `/work` 与主仓，
   从不挂它。挂载目标出现它 = 调用者挂进来的（token 写在公开的 `ci/Containerfile` 里，谁都能挂一份
   同内容文件）→ exit 3 并点名「标识文件是挂载的，不是镜像烘焙的」。校验仍在拿锁/搭建**之前**，瞬时。
2. **翻转**：见专节——verify 第三轮的原样伪造红前 3 绿 exit 0 → 绿后 exit 3 点名挂载；真镜像全路径绿；
   M66/M69 三条旧翻转逐条复跑不回退。
3. **文档**：troubleshooting §24（PM 裁定精简版原话：什么拒、为什么不防「自建镜像烘 token」、复核怎么看
   环境自述）。文件此前没有 perf 专节（任务书说的「inotify/perf 相关段」只有 inotify 的 §22b），故新开
   一节并在 perf.sh 注释里指过去。

## 翻转证据（缺陷类任务专节）

**① 红前 → 绿后（verify 第三轮的原样伪造：foreign 镜像 + 挂载公开 token + ENV=1）**

伪造命令（两轮逐字相同，唯一变量 = perf.sh 修复前/后；`:m51` = `e907617229d1`，无 ENV 无标识文件的
foreign 镜像；`/tmp/m73-token` 内容 = 公开的封闭 token `teamsmith-gate:1`）：

```sh
printf 'teamsmith-gate:1\n' > /tmp/m73-token
distrobox-host-exec podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \
  -e TEAM_PERF_PINNED_CONTAINER=1 \
  -v /tmp/m73-token:/etc/teamsmith-gate-image:ro \
  -v "$PWD:/work:ro" -w /work localhost/teamsmith-gate:m51 \
  bash -c 'bash /work/skills/teamsmith/tests/perf.sh --in-container'
```

红前（修复前的 M69 版 perf.sh；完整输出在 `state/bg/m73-red-before.log` 同源记录）：

```
== 环境自述（performance suite） ==
  模式          : container（参考环境：钉死镜像）（参考环境）        ← 谎报成立
  JS 运行时      : /usr/local/bin/node v24.19.0
  被测版本       : unknown（/work）
  ② 帧装配线：… 中位 456ms ≤ 2000ms … → OK
  ① 交互首帧：209 210 212 -> median 210 … → OK
  ③ 稳态窗格 CPU：… median 0.49% … → OK
  ✓ 自检 · 入口接线：本机即钉死镜像 —— 标识文件逐字节等于 token     ← 挂载的 token 骗过内容比较
== 结果 ==  ✓ 3 绿  ✗ 0 红  SKIP 0 没结论（自检失败 0）；参考环境：是；…
perf: 三条判定全绿 → exit 0
rc=0                                                                   ← 与 verify 第三轮逐字同形
```

绿后（本分支，同一条命令）：

```
perf: 身份证明 ③ 不符 —— 标识文件 /etc/teamsmith-gate-image 是一个**挂载点**（/proc/self/mounts 里有它的条目）：标识文件是挂载的，不是镜像烘焙的（token 是公开的，谁都能挂一份同内容文件，M64 F2 第三轮）；这不是本套件认的钉死镜像。
perf: 拒绝以参考环境自居 —— --in-container 要求身份证明都在且都来自镜像自身（① 环境信号 + ② 标识文件内容逐字节等于 token + ③ 标识文件不是挂载点），上面点名的就是缺的/错的。
      不在钉死容器里：要么进镜像跑（--container 会自己起容器，缺镜像时打印 build/run 命令；或 CI 形状
      podman run … bash -c '… perf.sh --in-container'），要么改用 --host（非参考环境，结论不作为验收依据）。
      重建参考镜像：<engine> build -f ci/Containerfile -t teamsmith-gate:local . ；宿主读数绝不记在参考环境名下。（exit 3）
rc=3                                                                   ← 瞬时，锁/临时目录/测量都没碰
```

**② 真镜像 → 绿（全路径 dogfood）**：`bash skills/teamsmith/tests/perf.sh --container`（外层自己起容器，
内层 `--in-container` 三份证据全过）。本任务不动 `ci/Containerfile`（不在 grant），无需重建——`:local`
（`a55ccdacb577`，M69 重建，带烘焙标识文件 + ENV）即真镜像：

```
  模式          : container（参考环境：钉死镜像）（参考环境）   ← 这次是真的
  JS 运行时      : /usr/local/bin/node v24.19.0               ← 镜像内 node
  被测版本       : 9604ce4（/work）
  ② 帧装配线：中位 426ms ≤ 2000ms ｜ 前提成立 → OK
  ① 交互首帧：median 1956 < 2000 ｜ 前提成立 → OK
  ③ 稳态窗格 CPU：median 0.00% < 1% ｜ 前提成立 → OK
  （新增 7 条自检钉在镜像内全绿：挂载判定 ×5 + 接线 ×2，含「本机即钉死镜像」原有钉）
== 结果 ==  ✓ 3 绿  ✗ 0 红  SKIP 0 没结论（自检失败 0）；参考环境：是；面板夹具：✓ 18 ✗ 0 finding 0
perf: 三条判定全绿 → exit 0
rc=0
```

**③ M66/M69 三条旧翻转逐条复跑，不回退**：

| 旧翻转 | 命令形状 | 结果 |
|---|---|---|
| 裸宿主直跑（M66） | `env -u TEAM_PERF_PINNED_CONTAINER bash perf.sh --in-container` | **rc=3**，点名 ① 信号缺失 + ② 标识文件缺失 ✓ |
| 宿主导出变量（M69） | `TEAM_PERF_PINNED_CONTAINER=1 bash perf.sh --in-container`（宿主） | **rc=3**，点名 ② 标识文件缺失 ✓（= 验收命令 1） |
| 内容被改（M69） | foreign 镜像 + 挂载**错** token（`teamsmith-gate:999`）+ ENV=1 | **rc=3**，② 内容不符与 ③ 挂载**两条都点名**（设计如此：错哪个点哪个） ✓ |

## 自检（每次套件运行都跑；宿主与真镜像两种形态都全绿）

新增 7 条（真镜像内实测输出）：

```
✓ 自检 · 挂载判定：空 mounts 表 → 不算挂载（实际 1）
✓ 自检 · 挂载判定：真镜像形状（overlayfs / + /work + resolv.conf，无标识文件条目）→ 不算挂载（实际 1）
✓ 自检 · 挂载判定：标识文件是挂载目标（伪造形状）→ 判挂载（实际 0）
✓ 自检 · 挂载判定：转义路径（\040 解开后是别的文件）→ 不误判（实际 1）
✓ 自检 · 挂载判定：mounts 表读不到 → 这一条判不了，不据此拒绝（实际 1）
✓ 自检 · 入口接线：信号+内容齐但标识文件是挂载的（伪造形状）→ 可见拒绝 exit 3（实际 3）
✓ 自检 · 入口接线：拒绝点名「标识文件是挂载的，不是镜像烘焙的」
✓ 自检 · 入口接线：信号+内容齐且不是挂载（真镜像形状）→ 放行 rc=0（实际 0）
```

接线级用函数覆盖造判定面（测试里造不了真挂载，要特权）；覆盖全在子壳（命令替换）里，不污染外层；
真挂载的端到端翻转 = 上面专节①②的 podman 实跑。原有钉（M66 信号 ×3、M69 标识文件 ×4、入口接线 ×4、
真路径旋钮忽略 ×4）全部原样保留且绿。

## 验收命令（任务书三条，逐字实跑）

| 命令 | 结果 |
|---|---|
| `TEAM_PERF_PINNED_CONTAINER=1 bash skills/teamsmith/tests/perf.sh --in-container`（宿主） | **exit 3**，点名 ② 标识文件缺失 + 重建命令（输出见翻转③第 2 行） ✓ |
| `bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?` | **2**——宿主语义不变：照常跑完整套件、标注「非参考环境」，退出码来自测量（本机首帧 3422ms 真红、夹具 c-healthy 如实报「机器安静却判红」，与 M66/M69 交付时同形；测量路径本任务一行未动） ✓ |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | **✓ 2290 ✗ 0**，rc=0 ✓（第一轮 ✗2 = §24 三行踩「容器依赖」逐行豁免，修复后复跑全绿，见下） |

协议门禁另跑：`openspec validate --all --strict` → **18 passed 0 failed**；全量 `smoke.sh </dev/null>`
一轮（见下）。

## FULL smoke 记录

- 第 1 轮 FAST（交付中途）：**✓ 2288 ✗ 2** —— 两条红都出自我新增的 §24：dep_scope_hits 的豁免是
  **逐行**的，含 `Containerfile` 的行必须同行带 `perf.sh`/`TEAM_PERF` 等 harness 标记，§24 有三行没带
  （真红 + 它的翻转夹具各计一条）。按原样逻辑本地验证 CLEAN 后重行换行修复（提交 `701ddfd`），
  第 2 轮 FAST **✓ 2290 ✗ 0**（总数 +2 = 同行其它段新增断言，与本任务无关）。
- FULL 一轮（交付前）：**✓ 2800 ✗ 0**，rc=0（877s）——最终门禁：openspec 18/18 + FAST ✓2290 ✗0 + FULL ✓2800 ✗0，全绿。

## 边界执行

- 只碰 `grant:` 的 `perf.sh` + `references/troubleshooting.md`；`smoke.sh` 一行未加（gate-guard 禁止 smoke
  引用 perf.sh，M66/M69 已论证；检查全在 perf.sh 自检）。红线数值、`--host`、锁零改动
  （`git diff 9604ce4 --stat` 只有上述两个文件 + 本报告）。
- 未 push（local 模式）；`docs/team/**` 只新增本报告。
- 信任边界按 PM 裁定执行：范围内（非故意误用的一切形状）全部可见拒绝；范围外（控制运行时故意烘 token /
  伪装 mounts 表）不防——容器内自检有硬上限，判定永远带完整环境自述供复核。成文于 troubleshooting §24 +
  perf.sh 身份证明段注释。

## 观察（不越权，交 PM 处置）

- `ci/Containerfile` 末尾注释仍写「declares what it is with **TWO** pieces of evidence」「requires both」——
  现在 perf.sh 验的是「两个烘焙构件 + 一条来源属性（非挂载）」。行为无影响、语义仍成立（两个构件确实是
  镜像自己带的；③ 是 ② 的来源校验不是第三个构件），但措辞可顺手对齐。该文件不在本任务 grant，未动。

## 残余风险（如实记录）

- ③ 读 `/proc/self/mounts`；调用者若能控制运行时把 mounts 表也伪装掉（over-mount `/proc` 一族），检查即
  失效——但那已在 PM 裁定的信任边界外（「控制容器运行时、故意」），且失效方式是「自述与来源对不上时复核
  能看出来」，不是静默谎报读数。读不到 mounts 表时这一条不判（不拿判不了的东西当拒绝理由，也不当放行
  证据——② 的内容校验仍独立生效）。
- token 升版仍是 Containerfile 与 perf.sh 两处手工同步的常量（M69 已记；约定写在 Containerfile 注释）。

Agent: dev
