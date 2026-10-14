# P265 · 在 Pi 里提供 `/team` 斜杠命令（用户常用命令 + 状态读取）

task: P265
agent: -
phase: propose
category: analysis
change: slash-team
specs: extension-slash
deltas: -
branch: task/P265-slash-team-propose
deps: 用户 2026-10-14 确认的范围（见下）

## 需求来源与已确认的范围（用户原话）

> Sometimes pm agent inform me that I can run some `team` command if I need to do something with it. It could be better to provide slash commands in pi like `/team pulse up`.
> B，你需要筛选放进来的命令，不要机械的放入。把通常用户常用的放入，以及状态读取等放入。
> （`team up` 那条被用户自己否掉：能在对话里输入说明 PM 在跑，斜杠命令就在那个会话里；PM 崩了就没处输入。）

**结论**：在 Pi 项目扩展里注册 `/team`，处理函数**调用真正的 `team` CLI**（起子进程，不是重新实现），把输出贴回对话。

## 放进来的清单（用户确认过）

- **读取**：`status`、`digest`、`ps`、`board`、`reply list`、`reply show <n>`、`config list`、`version`、`doctor`、`meeting inbox`、`meeting read <名>`
- **用户会亲自动手的操作**：`pulse up|down|status`、`config upgrade-models ...`（`--yes` 原样保留）、`meeting say ...`、`meeting close`

**不放进来**：`up`/`--fresh-pm`（PM 会话自身；用户已否）、`dispatch`、`say`、`notify`、`close`、`teardown`、`config set`、`smoke`/`gate`/`perf`、`review`、`change`、`archive`、`bg`、`add-agent`、`init`、`bootstrap`、`draft`、`outbox`、`inbox`、`thread`、`monitor`、`pr`、`gh` 等（PM 与席位的工具）。判断标准：会写账本/会起进程/会改配置/是 PM 工作的，不进。

## 你要产出的东西

一个 OpenSpec change（新能力 `extension-slash`，或落既有能力并说明理由）：proposal/design/tasks + delta。至少覆盖：

1. **扩展与安装**：`.pi/extensions/team.ts` 由安装脚本或 `team init` 生成（随团队技能走）；`registerCommand("team")`；处理函数 spawn `team <args>`、收输出、贴回对话。
2. **白名单机制**：上面那份清单是数据（哪条进、哪条不进）；不在清单的拒绝并说明「这是 PM 的命令，请到终端执行」。**单真源**：清单写在一处，`/team`（无参）列出的可用项就从同一份清单渲染。
3. **安全边界**：它只是命令行的**前门**——命令行自己的拒绝守卫（写配置要 `--yes`、派单守卫、容量）原样继承；扩展一条命令都不重新实现；命令是用户亲手输入的（模型替用户做不了这件事）。
4. **输出位置**：一句话的结果用通知；多行输出进对话正文；命令的退出码要映射清楚（失败要看见、不能把失败吞成成功）。
5. **已知的两个坑写进红侧**：① `up`/`--fresh-pm` 等会重启/新建 PM 会话的命令，在「正在和 PM 对话的会话里」要明确拒绝并说明（不能让我重启我自己）；② 长命令与开窗口的命令不在清单里（故没有「卡住对话」的问题——清单里的都很快）。
6. **红侧**：白名单外的命令被拒并点名；清单里某条执行失败 → 结果里看到非零退出与输出；`/team` 无参列出两组清单且与数据一致；两条语言（若有语言层，配合 P260）各一份样张。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 与 P260（帮助面）的关系：如果帮助面落地了语言层，`/team` 的输出跟随它；若没有就先中文。design 写清依赖方向。
- 不改 `team` CLI 本身（它只是被调用）；不改面板。
- 不合并、不推送；做完 `team notify pm`。
- **排期**：todo（席位空出来再派）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P265-dev.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
