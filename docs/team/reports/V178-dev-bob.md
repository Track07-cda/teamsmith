# V178 · 看板新增帮助独立复验

agent: dev-bob   status: PASS（候选及合并后定点复验）   time: 2026-11-19T02:39:27Z

branch: `task/V178-board-add-help-verify`   PR/MR: -

**候选 `f4a4395544c39c848176560b31640ade212709c1` 和合并版 `ec0ad9706fea4f97c00bb0083455201a5eabfa29` 的定点复验均通过。** 候选的英文和中文帮助都显示必填标题；旧版帮助正常退出，却都过不了同一条标题检查。按新版用法在隔离项目新增并读回一行，标题、负责人和依赖均与输入一致。合并版产品文件与候选相同，实际英文帮助仍显示修正后的用法。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reviews/P475.md`、`docs/team/reviews/P475-verify.log` | 当前为 `dev-bob` 执行的合并后记录，`ec0ad9706`，PASS。候选中央原件已由 PM 另存。 |
| `/var/tmp/v178-dev-bob-MyR9Gn/` | 候选与合并后的检查脚本、帮助原始输出和 `review` 命令输出，以及候选阶段的隔离看板前后数据；保留至 PM 接收。 |

## OpenSpec assessment

`change: -`，没有独立提案、设计或规格增量可验。按 `openspec/specs/help-surface/spec.md` 的 `Every behaviour a help page states is declared and probed` 对照现有要求，仅评估 P475 涉及的一条用法。

| Dimension | Assessment |
|---|---|
| Completeness | 对照 `2ac59d49`，除作者报告外只改 `skills/teamsmith/scripts/strings/commands.tsv:56`；差异仅在 `board add` 的用法插入 `<title> [agent] [deps]`。 |
| Correctness | 中英文均由实际 CLI 显示新用法。同一条标题检查在旧版退出 1、候选退出 0；新增并读回的行验证 `cmd-docs.sh:66–78` 所读取的参数实际写到了对应列。 |
| Coherence | 两种语言各自把旧页面的新增用法替换成新用法后，和候选页面逐字节相同；既有解析器、其它用法、语言表与规格均未修改。 |

## Findings and final assessment

- CRITICAL 0 · WARNING 0 · SUGGESTION 0：限上述定点验证。
- 未实跑 `--allow-dup` 或省略可选参数的分支、其它看板操作、整组帮助、全量检查或 OpenSpec 全库校验；任务只要求核对帮助并实跑一条普通新增。不接触真实项目看板、运行中的 Pulse 或模型。
- 合并后只核对产品文件并运行一次默认英文帮助；旧版对照、中文帮助和新增记录只在候选阶段运行。

## Verification evidence

`TEAM_LANG` 在派单环境未设置，项目 `.pi/team/config.sh` 也未设置或引用该键。实际默认组以 `env -i` 启动且不传 `TEAM_LANG`；中文组显式传 `TEAM_LANG=zh`。四次帮助 stderr 均为空。

```text
$ GIT_OPTIONAL_LOCKS=0 TEAM_GATES='bash /var/tmp/v178-dev-bob-MyR9Gn/check.sh' bash skills/teamsmith/scripts/team review P475 --dir /var/tmp/p475-review-f4a43955.YMSPRi --branch f4a4395544c39c848176560b31640ade212709c1
✓ review checkout: /var/tmp/p475-review-f4a43955.YMSPRi @ f4a439554（分支 f4a4395544c39c848176560b31640ade212709c1，干净）
✓ 门禁输出：docs/team/reviews/P475-verify.log（PASS，3s）
✓ 复验记录：docs/team/reviews/P475.md（PASS）
# exit 0；候选检出执行前后均无未提交或被忽略的文件。
```

实际命令在 `/var/tmp/v178-dev-bob-MyR9Gn/project` 执行，使用的命令入口是候选检出的 `skills/teamsmith/scripts/team`：

```text
$ team board add V178TEST 'Verify board help title' reviewer PREP1
✓ board add V178TEST
# exit 0
$ team board row V178TEST
| V178TEST | Verify board help title | reviewer | - | PREP1 | todo |
# exit 0
# 原看板加上这条预期记录，与实际写入的看板逐字节相同（cmp exit 0）。
```

Ledger ban（在 V178 工作树运行）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=2885 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Flip evidence

旧版取自 `git archive 2ac59d495aacccba4a8017b999311af9dae8ed34 skills/teamsmith/scripts`，未改候选检出。两种语言各自用了同一条 `grep -Fx` 标题检查；旧版返回 1 的原因是完整用法行没有 `<title>`，不是 CLI 启动失败。

```text
# 2ac59d49 · team board --help（默认英文 / TEAM_LANG=zh）
  board add <ID> [--allow-dup]
# 两次帮助 exit=0；标题检查均 exit=1。

# f4a43955 · team board --help（默认英文 / TEAM_LANG=zh）
  board add <ID> <title> [agent] [deps] [--allow-dup]
# 两次帮助及标题检查均 exit=0；除新增用法这一行外，页面逐字节相同。
```

## Decisions and deviations

- 无。V178 只提交本报告；未修改候选或合并检出，未推送、未自行合并、未发布。

## 合并后核对 · 2026-11-19T02:39:27Z

在 PM 提供的新独立检出上，候选到合并版的 Git 差异只涉及 `docs/team/`；另外用 `cmp` 将合并检出中实际使用的 `skills/teamsmith/scripts/strings/commands.tsv` 与候选提交的文件逐字节对照。默认英文帮助只运行一次，stderr 为空。中央记录已更新；原始英文页面及命令输出分别保留为证据目录下的 `merged-default.stdout` 和 `merged-review-console.log`。

```text
$ GIT_OPTIONAL_LOCKS=0 TEAM_GATES='bash /var/tmp/v178-dev-bob-MyR9Gn/check-merged.sh' bash skills/teamsmith/scripts/team review P475 --dir /var/tmp/p475-merged-ec0ad970.xfpZfe --branch ec0ad9706fea4f97c00bb0083455201a5eabfa29
merged=ec0ad9706fea4f97c00bb0083455201a5eabfa29 clean (including ignored files)
no tracked changes from candidate outside docs/team (git diff exit=0)
commands.tsv byte-identical to candidate (cmp exit=0), blob=9176f7f5f487893801645387e6c2d7b30564a44a
merged-default exit=0
teamsmith · board — read and write the board rows
  board add <ID> <title> [agent] [deps] [--allow-dup]
merged-default title assertion exit=0
merged checkout still clean (including ignored files)
✓ 门禁输出：docs/team/reviews/P475-verify.log（PASS，1s）
✓ 复验记录：docs/team/reviews/P475.md（PASS）
# review exit=0
```
