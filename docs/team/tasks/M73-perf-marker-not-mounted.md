# M73 · perf.sh：镜像标识文件不得是挂载点（堵住 M64 的"挂载伪造"）+ 信任边界成文

```
task:   M73
agent:  dev
issue:
change: perf-suite-split
specs:  verification#The performance suite is separate, self-describing and non-blocking
phase:  apply
anchor: change
deltas: -
grant:  skills/teamsmith/tests/perf.sh · skills/teamsmith/references/troubleshooting.md（信任边界段落）· skills/teamsmith/tests/smoke.sh（仅必要时）
deps:   M66 · M69（均已合并）· M64（F2 第三轮 BLOCKED = 本任务输入）
status: todo
budget: 半个工作块
```

> 本地模式：不 push。

## verify 的第三轮伪造（M64 F2，PM 已复核成立）

```
foreign image marker absent                         → exit 0（夹具有效性）
foreign image + 调用者挂载公开 token + ENV=1         → 自称「参考环境」→ 3 green; exit 0
```

token 写在公开的 `ci/Containerfile` 里，谁都能挂载一份同内容文件 → M69 比对的是"内容"，
证明不了"来自钉死镜像的 rootfs"。

## PM 的信任边界裁定（照此执行，并写进文档）

- **在范围内（必须可见拒绝）**：一切**非故意**误用——裸宿主直跑（M66 ✓）、宿主导出变量（M69 ✓）、
  陈旧镜像（M69 ✓）、内容被改（M69 ✓）、**挂载伪造（本任务修）**；
- **范围外（不可能也不需要防）**：调用者**控制容器运行时、故意**把公开 token 烘进自建镜像。
  容器内自检有硬上限——这是"自述可信"对抗意外，不是对抗一个拥有运行时的人的"证明"。
  判定输出仍带完整环境自述，可疑结论的**复核**永远能看来源。

## 修法（小，按这个形状）

1. **标识文件不得是挂载点**：`--in-container` 的校验加一条——解析 `/proc/self/mounts`（或 `findmnt`），
   若 `/etc/teamsmith-gate-image` 是挂载目标 → exit 3 并点名「标识文件是挂载的，不是镜像烘焙的」。
   （真镜像里它在 overlayfs 上，不是独立挂载；套件自己的 wrapper 只挂 /work，不挂它。）
2. **翻转（红→绿原始输出）**：verify 的原样伪造（foreign image + 挂载正确 token + ENV=1）→ **exit 3**；
   真镜像（重建）→ 绿；顺带复跑 M66/M69 的三条旧翻转（裸宿主 / 宿主导出 / 内容被改）不许回退。
3. **文档**：`references/troubleshooting.md` 的 inotify/perf 相关段补一段**信任边界**（上文 PM 裁定原话，
   精简版）：什么拒、为什么不防"自建镜像烘 token"，以及复核时怎么看环境自述。

## 边界

- 只碰 `grant:` 三个文件；不改红线数值、不动 `--host`、不动锁；
- 不 push；不改 `docs/team/**`。

## Acceptance

```sh
TEAM_PERF_PINNED_CONTAINER=1 bash skills/teamsmith/tests/perf.sh --in-container   # 宿主：exit 3
bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
