# V94 · P362 的独立验收：勾得对不对（勾了的真有证据、留空的真的没做）

task: V94
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 账本勾选
deltas: -
branch: task/V94-tick-checklists-verify

## 受检

候选 `426eaf84`（报告 `docs/team/reports/P362-dev3.md`）。它只动两份 `tasks.md`：
`behavior-focused-ci` 9 → 7 项未勾（勾 2）、`gate-waiter-patience` 34 → 7 项未勾（勾 27）。

## 要自己做的（重点是"抽回两条"，不是数数量）

1. **抽 6 条被勾的项**（两份里各 3 条），逐条核它写的证据指针**今天在磁盘上读得到**，并且真的支持那句话
   （提交在位 / 报告里确有这样一段 / 选段读数确是这个数）。写出你抽的是哪 6 条与你看到的东西。
2. **抽 3 条留空的项**，确认"没做"是真的没做（而不是作者偷懒）：例如 `bfc 5.1`（钉死镜像里完整 `--floor --paths`）、
   `gwp 6.2`（`--select 34,34b,34d,36` 定点执行）——去翻 apply/verify 报告，确认那件事确实没发生；若你发现**其实做过**
   （有读数在盘上），那是必须报的错（勾空 = 漏记）。
3. **没有改条目文字**：`git diff main 426eaf84 -- openspec/changes/*/tasks.md` 里，被勾的行只应是 `- [ ]` → `- [x]`
   加**追加**的证据后缀，原有条目文字逐字未改；未勾的行**完全没动**。
4. `openspec validate --all --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check`、`team change status <id>`
   两份输出（贴读数，看还剩几项）。
5. 轻量收口：账本禁令、`git diff --check`。

## 边界

只读、只写 `docs/team/reports/V94-verify.md` 与自己的线程；不改清单、不合并、不 push。**不要跑整套门禁**。
结论先写 PASS/PARTIAL/FAIL，并单列「抽检发现的问题」。
