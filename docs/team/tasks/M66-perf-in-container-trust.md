# M66 · perf.sh：`--in-container` 不得把宿主谎报成参考环境（perf-suite-split apply 返工）

```
task:   M66
agent:  dev
issue:
change: perf-suite-split              # apply 已合并 7135095；本任务是 M64 独立验证发现的 apply 侧缺陷返工
specs:  verification#The performance suite is separate, self-describing and non-blocking
phase:  apply
anchor: change
deltas: -                            # 不改契约文本；是让实现符合 R2「环境自述」的既有承诺
grant:  skills/teamsmith/tests/perf.sh · ci/Containerfile · skills/teamsmith/tests/smoke.sh（仅必要时加一条断言段）
deps:   M58（apply）· M64（verify，BLOCKED 报告 = 本任务输入）
status: todo
budget: 半个工作块
```

> 本地模式：不 push。

## 缺陷（M64 F2，PM 已独立复现）

```text
$ bash skills/teamsmith/tests/perf.sh --in-container      # 在宿主上直接跑
  模式          : container（参考环境：钉死镜像）（参考环境）   ← 谎报
  可见逻辑核数   : 32（nproc）                                ← 明明在宿主
```

`--in-container` 现在**只相信调用者的声明**（`MODE=container` 一进就当参考环境），没有任何
"我真的在钉死容器里"的证据。这正是我们信条里最坏的形态：**自述可以撒谎**——哪天 CI/发版流程把它叫错地方，
红绿都会被记在"参考环境"名下。

## 修法（按这个形状做，细节你定）

1. **可信信号**：钉死镜像在 `ci/Containerfile` 里 `ENV TEAM_PERF_PINNED_CONTAINER=1`（加一行，并写注释说明这是
   身份信号，不是调优旋钮）；
2. **`perf.sh --in-container` 必须校验信号**：信号缺失/不符 → **可见拒绝**（exit 3，点名"不在钉死容器里：
   要么进镜像跑，要么改用 `--host`（非参考环境）"），**绝不**继续以参考环境自居；
3. **真容器里不受影响**：CI 的调用形状（`podman run … bash -c '… perf.sh --in-container …'`）照常工作；
4. **宿主直跑的旧行为**变成红：上面那段 PM 复现命令现在要 exit 3 而不是自称容器；
5. **翻转证据**：造一次"信号被删/被改" → 红（给原始输出）；真容器里绿（有镜像就跑，没有就可见 SKIP 并说明）。

## 边界

- 只碰 `grant:` 里的三个文件；**不改红线数值**（2000ms / 1%）、不动 `--host` 语义、不动锁；
- `smoke.sh` 只在确有必要时加一条断言（优先把检查做进 `perf.sh` 自检，别动门禁结构）；
- 顺带检查 `perf.sh:215/248` 两处帮助/文档行与新语义一致（该改就改，别留着教唆直跑）；
- 不 push。

## Deliverables

- 上述改动 + 报告 `docs/team/reports/M66-dev.md`：修复前后两条命令的原始输出对比、翻转证据、
  真容器（或可见 SKIP）证据。

## Acceptance

```sh
bash skills/teamsmith/tests/perf.sh --in-container        # 宿主直跑：必须 exit 3 且点名原因
bash skills/teamsmith/tests/perf.sh --host >/dev/null; echo $?   # 宿主语义不受影响
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
