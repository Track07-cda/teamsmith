# P330 · 删掉从不被调用的夹具（P328 动作 3）

task: P330
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — 用户：「不要过度的测试」「移除不必要的过度测试」；P328 清点实测 127 个夹具里 54 个不可达
deltas: -
branch: task/P330-unreachable-fixtures
deps: P328 已裁定（`docs/team/reports/P328-dev-bob.md` 末节「PM 裁定」）

## 做什么

删掉**门禁、CI、`scripts/**`、`docs/team/tools/**` 都不会调用**的夹具文件（P328 实测 52 个、约 11 284 行，扣掉下面排除项），并同步删 `tests/loop-inventory.tsv` 里属于它们的行。这是纯减法：**不许新增任何夹具、检查器、预算表、规格条文**。

## 排除项（一条都不许删）

- `panel-b2.sh`（P318 写集）
- `panel-b3.sh`、`flip-m33.sh`（`openspec/specs/verification/spec.md` 的两条 scenario 点名，删它们要 spec delta）
- `panel-p21.sh`（P318 的 D-3 正在改）
- 任何出现在 `references/*.md`、`SKILL.md`、`openspec/**`、`docs/team/tools/**` 里的夹具名 —— **先列名单给我**，不要自己判断

## 四条硬约束（来自 PM 裁定）

1. **零引用证据**：每删一个，报告里给「文件 → 行数 → 扫描命令 → 零引用输出」。删完再扫一遍，剩下的引用数必须是 0。
2. **`loop-inventory.tsv` 同步**：被删文件的行同时删，删完 `bash skills/teamsmith/tests/smoke.sh --select 0e` 必须绿（`--loop-check` 不许红）。
3. **文档点名先报**：第 4 项排除项里的名字先给我，别删。
4. **两条反例**：随机挑 2 个被删夹具原本能造红的场景，用门禁里对应的段跑一次，证明那个行为今天仍被抓住（红→绿或「破坏→该段必红→还原」）。

## 报告要说清的三件事

- 开头一句结论（删了多少文件、多少行、剩多少不可达）。
- **「这批删掉的是从不执行的翻转/深水夹具；它们守的行为现在由 X 段自带红侧承接」** —— 逐段点名 X。
- 诚实边界：删掉后失去的能力是什么（重跑历史变异），以及哪些历史事故因此只剩「报告 + 归档变更」这个证据——**这份清单我要看**。

## 验收

```bash
bash skills/teamsmith/tests/smoke.sh --select 0e
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
openspec validate --all --strict
git diff --check && git status --short
```

不要跑整套门禁（P326 正在改 `smoke.sh`，同一棵树两个写者会互相干扰）；选段用 `section-select.sh --paths` 取段号。冻结后通知 PM，换人独立复核「删的都是真不可达」。
