# P254 · 拒绝信息说人话：`team up` 的身份拒绝与「（只负责 PM）」

task: P254
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — 只改用户可见的拒绝信息与标题，不改判据
branch: task/P254-refusal-plain-language
deps: -

## 缺陷（用户 2026-10-14 实测报回，原文照录）

```
$ team up
teamsmith up · <项目>（只负责 PM）
✗ PM launch identity missing/changed（含 suffix）；先保留 BOARD/threads/reports 磁盘交接，再 team up --fresh-pm；不改 Pi 历史
```

用户的两个问题：「**什么是只负责 PM？**」「**这个报错也很难懂**」。两句都成立：

1. **`（只负责 PM）` 没有任何解释**（`cmd-watch.sh:158` 的 `team_hdr`）：它只是「这次 `up` 不拉起席位（席位要 `--agents`）」的范围说明，用户读不出这层意思，还容易以为「PM 只负责 PM」是某种降级。
2. **身份拒绝没有说清是什么、为什么、怎么办**（`common.sh:2624`）：PM 的启动身份记录（`state/pm-launch.env`：`model` 与 `resume_key`）与当前解析不一致时拒发。信息里没说是**哪一个**字段、**记录里是什么**、**现在解析成什么**、也**没区分「记录缺失」与「记录变了」**——而这两种情形的处境完全不同（前者常见于 0.1.x 升上来的项目，记录这套东西是新版本才有的；后者常见于改了 `TEAM_PM_MODEL` 或 PM 模板）。

## 要求

1. **`team up` 的标题**：把范围说明写成读得懂的话（例如 `teamsmith up · <项目>（本次只恢复 PM；席位要加 --agents）`），并保证不与其他 `up` 输出里的说法冲突。
2. **身份拒绝分两种情形，各自给全信息**：
   - **记录缺失**：明说「我从没记录过这个项目的 PM 是怎么启动的（记录文件 `<路径>` 不存在）」，解释为什么需要它（避免把**一场用模型 A 开的对话**当成模型 B 续下去——这是 R6/OBS1 那条合同），并给两条**并列**出路与后果：
     · `team up --fresh-pm`：开一场新对话（磁盘上的 BOARD/threads/reports 就是交接；Pi 历史**不动**，旧会话文件留在原处）；
     · 「想续上一场对话」时：要么把 PM 模型改回记录里的那个（若还能取到），要么按工具给出的**补记录**方式声明——见第 3 条。
   - **记录与当前解析不一致**：打印**两边**的值（`记录 model=… / 现在 model=…`，`记录 resume_key=… / 现在 resume_key=…`，并把 suffix 显式标出来），指出**是哪一处变了**，再说后果与两条出路。
3. **补记录要有正式入口**（今天只能手写文件——我就是这么做的）：提供 `team up --adopt-pm-identity`（名字可换，但必须是**显式、有审计**的动作）：按当前解析写出记录（`model`/`resume_key`/`mode=continued`）、打印「我声明这次续跑的身份是 X」、写一行审计；**拒绝**在记录已存在且不一致时静默覆盖（要先 `--fresh-pm` 或先 `--adopt-pm-identity --yes` 明示）。这条同时把「用户自己修记录」从「手写文件」变成「有据可查的一条命令」。
4. **红侧**（各给破坏/还原或前后对照）：
   - 记录缺失 → 信息里必须出现记录**路径**、`--fresh-pm`、以及「Pi 历史不动」；把「缺失」与「不一致」两种信息混成一条 → 红；
   - 记录不一致 → 信息里必须出现**两边**的 model 与 resume_key（夹具把两边设成不同值，断言两个值都在输出里、并点出哪一处变了）；
   - `--adopt-pm-identity` 在记录已存在且不一致时**不加 `--yes`** → 必须拒绝并点名；加 `--yes` → 写入 + 审计一行；写入后 `team up` 能续跑（夹具证明）；
   - 标题：断言 `up` 的标题里出现「只恢复 PM」与 `--agents` 提示（不要只断言字面，断言这两个词）。
5. **不变量**：判据本身一字不改（什么时候拒、拒的依据）、退出码、`--print` 的机器输出（除新增字段外）都不变；`--adopt-pm-identity` 是**新增**入口，不改 `--fresh-pm` 的既有语义。

## 边界

- 只碰 `scripts/lib/cmd-watch.sh`（`team_cmd_up` 的标题与拒绝分支）、`scripts/lib/common.sh`（身份判据的信息文本 + 新入口的判定）、必要的 `cmd-project.sh` 帮助行、以及夹具/登记。
- 与 **P252（help 分级 + 语言层）** 的分工：P252 管**帮助页**，本任务管**运行时的拒绝信息**；两者都改用户可见文本，所以**不要**互相改对方的文件：`cmd-watch.sh`/`common.sh` 归本任务，`cmd-project.sh` 里的 `team help` 段归 P252。若两边都要碰 `cmd-project.sh` 的同一段，先 `BLOCKED:` 给 PM。
- 不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
- **排期**：本任务在我方队列里是 todo（等现有席位空出来再派）；任务书先写好，免得用户报的第二遍。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

外加一段**端到端现场**（报告里贴）：在临时项目里分别造「记录缺失」与「记录不一致」两种情形，贴出各自的完整输出；再用 `--adopt-pm-identity --yes` 修好缺失那种并证明 `team up` 能续跑。

## 范围调整（PM 2026-10-14，用户要求「启动时自动升级」之后）

- **「缺记录 → 默认自愈」这一半已并入 P256（`startup-self-heal`）**：`team up` 在记录缺失时会自动登记本次启动身份并打一行说明；本任务不再实现那一半，避免两处同时改 `team_pm_identity_guard`。
- **本任务保留的两件**：① 拒绝信息说人话（记录**存在但不一致**时打印两边 model/resume_key、写明 suffix、说清两条出路与后果）；② `team up` 的标题写成「本次只恢复 PM；席位要加 --agents」。另加一件由 P256 交过来的接口确认：自愈那行说明的措辞与它在 `--print` 下的行为（不写盘但要预告）要与 P256 的 delta 一致——先读 P256 的 delta 再动手。
- **实现要排在 P256 落地之后**（同一批文件，单写者）。
