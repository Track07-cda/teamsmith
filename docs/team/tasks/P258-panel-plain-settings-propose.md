# P258 · 设置页只用普通话说人话（去掉内部行话、审计与测试开关）

task: P258
agent: dev-bob
phase: propose
category: analysis
change: panel-plain-settings
specs: panel
deltas: panel
branch: task/P258-panel-plain-settings-propose
deps: -

## 用户的反馈（原文，2026-10-14）

> 这些都是什么语言？派单记录？为什么设置菜单里面要有记录？审计根本没有用，也看不懂，去掉！不要用你自己的一套简写的语言，什么"手改"
> 这里测试旋钮又是什么玩意儿？还有什么内部接缝？
> 不要在界面中包含任何黑话

（两张截图是 Pulse 面板的**设置页**：一张显示「实际派单记录（只读）」逐席位列出 `没有完整派单记录: legacy/unknown assignment_version`、一段「审计（最近）」的原始行 `… result=ok actor=cli key=TEAM_AGENT_MODELS old='…'`；另一张显示「依赖策略: 手改 .pi/team/config.sh」「测试旋钮: 磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用」「测试旋钮（M53）：…，记录标 forced=1」等。）

## 现状（PM 已定位，你复核）

- 设置页把三类**内部信息**渲染成了普通用户会读到的行：① 每个席位的派单记录（含内部诊断字串 `legacy/unknown assignment_version`）；② 配置审计的原始行（含 `actor=cli`、`key=TEAM_…`、旧值）；③ 只给测试夹具用的开关（`TEAM_MEMINFO_FILE`、`TEAM_INBOX_WATCH_FORCE_FAIL`、`TEAM_IW_REQUIRE_WATCH` 等）。
- 字符串表里有我们自己的简写：`settingsRefusedRoute: '只读键：手改 .pi/team/config.sh'`、`settingsAssignmentHint: '只读：实际模型来自已提交的派单记录…'`、`settingsGroupAssignments: '实际派单记录（只读）'`、`settingsAuditHeading: '审计（最近）'`（`scripts/panel/src/strings/zh.ts` 191–231 行一带），英文表同形。
- 面板设置页**是用户可见的界面**；用户的标准很明确：**不懂这个项目的人也要看懂，界面里不许出现我们的黑话**。

## 要解决的（写进 delta 的合同）

1. **界面不许出现内部标识**：`TEAM_*` 之类的键名、里程碑代号（`M53` 这种）、内部诊断字串（`legacy/unknown assignment_version`、`actor=cli`、`result=ok`）、以及我们自己的简写动词（「手改」「只读键」这类）。判断标准写成可检查的：**界面可见字符串里不许出现**（a）匹配 `[A-Z][A-Z0-9_]{3,}` 的标识符（`PATH`、`HTTP` 这类通用大写缩写要怎么处理，你给规则并在 design 里说明）、（b）形如 `M<数字>` 的代号、（c）一份**禁用词表**（初始至少含：手改、只读键、派单记录、测试旋钮、内部接缝、旋钮、接缝、依赖策略、机器路径；英文对应 hand-edit、knob、seam、assignment record、policy …——词表要可扩、放在数据文件里、由夹具读）。
2. **测试开关不上界面**：只服务于夹具/自测的配置项**在设置页里根本不出现**（今天它们还带着「（测试）」的标签出场）。它们的读取与 CLI 行为不变；要看它们就 `team config list`，界面不承担这件事。
3. **审计不上界面**：设置页不再渲染审计行。审计本身保留（那是配置写入的凭据，`team config log` 仍可读），只是不再出现在界面里。design 要写明「为什么它不该在界面」——它是给排障的人读的原始记录，不是设置的一部分。
4. **诚实性用普通话表达，不许丢**：旧的「策略 vs 实际」区分有真实用途（防止把「下一次派单会用哪个模型」当成「正在跑的席位用的是哪个模型」）。改成两句人话，例如「**下一次派单会用的模型**」与「**正在运行的任务实际使用的模型**」，并配一句普通话说明它们为什么会不同（任务一旦派出去，就固定用当时的模型）。**删掉的是黑话，不是这条区分**。同样，席位一行里如果是内部诊断，就换成普通话的原因（例如「这个席位还没有派过任务」）。
5. **不能改的项怎么提示**：设置页里有些值只能改项目配置文件。提示语要写成普通话的一句话（例如「这个值要改项目配置文件 `.pi/team/config.sh`，界面不能改」），路径本身保留（它是事实），但**不许**再出现「手改」「只读键」这类简写。
6. **两种语言都要干净**：面板有中文与英文两套字符串，两边都要过同一套判据（英文里也不许出现 `knob`/`seam` 这种我们的内部词）。
7. **可检查**：给一个新的夹具组（面板字符串判据）：① 可见字符串命中禁用词表 → 红并点名键与词；② 命中 `M<数字>` 代号 → 红；③ 命中 `TEAM_*` 形态的标识符（按你定的规则）→ 红；④ 设置页渲染结果里出现审计行或测试开关 → 红。**红侧**：往 zh 与 en 各注入一个禁用词 → 各自红；把审计块加回渲染 → 红；还原后全绿。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 范围限于**面板设置页与它的字符串表**（`scripts/panel/src/strings/{zh,en}.ts`、设置视图的渲染、以及承载「哪些键上场」的清单）。**不要**顺手改面板其他页的文案，也不要改 CLI 的帮助（那是 P252 的面）与 CLI 的报错文案（那是 P254 的面）——那些各自有主。
- 不许削弱既有断言：`panel-strings` 的双语覆盖与对比度检查、快照审查等照旧；新增判据是加严。
- 不合并、不推送；做完 `team notify pm`。
- **排期**：todo（席位空出来再派）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P258-dev-bob.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
