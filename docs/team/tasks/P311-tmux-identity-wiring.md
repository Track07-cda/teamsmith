# P311 · `tmux-identity-scope` 最后两格：基线冻结 + §32 门禁接线

task: P311
agent: dev-bob
phase: apply
category: code
change: tmux-identity-scope
specs: pm-lifecycle, verification
deltas: -
branch: task/P311-tmux-identity-wiring
deps: P274/P304/P308（已并入）｜清单只剩 `0.3` 与 `1.6`（见 `team change status tmux-identity-scope`）

## 两件

**1 · 0.3 冻结改动前基线**：在**改动前**的那棵树（`v0.2.0` 或 `tmux-identity-scope` 落地前最后一个提交，**点名它**）上跑 `tests/tmux-identity-leak.sh --all` 与 `smoke.sh --select 32`，把**原始输出**抄进报告；并证明它在**私有 socket、私有 fixture 项目**下跑、**没碰真实 server**（前后 `tmux list-sessions` 对默认 socket 的读数不变）。

**2 · 1.6 门禁接线**：`smoke.sh` §32 调用新夹具；`section-budgets.tsv` 的 §32 行按**实测**重填（`bash tests/section-select.sh --paths skills/teamsmith/tests/tmux-identity-leak.sh` 打印的段；预算＝实测 × 系数，与你改动前同一套规则）；`section-paths.tsv` 的 §32 patterns 补 `skills/teamsmith/scripts/lib/common.sh`。
**注意**：夹具刚由 P308 修好「**全跳过 → rc=77**」——接上后若机器上 tmux 不可用，§32 会**红**而不是假绿，这是**要的行为**；报告里请写一句「本机 tmux 可用」的证据（`tmux -V`）。

**红侧**：① 把 §32 从 `smoke.sh` 去掉 → `--select 32` 必须**不再跑**该夹具且选段审计能发现（`tests/section-needs-audit.sh` 或等价）；② 把 patterns 里的 `common.sh` 去掉 → 改 `common.sh` 时 §32 不再被选段器选中（必须红）。

## 验收

```bash
bash skills/teamsmith/tests/smoke.sh --select 32
bash skills/teamsmith/tests/tmux-identity-leak.sh --all
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
交付后把清单里 **0.3 与 1.6** 两格按事实勾上（带证据），写报告，notify pm。
