# P288 · 门禁锁抗外部删除：apply

task: P288
agent: dev3
phase: apply
category: code
change: gate-lock-external-deletion
specs: verification
deltas: -
branch: task/P288-gate-lock-external-deletion-apply
deps: P287（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/gate-lock-external-deletion-proposal.md`）

## 范围与硬约束

合同以 `openspec/changes/gate-lock-external-deletion/` 为准（D1–D7 全按你的推荐采纳）。**不许改**：发布路径的名字与语义、两把锁的顺序（先发布、后伴生）、「删锁/换锁 ⇒ 有界时间内一行点名 + 安全点停跑 + 退出码 2」、入场检查的拒绝语义、命名规则（点开头或带 ns）、六个 scenario 的方向。

**红侧逐条跑**（各给「破坏 → 红点名 → 还原 → 绿」）：① 删伴生锁 → 持有者一行点名并停；② 换一个同名新文件 → 察觉并点名**两侧身份**；③ 入场检查（造「活登记换过身份」的现场）→ 拒绝起跑；④ 等待者在文件被 unlink 时打印并继续等；⑤ **反例**：正常运行**不许**误报；⑥ 发布路径被删 → 只印不停（兼容声明那半）。

**写集串行**：与 P281（门禁锁卫生，第二轮复检在等）同族文件（`gate-lock.sh`、`smoke.sh`、两张 tsv）。交付前 `git merge main`；P281 的 `34`/`34b` 既有一字不许回退；**语义冲突停下报我**。

**不改**：判定 token、退出码集合、排队上限算式、`team_review_verdict` 的解析。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/smoke.sh --select 34c,34d
bash skills/teamsmith/tests/smoke.sh --select 34,34b
bash skills/teamsmith/tests/smoke.sh --select 0e
bash skills/teamsmith/tests/flip-p287-name.sh --self-test
bash skills/teamsmith/tests/flip-p287-lock.sh --self-test
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test && bash skills/teamsmith/tests/tmp-hygiene.sh --lint
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P288-dev3.md`（逐条 scenario 对照、命令与 rc、六条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由**没写过本变更**的席位独立复验。
