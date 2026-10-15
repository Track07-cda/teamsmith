# P285 · 补齐 `orphan-visibility` 的三项缺口（清单 1.1 / 4.2 / 7.5）

task: P285
agent: dev-bob
phase: apply
category: code
change: orphan-visibility
specs: seat-visibility
deltas: -
branch: task/P285-orphan-gaps
deps: P276（已并入 main）、V42（独立复验 PASS）、P284（清单已勾，这三项留空）

## 背景

P284 按证据勾清单时留空三项（`openspec/changes/orphan-visibility/tasks.md` 的 1.1 / 4.2 / 7.5），因为**已提交的证据里找不到任务书点名的东西**。核查记录与理由在 `docs/team/reports/P284-dev-bob.md` 的「留空的 3 项（真缺口）」一节。**它们是真缺口，变更因此不能归档。**

## 要做什么（三项，各自带证据）

1. **1.1 的第三段证据：一次普查的 fork 数与耗时读数。** 任务书那句「**先一次 `ps -eo pid=,args=` 筛候选再读 `/proc`**」需要一个能证伪的读数。做法建议：夹具里用一个 **`ps` 垫片**（把 `ps` 换成本项目夹具路径、记下被调用次数）跑一次普查 → 断言 **`ps` 恰好被调用一次**、并把耗时打进夹具输出；另造一个反例（把实现改成每个 pid 调一次 `ps`）→ 必须红。（若你找到更直接的判据，用它并在报告里说明为什么。）
2. **4.2 的 flip 臂**：`TEAM_ORPHAN_SCAN=0` 与开启各跑一次 `team ps`，断言**既有每一行逐字节相同**（容量行/存活块/模型表/会话块/窗口列表）；再加一条变异臂：把普查读数插进**容量行**→ 必红。任务书点名的变异与点名的断言要真正对上（P284 报告说现在对不上）。
3. **7.5 的文档**：`skills/teamsmith/references/config.md` 补新键的说明（`TEAM_ORPHAN_SCAN`，含默认值与「关掉它会发生什么」）；`skills/teamsmith/references/troubleshooting.md` 补一段「孤儿进程是什么、怎么清、为什么默认不清」（**若既有章节已覆盖则不新增章节**）；**不重写** `team help` 的既有页面。

## 边界

- 产品代码只在「必须让 1.1 的读数可测」时才动，且**不改行为**（改了就在报告里点名并给红侧）。
- 写集串行：`seat-visibility.sh`/`section-*.tsv`/`smoke.sh` 可能被在飞任务动；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我。
- 改完**自己勾上那三项**（行末写你的证据指针），并把 `tasks.md` 的三处 `[ ]`→`[x]`。
- 不合并、不推送；做完 `team notify pm`。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/seat-visibility.sh
bash skills/teamsmith/tests/seat-visibility.sh --flip
grep -rn 'TEAM_ORPHAN_SCAN' skills/teamsmith/references/ | head
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
