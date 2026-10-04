# M68 · settings-choice-editors 重做 apply（直写交互 + 交互路径不等读）

```
task:   M68
agent:  dev2
issue:
change: settings-choice-editors      # 修订提案已验收：docs/team/reviews/settings-choice-editors-rework-proposal.md（ACCEPTED）
specs:  panel#The console offers the schema's choice set wherever there is one, and degrades visibly / panel#The console writes a project setting only through team config set, after validation
phase:  apply
anchor: change
deltas: panel
grant:  scripts/panel/src/**（App/types/layout/strings）· scripts/lib/cmd-config.sh（仅当测量要求）· scripts/panel/panel.js（由 build.sh 重建）· tests/panel-choices.sh · tests/panel-p21.sh（仅 choices/choices-schema 两段）· tests/panel-flip-m54.sh · tests/smoke.sh（§38，append-only）
deps:   M65（修订提案，已合并 58263e6）· **M59 已合并**（两者都改 tests/panel-p21.sh——本任务在 M59 落地后才开始，避免对冲）
status: todo（等 M59 合并后派）
budget: 一个工作块；做不完交 PARTIAL
```

> 本地模式：不 push。设计真源 = `openspec/changes/settings-choice-editors/design.md` §5（测量/瓶颈/修法/翻转）与
> 修订后的 `tasks.md`；**以它们为准**。

## 四条用户决定（契约形态，design/proposal 已写死）

1. **选中即写**：选项条目 accept → `config set … --dry-run` 通过后直接 `config set … --yes --fingerprint …`，
   **没有第二确认帧**；校验 + CAS 指纹 + 审计一行全部保留；
2. **只有「其他」**（自由输入）打开写编辑器（校验 + 确认保留）；
3. **危险值例外**：即使来自选项，第一次 accept 只出示危险警告（不写、不审计），第二次 accept 才带
   danger allowance 写入；
4. **交互路径不等读**：按键与回答帧之间**不得**出现 `config list`/`__panel-data` 调用；编辑器由视图已读的
   `settings` 块构建；settle 后的重读**在后台**进行，回执帧不等待它。修法 = **删掉强制重读**
   （settings 块已有 15s TTL），不是加长 TTL。

## 必给的翻转（每条红→绿原始输出）

- 直写 argv 序列：accept 一个选项 → 恰好 `dry-run` → `--yes`，无确认帧，审计 +1；
- 交互路径无读子进程（按键→帧之间无 `config list`/`__panel-data`）；
- 危险值（来自选项）仍一次确认；
- 「其他」仍走编辑器 + 校验 + 确认；
- bundle 重建两次字节一致（`bash skills/teamsmith/scripts/panel/build.sh` 跑两遍比 sha256）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-choices.sh
bash skills/teamsmith/tests/panel-flip-m54.sh F-B
bash skills/teamsmith/tests/panel-flip-m54.sh F-C
node skills/teamsmith/tests/panel-strings.mjs
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不改 `tests/panel-p21.sh` 里 choices/choices-schema 以外的段**（M59 的地盘）；
- 写入路径仍走 `team config set`（唯一写入者）；**不新增 `unset`**；
- 响应性写成行为契约（上第 4 条）；**不往正确性门禁里塞墙钟数字**（D33）；
- 不 push；不改 `docs/team/**`（PM 台账）；矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- 实现 + 翻转证据 + 报告 `docs/team/reports/M68-dev2.md`（含直写前后两次 accept 的帧证据、
  以及"交互路径无读"的 argv 日志证据）。
