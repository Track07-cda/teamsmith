# M44 · 门禁守卫：受版本控制的文件里不许有冲突标记

```
task:   M44
agent:  verify
change: -
specs:  -
phase:  -
deps:   -            # 与 P20 都在改 smoke.sh：只在文件里**追加**你的段落，别动别人的
status: todo
budget: 半小时级
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`。

## 为什么要做（2026-09-19 PM 自伤事故）

PM 合并 M43 时 `git merge --squash` 报冲突（`references/troubleshooting.md`），PM 用
`git add -A && git commit` 直接提交 —— **把 `<<<<<<<` / `=======` / `>>>>>>>` 冲突标记一起写进了 main**。
是 PM 随后自查发现的（`grep -rln '^<<<<<<<'`），已 amend 修正；但**门禁本身没有任何一条断言能抓住它** ——
下次任何人（含 agent）犯同样的错，都可能把标记留在被保护分支上。

## Deliverables

1. `skills/teamsmith/tests/smoke.sh` 新增一段（建议放在静态检查族，段号自选，避免与 P20 的段落冲突）：
   **受版本控制的工作树文件里不得出现冲突标记**。判据用 `git grep`（只扫已跟踪文件，排除 `.git`、
   `.worktrees`、二进制）匹配行首的 `<<<<<<< `、`=======`（整行）、`>>>>>>> ` 三件套；
   命中就红，并把**文件:行号**打出来。
2. 夹具（必须可证伪）：
   - 绿色侧：当前树全绿；
   - **红色侧（翻转）**：在临时仓库里造一个带三件套的文件并提交 → 断言必须红并点名该文件；
     把文件清干净 → 回到绿。翻转脚本走 `skills/teamsmith/tests/flip-*.sh` 的既有形状。
3. 文档：`references/protocol.md`（或 troubleshooting）里一句话写清「合并/解冲突后门禁会拦冲突标记」。

## Boundaries

- **只追加**：不要重排/改写既有段落编号与他人的段落（P20 也在动同一个文件）。
- 不要用绝对路径调 tmux；测试纪律照旧（私有 socket / 破坏性夹具进容器）。
- 判据必须只扫**已跟踪**文件（未跟踪的临时文件里有标记不算问题）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/flip-m44.sh     # 你写的翻转脚本：红→绿
```

## Report

`docs/team/reports/M44-verify.md`。

---

## 附注（PM）：你工作树里有一处未提交的旧证据

`.worktrees/verify` 里 `docs/team/reports/M39-verify.md` 有 14 行未提交改动 —— 那是 M39 的 **(c3)** 增补
（在含 M36 shim 的最新 main 上复核 M39 的修）。M39 已关闭，但这段证据有价值：请**先单独提交它**
（`docs(team): M39 report — (c3) addendum on the post-M36 main`），再做 M44 的正式改动，不要混在一个提交里。
