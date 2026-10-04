# M51 · 门禁在钉死容器里红了两条：修 P27 新夹具的环境假设（apply 收尾）

```
task:   M51
agent:  verify
issue:
change: gate-hygiene                    # P26/P27 已合并；本任务收尾同一 change，归档前的前置
specs:  verification#The hard timeout covers the gate run, not the queue / panel#Frame assembly is asynchronous, cached and never blocks input
phase:  apply
anchor: change
deltas: panel                      # 逗号分隔的 capability token（不是文件路径）
deps:   P27（已合并，锚点来自它）
status: todo
budget: 一个工作块（改完必须在**钉死容器里**自证）
```

> 本地模式：不 push；分支留在 `.worktrees/verify`。

## 事实：CI 红了（main 上 run `35524041943`，只有两条）

```
✗ 35e 子 shell 里的 SKIP 计数 = 1（期望 [1]，实际 [2]）
✗ 36 panel-cpu-premise 有失败项（rc=1；✓ 3 ✗ 15）
    ✗ a-above：期望退出码 4，实际 3（3 = setup failure）
    ✗ b-below：期望退出码 2，实际 3
计时断言按负载前提跳过 1 条：27-d 装配红线（loadavg 6.39）
=== 结果 ===  ✓ 2633 ✗ 2
```

**PM 已在本地容器里复现并定位出真因**（不是猜）：

```
$ podman run --rm --userns=keep-id --pid=host --cgroups=enabled \
    -e HOME=/tmp -v "$PWD:/work:ro" -w /work teamsmith-gate:local \
    bash -c 'bash skills/teamsmith/tests/panel-cpu-premise.sh'
panel-cpu: /usr/bin/time is required for the tree figure      ← panel-cpu.sh 第 103-106 行
```

- **`/usr/bin/time` 在镜像里不存在**（`panel-cpu.sh` 从 ce35f05 起就需要它；此前它只在人手跑，
  **没进过门禁**，所以这个镜像缺口一直没暴露 —— P27 新增的 36 段是第一个需要它的门禁段落）；
- 容器盖了只读挂载、又是非 root，运行时 **apt 装不了**（`E: Could not open lock file /var/lib/dpkg/lock-frontend`）
  → 只能**改镜像**；
- `35e` 是**全局**跳过计数断言：CI 的 runner 是 **4 核**（`0.75 × 4 = 3 < loadavg 6.39`）→ 真实的 27-d 也跳过一次
  → 计数变 2；本机 32 核时不会。

## 要求（改完在**容器里**自证，不接受"本机绿"）

1. **`ci/Containerfile`**：把 `time`（提供 `/usr/bin/time`）加进 apt 列表；镜像重建后
   `bash -c 'command -v /usr/bin/time'` 必须通过（把该自检**写成断言**，与镜像里既有的其它工具自检放在一起）。
2. **`tests/smoke.sh` 的 35e**：断言不许依赖跑机核数/负载 —— 用夹具旋钮把 **load 与 cores 都注入**
   （`TEAM_SMOKE_FIXTURE=1` + `TEAM_SMOKE_LOADAVG` + `TEAM_SMOKE_CORES`），或在断言里**只数自己那一次跳过**；
   并补一条反向夹具证明它**仍会**在真的多跳一次时判红（不许把断言改成恒真）。
3. **`panel-cpu.sh` 缺工具时的姿态**：从 `exit 3`（setup failure，夹具会判失败）改成**可见跳过**
   （打印一行原因 + `SKIP`，退出码沿用你的约定：4 = 没结论），这样：
   · 有 `/usr/bin/time`（门禁镜像）→ 照常判红/绿；
   · 没有（用户自己跑、别的环境）→ **可见**说清"树 CPU 图需要 /usr/bin/time，没装"，而不是硬失败。
   `tests/panel-cpu-premise.sh` 相应地把"环境缺少该工具"识别为**SKIP**（可见、不判红、不假绿）。
4. **文档**：`SKILL.md` 的 Requirements 一段把 `/usr/bin/time` 列进可选依赖（与 `timeout`、`lsof` 并列），
   并说明缺它时哪条读数会跳过。
5. **不许动**：前提阈值（`0.75`/`0.25`）、红线（2000ms/1%）、排队记账语义、`d-realpath` 的反后门对照逻辑。

## Acceptance（贴原始输出；**容器里**跑）

```sh
# 1) 重建镜像（含你加的 time）
podman build -t teamsmith-gate:local -f ci/Containerfile .        # 或用 distrobox-host-exec
# 2) 在钉死容器里跑新建的两段 + 全量门禁（与 CI 同一路径）
podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \
  -v "$PWD:/work:ro" -w /work teamsmith-gate:local \
  bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'
# 3) 本机（32 核）也要保持绿
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
**验收判据**：容器里 `✗ 0`（或只允许"可见 SKIP"，且 SKIP 行打印原因），且 `35e` 在 4 核语义下也成立
（给出你在容器里读到的 `nproc` 与 load 数字）。

## Report

`docs/team/reports/M51-verify.md`：真因（含 `command -v /usr/bin/time` 的前后输出）、四处改动、
**容器内**的原始结果行、以及"4 核 runner 语义"下 35e 的证明。
