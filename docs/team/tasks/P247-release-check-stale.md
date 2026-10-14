# P247 · 发布检查跟上 routing 之后的形状：tag 选法 + init 路线参数

task: P247
agent: dev
phase: apply
category: infra
change: -
anchor: none (infra) — 发布前检查工具的判据修正，不改产品行为
branch: task/P247-release-check-stale
deps: -

## 两个缺陷（PM 2026-10-14 实测）

`bash docs/team/tools/release-check.sh` 在 main 上现在是 **通过 21 · 失败 4**。四条里**没有一条**是「树有问题」，但工具因此说「发布前检查未通过」，等于失去了信号价值。逐条：

### 一、三条 tag 失败（`最新 tag（v1.42.0）≠ package.json（0.1.2）` / `不是 HEAD 的祖先` / `HEAD 领先 645 个提交`）

根因：工具用 `git tag --sort=-v:refname | head -1` 取「最新 tag」，本仓保留着 **29 个改写前（filter-repo 之前）的旧 tag**（`v1.31.0…v1.42.0` 等，最近一个是 2026-09-19），它们**不在** HEAD 的历史上（`git merge-base --is-ancestor` 为假）。版本序里 `1.42.0 > 0.1.2`，于是「最新 tag」永远是那个旧 tag——**这个判据在改写后的仓里恒假**，与 0.1.2 发布时的表现一致（当时我看到的是同一形态，只是没深究）。

**要求**：
1. 取「最新 tag」时**只看 HEAD 的祖先**（例如 `git tag --merged HEAD --sort=-v:refname | head -1`，注意 annotated tag 要解析到 commit 再判）。
2. 另加一条**异常提示**（不是红，也不改判定）：若仓里存在**不在 HEAD 历史上**的 tag，打印计数并点名前几个，附一句「不要 `git push --tags`（会把它们指向的旧历史推进公开仓）」。理由：本仓真有这 29 个，而清单第 4 节的原写法正是 `--tags`（PM 已改，但工具该能提醒）。
3. 红侧：在 scratch clone 里造一个**版本更高但不在 HEAD 上**的 tag → 「最新 tag」仍取可达的那个、判定不假红；再让 HEAD 与可达的最新 tag 错位一个提交 → 该条按原意变红。

### 二、`team init 失败`（安装路线第 3 条）

根因：工具第 274 行运行 `"$INST/prefix/bin/team" init`（**无参数**），而 routing 合并之后 `init` 要求 `--task-models` 与 `--pm-model`（没有默认模型可猜），于是它按设计拒绝 → 路线判失败。

**要求**：按新合同传入参数（例如 `--task-models 'infra=opencode-go/deepseek-v4.1-flash' --pm-model 'opencode-go/deepseek-v4.1-flash'`，用**发布包里的** `team`），并断言新形状确实成立：项目里 `.pi/skills/{teamsmith,teamsmith-init}` 与源树**逐字节相同**、项目内 `team help` 退出 0、以及 `.pi/team/config.sh` 里出现 `TEAM_TASK_MODELS`/`TEAM_PM_MODEL`（而不是退休键）。红侧：把参数去掉 → 该路线必须红（今天就红，正好当对照）；再把 `--pm-model` 的值写错成不存在的形状 → 若工具不做形状校验就如实记（不要求加校验，但要说清现状）。
**不要**改 `install.sh` 的隔离方式（它已用 `HOME="$INST/home"`，是对的；PM 早先手动跑它才动过真实共享软链，工具本身没问题）。

## 边界与纪律

- 只改 `docs/team/tools/release-check.sh`（必要时它的自测夹具部分）；**不改**产品代码、`publish-public.sh`、`.gitignore`、`RELEASE-PUBLIC.md`（清单 PM 已改）。
- `--self-test` 必须仍是 **4/4**；若你的改动让某条自测变异不再被抓住，补齐夹具并说明。
- 不 push、不建 tag、不删 tag（**不要**去删那 29 个旧 tag——那是仓库状态，留给用户决定）。

## 验收（贴真实输出）

```bash
bash docs/team/tools/release-check.sh                 # 期望：唯一红是「HEAD 领先可达的最新 tag v0.1.2 N 个提交」；另有一条旧 tag 异常提示
bash docs/team/tools/release-check.sh --self-test      # 期望 4/4
git diff --check && git status --short
```

（可选，若有网）`bash docs/team/tools/release-check.sh --remote`。

## 交付

`docs/team/reports/P247-dev.md`（两条缺陷的复现、改动、红侧前后证据、自测结果、未做项——特别是「旧 tag 是否该由用户删掉」这一句留给 PM/用户）；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
