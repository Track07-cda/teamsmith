# M35 · smoke 抖动清查：attempts state=idle（两连）与 M25-② 对照组（一见）

```
task:   M35
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M20 M33      # 计时硬化与哨兵已落地；这是残余抖动点收尾
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

门禁可信度的残余侵蚀点（wolf-cry 风险——假红多了真红会被放过）：

1. **attempts state=idle 断言（已两次假红）**:
   - 第一次：P18 B2 复验（`/tmp/review-P18`，~12:0x，红一次、同 tip 复跑转绿）;
   - 第二次：M34 复验（`/tmp/review-M34`，今天，红一次）。
   断言形态：`smoke.sh` 某段要求 `pm-start-attempts.log` 含 `state=idle`——疑似 PM 启动证据的
   写入时机与读取断言竞争。
2. **M25-② 对照组断言（一次）**:M30 复验时「夹具有效性：对照组脚本起来了」红过一次（`/tmp/.../m25-control.out`
   找不到），复跑转绿。
3. 已修的不在本范围：27-d/26-m（M20 多次取中位+裸等轮询化）、11e 冒充（M32 探针自 detach stdin）、
   bg6 $TMP 消失（M33 哨兵已装，再发生会有证据）。

## 任务

1. **定位**两条断言的等待机制（它们大概率还是「固定窗口赌时机」或「单次采样」），换成与 M20 同族的
   条件轮询/多次采样；每条给出**为什么会抖**的一句话机制说明。
2. **负载下不抖**：在人为加压环境（比如并行跑另一套 FAST smoke 或 `stress-ng`/`yes` 占几核）连跑 10 次
   相关段，0 红才算修完；报告附计数。
3. smoke 里若还有同类「单次采样赌时机」的断言，列清单（本任务只修上面两条+同函数内的直接亲属，
   其余进报告作后续清单）。

## Boundaries

- 只动 smoke.sh / tests/；不动产品代码；不改断言的**判据语义**（修的是等待方式，不是放水）。
- tmux 纪律照旧（#1250）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 加压 10 连跑 0 红的证据 + 翻转（改回旧等待方式 → 加压下复现红）
```

## Report

`docs/team/reports/M35-dev2.md`。
