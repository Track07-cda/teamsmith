---
id: P449
title: delivery-final-wake-integrity 实施
agent: dev
category: code
phase: opsx-apply
change: delivery-final-wake-integrity
specs: notify-and-inbox background-jobs pm-lifecycle
anchor: openspec/changes/delivery-final-wake-integrity/proposal.md
deltas: notify-and-inbox, background-jobs, pm-lifecycle
branch: task/P449-final-wake-apply
---

# P449 · 实施通知归属、最终唤醒与 PM 对账

## 依据与分工

最终提案 `2b66af2f` 已接受。阅读 change 全部规划、V155 报告和 `docs/team/reviews/delivery-final-wake-integrity-proposal.md`。你未参与提案，执行 tasks 1.1–3.2；4.1/4.2 由另一非作者复验，不由你勾选。

## 必做

1. `.job` 同时记录 `session_cwd` 与执行 `cwd`；归属只看发起身份并继续验证 pid/starttime。旧记录仅在 cwd 精确匹配席位工作树时按 legacy 接受，独立 clone、相对/他人/缺失路径不归席位。
2. CLI 合并键只给 delivered 增加 tip：不同 delivered tip 新行并各唤醒一次；同 tip 重复合并；suspended/interrupted 不用 tip 拆行；suspended→delivered 新行。无戳发送者保持既有合并边界。同步 `references/protocol.md`。
3. 复用 `bg-ledger-harness.mjs` 替换旧用例：独立 clone 作业 suspended→最终 delivered 一次唤醒；不同 delivered tip 各一次，同 tip 一次，suspended 进度不敲；其他席位不受影响。保留 §13c 点名的 owner-scope 用例名，负向身份断言放该用例，正向独立 clone 放自己的用例。
4. 同步 `templates/pm-prompt.md.tmpl`、`SKILL.md`、`references/workflows.md`：通知优先、文件为准；旧 tip/无新通知/merged 不证明未完成；准备重复同一等待状态前用 digest/BOARD/任务分支报告/git log/status 对账；不读屏、不代跑复验。
5. 不新增通知系统、定时轮询、配置或人工双发。

## 验收

- `bg-ledger.sh --select owner-scope,merge,wake,flip` 及 §13c、真实通知 §12b-pi；删除发起身份区分或 delivered tip 边界必须按名变红，恢复后绿。
- 一次性隔离 PM 两场景：报告已提交但唤醒缺失时读文件识别交付且不重复等待/不代跑；作业仍运行时不误报完成。旧提示若也能正确处理，不伪称反向证明。
- `openspec validate --all`、spec-refs、section-select、账本禁令、diff check；不跑全量/夜间/61b。

## 交付

小步提交，`docs/team/reports/P449-dev.md` 先给结论，附真实记录、合并/唤醒计数、指引场景、红/绿/恢复和未跑范围。通知 PM 后由非作者复验；不合并、不归档、不发布。
