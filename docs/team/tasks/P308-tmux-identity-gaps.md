# P308 · `tmux-identity-scope` 清单留空的三项：先修 F1′，§32 接线等 P297

task: P308
agent: dev2
phase: apply
category: code
change: tmux-identity-scope
specs: pm-lifecycle, verification
deltas: -
branch: task/P308-tmux-identity-gaps
deps: P307（勾选已并入；三项留空与两条观察见 `docs/team/reports/P307-dev2.md`）｜P297（在飞，写集冲突，见下）

## 一、现在做（不碰 `smoke.sh` / `section-budgets.tsv` / `section-paths.tsv`）

**1. F1′（必修，真缺口）**：`tmux-identity-leak.sh` 的收口判 `PASS==0 && FAIL==0 → exit 77`，而隔离断言会给 2 个 ✓，于是「全跳过」永远不触发。现场（你自己复现的）：tmux 解析得到但 `-V` 失败 → `--all` 打 `✓8 ✗0 · 跳过 7 段` 且 **rc=0**。

**改法**：收口改成按**段数**判——「**所有段都被跳过**（或没有任何段真正跑过）→ `rc=77`」，**不看 `PASS`**；只要有一段真跑过，才按该段的 pass/fail 判 rc。**红侧**：① 现在这个现场（假 tmux、全跳过）必须 **rc=77** 并打印一行「跳过不是通过」；② 把收口改回 `PASS==0 && FAIL==0` → 必须**再次 rc=0**（证明修的是判据）；③ 正常环境（有 tmux）→ rc=0 且有段真跑（不许把正常情形误判成跳过）。

**2. 3.2 的 16 条过期豁免**：按你报告里的判断处理（删清单行或补回文件），并在报告里给前后计数。

**3. 观察留档**：3.1 的隔离断言在**本 worktree 是空集**——报告里写明「它的牙在独立克隆上（V56 做过）」，并**不要**为了让它在本树有牙而改断言（那是假的）。

## 二、等 P297 落地后再做（我会另派 P309，或你在这条里等我通知）

**1.6 §32 接线**：`smoke.sh` §32 调用新夹具；`section-budgets.tsv` 的 §32 行按**实测**重填；`section-paths.tsv` 的 §32 patterns 补 `skills/teamsmith/scripts/lib/common.sh`。**理由**：P297 正在改 `smoke.sh`（版本感知），两条同时改同一文件会冲突——按单写者纪律串行。

## 验收（第一部分）

```bash
bash skills/teamsmith/tests/tmux-identity-leak.sh --all      # 正常环境
bash skills/teamsmith/tests/tmux-identity-leak.sh --flip 2>/dev/null || true
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
交付后写报告、notify pm；**§32 那部分不要动**。
