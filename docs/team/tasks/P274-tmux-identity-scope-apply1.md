# P274 · tmux 身份作用域：apply-1（写侧 + 审计）

task: P274
agent: dev2
phase: apply
category: code
change: tmux-identity-scope
specs: pm-lifecycle, boundary
deltas: -
branch: task/P274-tmux-identity-scope-apply1
deps: P268（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/tmux-identity-scope-proposal.md`）

## 范围（apply-1：写侧 + 审计）

按 `openspec/changes/tmux-identity-scope/` 的 design §1 与 §3 落笔，五个裁定点我已全部按你的推荐裁掉（A 两个 capability / B 加会话 `-e` 身份 / C 选 **A1** 日志目标 fallback / D 独立夹具 + 接入 §32 / E 保留 doctor 只读残留行）。

1. **写侧**：产品面 tmux 调用收进包装；**建对象动词**（`new-session`/`new-window`/`split-window`/`respawn-*`）在子进程环境里摘掉整个 `TEAM_*` 命名空间；**kill 类保留身份**（闸门 `allowed-owned` 绑在它上面，且 kill 类不可能启动 server）；只读动词按你的简单规则统一。接入点：`common.sh`、`cmd-watch.sh`、`cmd-agents.sh`、`cmd-draft.sh`。
2. **B**：`new-session -e` 写四个身份变量到**会话**作用域。
3. **C/A1**：`shim/tmux` 在 `$TEAM_TMUX_CALLS_LOG` 缺席时按 cwd 解析日志目标到该项目 `state/tmux-calls.log`（约 10 行）；`boundary` 的 MODIFIED 由本批兑现。
4. **新夹具** `tests/tmux-identity-leak.sh`（私有 socket + 私有 fixture 项目，`--all/--select`、末行 ✓/✗、四条红侧）+ 红侧 1（写侧根因）与 4（审计）。

## 写集串行（硬要求）

`tests/smoke.sh`、`tests/section-budgets.tsv`、`tests/section-paths.tsv` 此刻由 **P264（门禁瘦身删改）** 在写。所以：

- **先做产品面与独立夹具**（上面 1–4 里除 §32 接线以外的全部）；
- **等 P264 落地**（我合并它之后会通知你，或你看到 main 里 §32 的断言已经瘦身完成）**再合并 main、再做 §32 接线与预算行**；
- 交付前逐条看「本次相对 main 的删除行」（P261 的教训：分支落后 main 会静默退回别人的成果）。

## 红侧（逐条给「破坏 → 红点名 → 还原 → 绿」）

1. **写侧根因**：私有 socket 无 server + 带身份与 pin 的 shell → `team up` → `tmux show-environment -g` 里**零个**本项目 `TEAM_*`；同一 server 上项目 B 的 pane 里也没有。翻转：把建对象调用改回带环境 → 红。
2. **审计**：pin 缺席时，从项目目录过闸门的一次调用 → 该项目 `state/tmux-calls.log` 恰好 +1 行；从非项目目录 → 哪里都不写。翻转：去掉 fallback → 红。
3. **不许削弱**：kill 类保留身份 ⇒ §31c/§6i 的 `allowed-owned` 断言必须仍绿（若它们红了，说明你把 kill 类也洗了——改回来，不要改断言）。

## 边界

- 不碰：读侧归因（apply-2 的面）、`cmd-project.sh` 的 doctor 行（apply-2）、帮助面/面板/账本。
- 不许新增措辞类断言（D170）；说明行（本批没有）用稳定短语 + 行为红侧。
- 不合并、不推送；做完 `team notify pm`。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/tmux-identity-leak.sh --all
bash skills/teamsmith/tests/tmux-lint.pl --selftest
bash skills/teamsmith/tests/smoke.sh --select 31c,32,6i     # 既有身份/闸门段不许回退
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
