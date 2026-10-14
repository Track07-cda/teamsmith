# P251 · 回合通知合并：apply

task: P251
agent: dev3
phase: apply
category: code
change: turn-notice-merge
specs: notify-and-inbox
deltas: notify-and-inbox
branch: task/P251-turn-notice-merge-apply
deps: P250（提案已 ACCEPTED；判定与两条 PM 注记见 `docs/team/reviews/turn-notice-merge-proposal.md`）

## 范围

按已接受的 `openspec/changes/turn-notice-merge/`（proposal / design 十条决策 / tasks §1–§6 / `specs/notify-and-inbox` delta）实现**全部条目**，逐条以 tasks.md 为准，本条不重述。三条 PM 注记要在实现里保住：

- 汇总行 = 最后一条事件的行 + 首事件时间戳 + 字段区 `×N first= last=`；**单事件行与今天逐字节相同**；
- 只有**写新行**才叫醒；合并的 settle 不叫醒；knock 去重身份换成**行身份**；
- **先明细、后合并判定**（`×N` = 该 run 在明细里的记录数）；`--detail` 只读、不 ack、缺文件/被轮转/记录不全要**点名缺口与非零退出**。

## 边界

- 只碰 design 的落点：`extension/team-notify.ts`、`scripts/lib/**`（收件箱写入口 + `team inbox --detail`）、`scripts/lib/cmd-config.sh`（新键登记）、`references/config.md`、`tests/bg-ledger-harness.mjs`/`tests/bg-ledger.sh`、`tests/section-paths.tsv`（必要时 budgets）、`smoke.sh` 的既有段。
- 不改：敲门传输机制、巡检叫醒键（P174）、挂起判定（P236 的 `cwd` 归属）、`[manual]`/`[draft]`/`[nudge]`/pulse 行、`team reply`（已归档）、canonical specs。
- 不许删/skip 断言换绿；新跳过要有点名的理由。
- **与 P249 的串行**：两边都会改 `smoke.sh` 与两张 `section-*.tsv`。交付前 `git merge main`，冲突按**双方保留**（各是新段/新行）解决并重跑选段自检；**语义冲突**（不是两段各自追加）就 `BLOCKED:` 给 PM。
- 不合并、不推送；做完 `team notify pm`。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail,wake,suspend-shape,owner-scope
bash skills/teamsmith/tests/bg-ledger.sh --select flip
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**：tasks §1.4/§2.3/§3.2 三组逐条（去键比较、跨类合并、取第一条的值、穿行重写；删明细落盘、越界不轮转、`--detail` 静默空输出、`--detail` 会 ack；每 settle 入队 knock、摘要文本当去重键、写失败仍叫醒），每条给「破坏→红（点名）→还原→绿」。

## 交付

`docs/team/reports/P251-dev3.md`（逐条 tasks §1–§6 对照、命令与 rc、十一条红侧的前后证据、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验（V33）。
