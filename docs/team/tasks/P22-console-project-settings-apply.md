# P22 · apply: `console-project-settings`（控制台里改项目契约）

```
task:   P22
agent:  verify
issue:  
change: console-project-settings
specs:  panel, memory-and-deps
phase:  apply
deps:   -            # 提案已由 PM 验收：docs/team/reviews/console-project-settings-proposal.md（ACCEPTED，已在 main）
status: todo
budget: 分批推进（tasks.md 的 B1…B4），每批一提交；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`。

## 前置（先读，别跳）

1. `openspec/changes/console-project-settings/`：`proposal.md` / `design.md`（11 条决策是你的实现口径）/
   `tasks.md`（**B1…B4 就是实施计划**，每批带夹具与翻转）/ `specs/{panel,memory-and-deps}/spec.md`。
2. `docs/team/reviews/console-project-settings-proposal.md`：PM 的验收记录（含复审结论）。
3. 一句话范围：**一个加固后的底层写入口 + 一个校验过的门面（`team config list|set|log`）+ 控制台里的
   项目设置视图（含按席位模型编辑）**。

## Deliverables

按 `tasks.md` 的 B1…B4 分批实现，每批：实现 + 该批夹具 + 翻转 + 重建 `panel.js`（改了面板就要重建）+ 提交。

| 批次 | 内容（以 tasks.md 为准） |
|---|---|
| B1 | 加固 `team_config_set_in_file`（保留注释/顺序、不粘行、引号按值形态、原子写 + `bash -n` 复核） |
| B2 | `team config list|set|log`：schema（class/kind/form/default/danger）、sha256 CAS、值校验、审计行 |
| B3 | 控制台项目设置视图：键列表 + 过滤 + 编辑（走 P20 的编辑键位）+ 生效徽章（apply/restart 文案 + 命令） |
| B4 | seats 块：按席位模型编辑（`team config set-agent-model`）+ 来源三态（与 `team ps` 同口径）+ `refuse` 类只读展示 |

## Boundaries

- **不许改 pi 的更新检查行为**（用户明确指令：不要关掉自动更新检查）；若你的夹具遇到 pi 的更新横幅，
  按 M45 的判据层思路容忍它，**不要**用 `PI_OFFLINE` 之类开关绕开。
- 不动 `.pi/team/config.sh` 的键名/语义，不引入第二份配置来源；`state/panel.conf` 仍只放面板偏好。
- 别碰 M45（`extension/team-inbox-watch.ts` 与 outbox 判据）、M40（身份/spawn）的语义。
- `smoke.sh` 只追加自己的段落，别重排他人的；测试纪律照旧（私有 tmux socket / 破坏性调用进容器）。
- 面板性能契约不变（<1% 单核、首帧 <2s）：项目设置的读取走已有数据块机制，别在渲染路径上读文件或起进程。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
外加**五条手工实录**（贴输出）：
1. `team config set TEAM_PULSE_INTERVAL 300` 后：注释与未改动行**逐字节保留**、`bash -n` 通过、审计行在；
2. 用**外部进程**在编辑器打开期间改文件 → 提交被拒（指纹不符），文件未被覆盖；
3. 值校验：`TEAM_PULSE_INTERVAL=0` 与未知键/未知席位各自被拒（点名原因）；
4. 面板：项目设置视图能开、能过滤、能编辑并落盘；`refuse` 类只读且给出正确命令；
5. seats 块：改 `dev` 的模型 → 运行中的窗口参数不变、receipt 说明下次生效；来源三态与 `team ps` 一致。

## Report

`docs/team/reports/P22-verify.md`：按 requirement 的覆盖表 + 每批翻转（red→green）+ 独立包路径。
