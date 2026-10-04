# E8 · explore: harness 能力探测 + 后台任务完成通知插件（pi 扩展形态）

```
task:   E8
agent:  verify
issue:  
change: -            # explore 阶段不指名 change；若结论是要做，提案阶段再建
specs:  -
phase:  explore      # 纯探索：只产报告，不改代码
deps:   -
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/verify` 工作树即可，PM 复验后本地合并。

## Context

起因：PM 把长门禁（~6 分钟的 `team review`）放后台 tmux 窗口跑，引出「后台任务完成后没人知道」的窟窿。用户拍板方向：**用插件形式解决**；并指出 ① 初始化时要考虑用户用的 harness——有的 harness（用户点名 oh-my-pi）本身就支持后台任务，那时一些依赖/机制就不必自建；② init 时应能给 pi 用户推荐安装后台任务类扩展。

现状：pi 官方文档明说**不内建 background bash**，出路是扩展或 tmux；teamsmith 已有一个扩展 `extension/team-notify.ts`（回合结束→收件箱+敲门），通知通道是现成的。PM 的垫底方案（若插件路不通）：后台任务登记台 + pulse 每拍检查完成。

## 要回答的问题（每个都要有证据；实测优先，不接受纯推理）

1. **oh-my-pi 是否真支持后台任务**：它是什么、后台任务 API/交互长什么样、完成如何通知启动它的 agent？（web 检索 + 若能装上就实测；装不上就引官方文档原文。）
2. **pi 扩展能力边界**：读 pi 文档（`docs/extensions.md`、`docs/custom-tools` 相关）回答：扩展能否 ① 注册一个自定义工具（如 `bg_run`）② 在命令完成后**主动**向会话注入消息/唤醒（team-notify.ts 的回合结束钩子证明了什么）？给最小可行形态。
3. **生态检索**：有没有现成的 pi 后台任务扩展可直接推荐（oh-my-pi 体系或其它）？有则评估「推荐安装」vs「自写」。
4. **harness 探测放进 init/doctor**：设计 init 时的能力探测清单（harness=pi？装了什么扩展？模型配置？），以及探测到/探测不到后台能力时各自的行为（推荐安装文案 / 退回登记台+pulse 方案）。
5. **与 teamsmith 的接口**：worker 用插件跑后台时，「回合结束不许有未收割后台作业」的规则如何被插件执行或提示？PM 的后台复验（`team review`）走插件后长什么样？
6. **推荐方案与工作量**：插件自写（fork/参考 team-notify.ts）还是推荐现成扩展；分阶段落地（先 PM 侧用还是 worker 也用）；风险。

## Deliverables

1. `docs/team/reports/E8-verify.md` — 探索报告：6 个问题逐条带证据的回答、推荐方案、工作量估计。
2. 只读探索（装扩展做实验可以，但只能装在沙盒/自己的测试配置里，不动 PM 与各 agent 的运行配置）。

## Boundaries (do not do)

- 不改 `skills/**` 实现；不建 OpenSpec change；不动别的项目。
- 检索证据给原文引用，不转述印象。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 每个结论附证据（文档原文 / 实测输出）
```

## Report

Write it to `docs/team/reports/E8-verify.md`（格式参照 `docs/team/reports/E6-dev2.md`）。
