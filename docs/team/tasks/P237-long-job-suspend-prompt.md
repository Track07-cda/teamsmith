# P237 · long-job-suspend · B 刀：提示词与文档面（工人简报的三态合同）

task: P237
agent: dev
phase: apply
category: code
change: long-job-suspend
specs: dispatch
deltas: dispatch
branch: task/P237-long-job-suspend-prompt
deps: P230（A 刀已并入 main，V20 PASS）、P236（归属返工已并入 main，V22 PASS）、task-model-routing 已并入 main（S1/S2/S3，V19/V21/V23 PASS）

## 范围

实现 `openspec/changes/long-job-suspend/tasks.md` 的 **§4（4.1–4.4）**，唯一合同来源是该 change 的
`specs/dispatch/spec.md`（ADDED requirement「The worker prompt makes suspension on background jobs a third
legal turn end and teaches the lane by purpose」）与 `design.md` 决策 1。**不重述**这两处已写清的文本要求。

要点（照做，细节以合同与设计为准）：

- 4.1 `scripts/lib/cmd-agents.sh`：后台车道段整段重写为「起完结束回合、完成叫醒带回结果」的口径，
  原地等只作为**有界例外**（三条同时成立 + 给出内联等待预算数字）；「Never stop mid-task」段列出
  **恰好三种**合法回合结束状态（交付 / 硬阻塞 / 挂起等作业），并要求挂起时回合末行点名所有等待的 job id、
  不得写最终判定、不得报 `BLOCKED:`；补上「上一个会话的叫醒随进程消失 → 先看 `state/bg.log` 与 `team bg list`」
  的续跑指引。
- 4.2 `templates/AGENTS.section.md.tmpl` 纪律条同步三态一句话版；`references/protocol.md` 的通知小节与
  `references/workflows.md` §E2 写同一口径。**`templates/pm-prompt.md.tmpl` 的既有规则不许被削弱**（它是参考措辞）。
- 4.3 把 A 刀在 `tests/bg-ledger.sh` 里的用例按既有方式折进 smoke §13/§13c，一致性断言挂到 §6 dispatch 或 §13c；
  车道段注入条件（内置 Pi 或模板带 `{bg_ext}`）保持不变。
- 4.4 兜底夹具：挂起后**死亡的席位**命中既有巡检待办条款（「任务未完成 + 窗口不在」），不新增巡检条款。

## 边界

- 不碰 A 刀已并入 main 的两个扩展（`extension/team-bg.ts`、`extension/team-notify.ts`）与 `tests/bg-ledger*` 的判据本身——
  它们已独立复验通过；4.3 只做**折进 smoke 的登记与一致性断言**，不得削弱或删除既有断言。
- 不改派单的身份/模型路由逻辑（S1–S3 已复验通过）；不改 canonical specs；需要契约变动先 `BLOCKED:` 给 PM。
- 不删/skip 既有断言换绿；模板/夹具的合法输入变化要说明理由。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面选出的段，至少含 6/13/13c>
bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧（每条都要有可跑的失败证据）**：① 把 AGENTS 模板里的第三态删掉 → 「One contract across the shipped
surfaces」必须红并点名那个面；② 把旧的「回合结束前必须收割」措辞还原进提示词 → 同一场景红；
③ 让模板不带 `{bg_ext}` 时也注入车道段 → 「A template without the lane placeholder」必须红；④ 把续跑指引里的
`state/bg.log` 去掉 → 「The resume guidance points at the on-disk evidence」必须红。还原后全绿。

## 交付

`docs/team/reports/P237-dev.md`（逐条 §4 对照、命令与 rc、四条红侧的前后证据、未做项）、证据包按 D94 放仓外；
不合并、不推送、不归档；做完 `team notify pm`。之后由**未写过本任务**的席位独立复验（该 change 的第三份 delta
届时才可归档）。
