# P72 · 手工 `team notify` 把发送者记成 `pm`（审计面）· `notify-sender-identity`（propose）— 交付报告

agent: verify   status: delivered（propose 完成，等 PM 提案审查；本阶段不写实现）
time: 2026-09-22T20:35Z
branch: `task/P72-notify-sender-pm-propose`（local 模式：分支留在 `.worktrees/verify`，不 push）   PR/MR: -
change: `notify-sender-identity`（phase=propose，owner=verify；deltas=`notify-and-inbox`）
brief: `docs/team/tasks/P72-notify-sender-label.md`
tip: 本报告的父提交为 `f95667eb`（`c81a2316` proposal+delta → `1e4a8443` design+tasks → `deb6d27c` delta 措辞收紧 → `f95667eb` 取证包 → 本报告）

## Deliverables

| Path | 内容 |
|---|---|
| `openspec/changes/notify-sender-identity/proposal.md` | 提案：Why（55 条错标与 `cmd-agents.sh:1141/1148/1160` 的成因）/ What Changes / Capabilities / Impact / 本阶段与 apply 期的验收命令 / the flip（含实测红）/ Boundaries / 报告证据清单 |
| `openspec/changes/notify-sender-identity/specs/notify-and-inbox/spec.md` | delta：**1 条 ADDED** —— *A manual notification is attributed to its sender, not its recipient*（`--from` > M40 运行时目录 > 拒绝；`TEAM_AGENT` 不许赢过目录；四个归属面：durable 行 / 敲门文本 / outbox `from:` / 唤醒账本；两条路同一解析；7 个场景）；**1 条 MODIFIED（全文重述）** —— *A turn-end notification appends one inbox line and knocks once*（`<agent>` 改由运行时目录决定，窗口名只作对照，新增「worktree 而非 window 命名 sender」场景） |
| `openspec/changes/notify-sender-identity/design.md` | 实测红（三种运行时形状同一条 `agent:pm`）、信号与优先级表、被否掉的四个替代方案、归属面、跨路径一致化、兼容性与残余（适配器命令建议加 `--from {agent}`、历史行不重写）、可证伪方案与四条变异 |
| `openspec/changes/notify-sender-identity/tasks.md` | 一个 apply brief（B1 CLI 解析与归属面 → B2 扩展同一解析 → B3 跨路径一致性夹具 → B4 smoke 段与文档 → B5 flip/门禁/报告）+ 一个独立 verify brief + 覆盖表 + 路径授权 + 夹具纪律 |
| `docs/team/reports/P72-verify/probe.sh`、`logs/probe.log` | 只读取证包：临时项目里复现四种运行时形状的 sender 记录（不碰 tmux、不写本仓库） |
| `docs/team/reports/P72-verify/logs/{validate.log,trial-archive.log}` | 门禁输出 + `/tmp` 试归档输出（证明 MODIFIED 与 base 逐字匹配、可合并） |

## 验收命令（真跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict        # logs/validate.log
✓ change/notify-sender-identity
Totals: 30 passed, 0 failed (30 items)          # rc=0

$ PATH="$HOME/.bun/bin:$PATH" openspec status --change notify-sender-identity
Progress: 4/4 artifacts complete                 # proposal / specs / design / tasks 全 done

$ rm -rf /tmp/p72trialproj && mkdir -p /tmp/p72trialproj && cp -r openspec /tmp/p72trialproj/ \
    && (cd /tmp/p72trialproj && PATH="$HOME/.bun/bin:$PATH" openspec archive -y notify-sender-identity)
                                                 # logs/trial-archive.log（试归档只在 /tmp 里）
Applying changes to openspec/specs/notify-and-inbox/spec.md:
  + 1 added
  ~ 1 modified
Totals: + 1, ~ 1, - 0, → 0                       # rc=0 —— MODIFIED 的 requirement 名与 base 匹配、全文合并成功

$ bash docs/team/reports/P72-verify/probe.sh     # logs/probe.log（见下面「翻转证据」）
probe rc=0（脚本级 ✓；输出本身是预期的红）

$ git status --porcelain
（本报告提交前：仅 `docs/team/reports/P72-verify*` 未跟踪；提交后干净）
```

`proposal.md` 里列的 **apply 期**验收（`flip-p72.sh`、FAST+全量门禁）本阶段没有实现可跑，已逐条写进任务书 5.1–5.3；**未跑**，不假报。

## brief 四条逐条回答

**① sender 解析（取舍）。** 定案：`--from <name>`（显式声明，逐字记录、与目录不一致时 stderr 点名）> **M40 运行时目录**（主工作树 = `pm`；`<main>/<TEAM_WORKTREES_DIR>/` 下的工作树 = 该目录名，子目录里跑也算）> **解析不出就拒绝**（非 0、不写行、不排队，输出点名 `--from`）。`TEAM_AGENT` 永不覆盖目录（不一致时目录赢并点名）。**窗口名只作对照，不作权威**：headless 的适配器通知/脚本/门禁夹具根本没有 pane，窗口名是可改的 UI 状态，而工作树路径是派单时创建的；M40 已把「身份 = 运行时目录」定为规则（design §2 有完整取舍表与被否方案）。拒绝而不是回落 `pm`：假归属是账本事后无法分辨的假绿（`references/philosophy.md`），而拒绝有 `--from` 这条明路。

**② 审计后果。** delta 写明 sender 必须同时出现在**四个记录**：durable 收件箱行、敲门文本、outbox 条目的 `from:`（watcher 渲染成 `from <x>`、`delivered.log` 记录它）、唤醒账本；收件人仍是文件名与敲门目标。于是 PM 的 `inbox/pm.md` 不再出现「读起来像 PM 自己报的」行——修复后 worker 的行是 `[manual] agent:<worker> · …`，与 `[auto]` 行同形。历史 55 行**不重写**（重写会伪造它本身作为证据的账本），design §5 与任务 5.4 都写明了这一点。

**③ 一致性。** 两条路用同一条规则：扩展侧从 `window || basename(cwd)` 改为「cwd 所在工作树」（roster 名优先），窗口名只用来发现并记录不一致；MODIFIED 的 requirement 直接引用 ADDED 的那条规则，ADDED 里有一条「一个运行时上下文 → 两条路同名」的 MUST 和对应场景（B3 用故意错配的窗口 `dev` vs `.worktrees/dev2` 钉住）。

**④ 可证伪。** ADDED 的第一个场景就是 brief 的夹具形状（`TEAM_AGENT` 空 + worktree cwd → `agent:<worker>`；主工作树 → `agent:pm`），另有 `TEAM_AGENT=pm`、外部 worktree 拒绝、`--from` 声明、排队条目 `from:`、跨路径同名，ADDED 共 7 个场景（MODIFIED 另有 1 个）；`flip-p72.sh` 四条变异（sender 回退成收件人 / 解析不出回落 `pm` / 扩展回到 window 优先 / 去掉 `TEAM_AGENT` 守卫）各让对应场景变红（任务 5.1–5.2）。

## 翻转证据（红 → 绿）

**红（本树实测，可复跑）。** `bash docs/team/reports/P72-verify/probe.sh`（临时项目 + 清身份 + `TEAM_NOTIFY_TMUX=0`）：

```
== ① worker 窗口形状（cwd=.worktrees/dev，TEAM_AGENT 空） ==
rc=0 lines=0→1
last: - 2026-09-22T20:33:17Z [manual] agent:pm · P72 probe: worker summary
== ② PM 自己（cwd=主工作树） ==
rc=0 lines=1→2   last: … [manual] agent:pm · P72 probe: worker summary
== ③ 无法归类的工作树（cwd=项目外挂 worktree） ==
rc=0 lines=2→3   last: … [manual] agent:pm · P72 probe: worker summary
== ④ worker + 继承 TEAM_AGENT=pm ==
rc=0 lines=3→4   last: … [manual] agent:pm · P72 probe: worker summary
== 汇总 ==
agent:pm 行数 = 4 / 总行数 = 4
```

四种形状四条一模一样的行：worker 的报账被记成 PM 自己，外部 worktree 也照样成功并写成 `pm`。

**绿（未跑，不假报）。** 本阶段是 propose，**没有改任何实现**，所以绿侧不存在；它由 apply brief 落地后按任务 5.1/5.2 产出：同一条命令应变为 ①④ `agent:dev`、② `agent:pm`、③ rc≠0 且 `lines=` 不变，并附 `flip-p72.sh` 四条变异的红。

## 决策与偏差

- **范围比 brief 的最小面大一条**：brief 的四点都在 CLI 侧，但第 3 点「两条路同一解析」在扩展仍用 `window || basename(cwd)` 时只能靠巧合成立（窗口被改名、或会话从子目录启动时立刻分叉），所以 delta 的 MODIFIED 把扩展的 `<agent>` 解析也写进契约。这是对第 3 点的必要落点，不是顺手的重构：扩展的守卫（worktrees 前缀 / 非 PM 窗 / session 匹配）与写前顺序都不动。
- **`--from` 是声明不是凭证**：显式 flag 胜过目录并逐字记录（与 `TEAM_AGENT` 这种继承值相反）；不一致时 stderr 点名。理由：`--from` 解决的正是「目录说不出是谁」的场景，而 `TEAM_AGENT` 属于继承环境，M40 已判定它不许静默赢过 cwd。
- **拒绝而非回落 `pm`** 是行为变更（`team notify` 在无法归类的目录里会从 rc=0 变 rc≠0）：design §5 记为兼容性变更，并给适配器侧出路——`TEAM_AGENT_NOTIFY_CMD` 模板本就支持 `{agent}`，任务 4.2 把推荐命令改成 `… notify pm --from {agent} --from-file {summary_file}`。
- **不重写历史行**（见 ②）。
- **未动**：`team say` / `draft` / pulse 行的形状（tag 已写明发送者）、outbox/投递守卫语义、`.pi/team` 配置、`docs/team/tasks/P72-*.md`（PM 的只读文件）、主工作树与本仓库以外的任何路径。
- **组合检查**：只有本 delta 触碰 base requirement *A turn-end notification appends one inbox line and knocks once*（`grep -rln` 于 `openspec/changes/*/specs/`）；另外两个 open 的 `notify-and-inbox` delta 动的是 *Messages to a stopped agent fall back to the inbox*（`one-line-draft-judgement`）与 *Only fresh lines…* / *The ledger separates…*（`wake-delivery-idempotence`），不重叠。

## 建议下一步

- PM 在 `docs/team/reviews/notify-sender-identity-proposal.md` 做提案审查（ACCEPTED 才可派 apply）；任务书 5.1–5.3 就是 apply brief 的验收面，B1/B2 可并行、B3 依赖两者。
- 派 apply 的席位时记得 `deltas: notify-and-inbox`、`phase: apply`，并在 brief 里明授 `scripts/lib/cmd-agents.sh`、`extension/team-notify.ts`、`references/**`、`SKILL.md`（`tests/**` 本就是 dev 的）。
- 归档前建议重跑一次本文的试归档（`logs/trial-archive.log` 的命令），确认 MODIFIED 仍与 base 逐字匹配。
- `BLOCKED:` 无。
