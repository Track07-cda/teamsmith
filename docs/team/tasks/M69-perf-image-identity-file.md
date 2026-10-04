# M69 · perf.sh `--in-container`：信号必须来自镜像自身（M64 F2 复验发现的逃逸）

```
task:   M69
agent:  dev
issue:
change: perf-suite-split
specs:  verification#The performance suite is separate, self-describing and non-blocking
phase:  apply
anchor: change
deltas: -
grant:  skills/teamsmith/tests/perf.sh · ci/Containerfile · skills/teamsmith/tests/smoke.sh（仅必要时）
deps:   M66（已合并）· M64（F2 复验 BLOCKED = 本任务输入）
status: todo
budget: 半个工作块
```

> 本地模式：不 push。

## 缺陷（verify 的 F2 复验，PM 已复核成立）

```text
$ TEAM_PERF_PINNED_CONTAINER=1 TEAM_PERF_ENGINE=/definitely/not/an-engine \
    bash skills/teamsmith/tests/perf.sh --in-container
模式          : container（参考环境：钉死镜像）（参考环境）
JS 运行时      : <home>/.local/bin/node v24.19.0     ← 宿主 node
... 参考环境：是 ...                                          ← 谎报依旧，rc=2
```

**环境变量单独不构成信任**（与 tmux 闸门重做的教训同一条）。而且**不能**用 `/run/.containerenv` 当硬证据：
本机开发环境本身就是 distrobox 容器，那个文件在宿主上**也存在**（PM 实测）。

## 修法（按这个形状）

1. **镜像自带证明**：`ci/Containerfile` 加一行，在镜像 rootfs 里落一个**标识文件**
   （如 `RUN printf 'teamsmith-gate:1\n' > /etc/teamsmith-gate-image`；内容是一个封闭 token，版本变动时跟着变）；
2. **`--in-container` 双重校验**：① 环境信号 `TEAM_PERF_PINNED_CONTAINER=1` **且**
   ② 标识文件存在且**内容逐字节等于期望 token**；缺哪个/错哪个**点名哪个**（exit 3）。
   宿主的 distrobox 里没有这个文件 → verify 的复现命令自然变成 exit 3；
3. **翻转（每条红→绿原始输出）**：
   - verify 的原样命令（宿主 + 导出信号）→ **exit 3**，点名"缺镜像标识文件"；
   - 标识文件内容被改 → exit 3 点名"标识不符"；
   - 真镜像（重建后）→ 绿（exit 0/2 取决于机器，但**自述必须真实**）；
   - 老镜像（无标识文件）→ exit 3 点名重建。
4. `perf_run_in_container` 的语义不变（内层调用在真镜像里，文件在）。

## 边界

- 只碰 `grant:` 三个文件；不改红线数值、不动 `--host`、不动锁；
- 不 push；不改 `docs/team/**`。

## Deliverables

- 实现 + 翻转证据 + 报告 `docs/team/reports/M69-dev.md`。

## Acceptance

```sh
TEAM_PERF_PINNED_CONTAINER=1 bash skills/teamsmith/tests/perf.sh --in-container   # 宿主：exit 3
bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?                     # 不受影响
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
