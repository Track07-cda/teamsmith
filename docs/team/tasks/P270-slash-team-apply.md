# P270 · `/team` 斜杠命令：apply

task: P270
agent: dev
phase: apply
category: code
change: slash-team
specs: extension-slash, init-skill
deltas: -
branch: task/P270-slash-team-apply
deps: P265（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/slash-team-proposal.md`）

## 范围

实现已接受的 `openspec/changes/slash-team/`（proposal 的四个裁定点我已全部按推荐版本裁掉：全量进正文+保险丝、剥离三个环境变量、加 doctor 一行、安装默认软链）。合同以 change 目录为准，本任务书只重申准入条件：

1. **白名单与表外拒绝照写**：`up`/`--fresh-pm`、`dispatch`、`say`、`notify`、`close`、`teardown`、`config set`、门禁族、`review`、`change`、`archive`、`bg`、`add-agent`、`init`、`bootstrap`、`draft`、`outbox`、`inbox`、`thread`、`monitor`、`pr`、`gh` 一律拒绝并指路终端；`up` 由专门那条要求拒绝（会重启这个会话）。
2. **红侧一条不许少**（design §3.8 三层各自）：改坏表 → 菜单红；剥离列表清空 → 环境断言红；拒绝分支短路 → 拒绝断言红；桩退出非 0 → 必须有 error 通知与非 0 退出码；`sendMessage` 改 notify → 正文断言红；安装层缺/软链/副本/冲突/`--force`/`--no-skills` 逐格。
3. **门禁接线**：新段进 `smoke.sh`；`section-paths.tsv` 覆盖新文件与 `extension/team.ts`；`section-budgets.tsv` 一行**有实测 band**（不许留空——P234 踩过）。
4. **写集串行**：与在飞的 P266（面板普通话）会同时改 `smoke.sh` 与两张 tsv；交付前 `git merge main`，冲突按**双方保留**，语义冲突停下报我。
5. **合并前自查**（P261 的教训）：逐条看「本次相对 main 的删除行」，确认删的都是你自己的改写，不是 main 上别人的成果。
6. 语言：今天一份中文，不写没有开关可证伪的语言场景。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/slash-team.sh                 # 纯逻辑层（假 pi）
bash skills/teamsmith/tests/slash-team-e2e.sh             # 端到端层（真 pi RPC + 桩）
bash skills/teamsmith/tests/install-shape.sh              # 安装层（含扩展组）
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P270-dev.md`（逐条 requirement 对照、命令与 rc、三层红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。
