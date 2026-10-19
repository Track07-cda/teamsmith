# P317 · 清掉「说不出名字的吞错」：从 `common.sh` 开始

task: P317
agent: dev2
phase: apply
category: code
change: -
anchor: none (infra) — 代码纪律（AGENTS.md「no non-stick code」）
deltas: -
branch: task/P317-swallowed-errors-common
deps: 无

## 用户裁定

> 「现在的模型…「不粘锅」型的代码风格…都要尝试给自己免责。我不希望代码中过度测试过度的验证。」→ 「**做**」
PM 已把纪律写进 `AGENTS.md`：**不许吞掉说不出名字的错误**；`|| true` / `2>/dev/null` / `if fail then :` 只允许在「失败是预期的、并在注释里点名」处使用。

## 范围：只做 `skills/teamsmith/scripts/lib/common.sh`（6,415 行）

1. **先交清单**（不许先改）：文件里每一处 `|| true`、`2>/dev/null`、以及等价吞错，逐条给：
   `行号 → 原文 → 它吞的是什么失败 → 处置（删 / 留+一行理由 / 换成显式处理）`。
   分类判据：**失败是预期的吗？能否用一句话点名？**——能 → 留+理由；不能 → **删**（让失败显形）。
2. **按清单改**。**行为不变**：被删的吞错如果其实是承重的（例如 `set -e` 下需要继续），改成**显式**处理（`if ! cmd; then warn "…"; fi`），不是换成另一种吞。
3. **留下的每一处**都要在**同一行或上一行**写明理由（中文，一句话）。

## 验收

```bash
# 前后的数字（写进报告）
rg -c '\|\| true' skills/teamsmith/scripts/lib/common.sh
rg -c '2>/dev/null' skills/teamsmith/scripts/lib/common.sh
# 行为不变：相关选段
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
**红侧（两条，必须自己造）**：挑 2 处你**删掉**的吞错，让底层命令真失败 → 现在必须**报出来**（stderr 一行 + 非零，或明确的警告行），而**不再**静默继续。
报告：清单表 + 前后数字 + 两条红侧原始输出 + 「哪些留、为什么」。
