# P276 · 孤儿进程可见性：apply

task: P276
agent: dev3
phase: apply
category: code
change: orphan-visibility
specs: seat-visibility, boundary, board-and-status
deltas: -
branch: task/P276-orphan-visibility-apply
deps: P269（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/orphan-visibility-proposal.md`）

## 范围

实现已接受的 `openspec/changes/orphan-visibility/`（新的 `seat-visibility` 能力 5 条 + `boundary` 的 `team reap` + `board-and-status` 的一条 MODIFIED）。合同以 change 目录为准；tasks.md 的 0–9 节就是实施顺序。

## 准入条件（PM 复核时点名的，逐条自查）

1. **写集串行**：`tests/smoke.sh` 与两张 tsv 此刻归 **P264**（门禁瘦身）与 **P274**（tmux 身份）。**先做产品面与独立夹具**；等它们落地后再 `git merge main`、再做门禁接线与预算行；合并前逐条看「本次相对 main 的删除行」（P261/P266 都踩过静默回退）。
2. **不许用 pattern 信号**：`team reap` 只接受显式 pid 或 `--orphans` 的计划；`pkill`/`killall`/名字匹配一律不许出现。红侧要证明「名字像但不是那个 pid」不会被杀。
3. **跨项目零点名**：读数里出现别的项目的 pid/项目名/席位名/路径 → 红。**PM 会在真实机器上跑一次**（本机确实有别人的孤儿），看输出能不能安全抄进本仓账本。
4. **只读性质**：`status`/`ps` 的新读数不写盘（既有「状态哈希前后不变」断言不许回退）；`team reap --orphans` 不带 `--yes` 一个信号都不发。
5. **四条红侧逐条跑出来**：① 形状判据换成「命令行提到 agent 路径」→ 假阳性必红；② 判据改成「不是当前窗口的 pane」→ 在跑的席位被误判；③ 拿**默认 server** 的 pane 表比对 → 私有 socket 的活席位被误判；④ server 查询不到就「算孤儿」→ 未判定用例必红。每条给「破坏 → 红点名 → 还原 → 绿」。
6. **契约键**：新开关按四面登记（schema 表 + `templates/config.sh.tmpl` + `references/config.md` + 面板标签 `strings/{zh,en}.ts` 的 `label_<KEY>`），`tests/panel-strings.mjs` 的双向走查必须绿（这是 startup-self-heal 那次的教训）。
7. **帮助面**：新命令 `team reap` 的一页写进命令清单（`strings/commands.tsv` + `help.{en,zh}.tsv`），并让 `routes.sh` 的 Walk A 覆盖到它（用法行必须被真解析器接受）。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/seat-visibility.sh          # 新夹具（名字按你实现）
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P276-dev3.md`（逐条 requirement 对照、命令与 rc、四条红侧前后证据、**真实机器上的一次读数**（跨项目只报总量的形态）、未做项）；不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。
