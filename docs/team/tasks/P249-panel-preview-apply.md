# P249 · Pulse：写信槽与只读预览（apply）

task: P249
agent: dev2
phase: apply
category: code
change: panel-preview-and-compose
specs: panel
deltas: panel
branch: task/P249-panel-preview-apply
deps: P248（提案已 ACCEPTED，判定与两处裁定见 `docs/team/reviews/panel-preview-and-compose-proposal.md`）

## 范围

按已接受的 `openspec/changes/panel-preview-and-compose/`（proposal / design / tasks / `specs/panel` delta）实现**全部条目**，逐条以 tasks.md 为准，本条不重述。要点：

- **草稿生命周期**：`App.tsx` 的结算改成「先写盘、写成功才清内存」；`delivered`/`queued`（含 busy）/`held`（含 `unconfirmed`）→ 清空；`error` 类（无 durable 结果）→ 保留并点名；**写盘失败不许假装清掉**（输入行仍留着、回执点名文件）。
- **只读预览**：`team __panel-data --block detail` 增加显式 `--source spec|change|decision`（三类发现集、`--file` 只许取发现出来的路径、非法 id/越界/软链拒绝并点名、128 KiB 上界与消毒沿用、缺目标给空清单 + 可读原因而不是空文档当成功）；决策切片按 id 标题到下一个同级或更高级标题（同 id 的更深一级补记留在正文里）。
- **入口**：工作页第 2 页的变更/规格/决策块**行**接入既有可聚焦集合与绘制序（板行 + 这三类行），`enter`/点击开同一详情视图；`Esc`/`q` 原地返回，`q` 在详情打开时不收缩控制台（已文档化的例外）。
- **不改机器出口**：`--print`/`--json` 不因预览多读一字节或变一个字段；打开/关闭预览对机器帧除时间戳外逐字节不变。

## 边界

- 只碰 design 的 Impact 列出的路径（`scripts/lib/cmd-watch.sh`、`scripts/panel/src/**` 与重建的 `panel.js`、`tests/panel-b2.sh`、`tests/panel-b3.sh`、`tests/panel-b3-stub.sh`、`tests/panel-snapshots.sh`、`tests/smoke.sh` 的详情读者段与必要的 tsv 登记）。
- **不要**碰路由/派单/账本写入、`team reply`（已归档的另一个 change）、`openspec/specs/**` 的 canonical（delta 由归档落地）。
- 不许删/skip 断言换绿；快照变动要逐条说明「能被新增入口/source 解释」；新跳过必须有名有理由。
- 不合并、不推送；做完 `team notify pm`。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')   # 按改动算闭包，别手挑段号
bash skills/teamsmith/tests/panel-b2.sh --all
bash skills/teamsmith/tests/panel-b3.sh --all
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧一条不许少**（design §7 的十一条，逐条给红→还原→绿）：结算清空（拿掉 `updateDraft('')` 或 `clearDraft` 任一调用）、`error` 类保留、`held` 是结算、**写盘失败不假装清掉**（草稿文件置只读）、三个 source 的发现集与顺序（删判据回落 / 凭空补 tab）、拒绝集（越界路径、跨 source、非法 id、软链）、决策切片边界（少切补记 / 越界切片）、上界与消毒（200 KiB 规格 + 带 `ESC[2J` 的变更文件）、空块无死项、一页一行序（跨块断掉或两个光标）、机器出口不变。

## 交付

`docs/team/reports/P249-dev2.md`（逐条 tasks.md 对照、命令与 rc、十一条红侧的前后证据、快照逐帧说明、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验（V33）。
