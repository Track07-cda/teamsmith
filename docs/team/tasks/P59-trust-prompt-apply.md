# P59 · trust-prompt-and-fixtures apply：夹具区分覆盖层 + `team init` 说明信任后果

```
task:   P59
agent:  dev-bob
issue:
change: trust-prompt-and-fixtures      # 提案已验收：docs/team/reviews/trust-prompt-and-fixtures-proposal.md
specs:  verification#A fixture's input-box judgement distinguishes an unexpected overlay / init-skill#The project-local install names Pi's trust consequence
phase:  apply
anchor: change
deltas: verification, init-skill
grant:  skills/teamsmith/tests/pm-box-real.sh · skills/teamsmith/tests/frames/（新增真实帧）· skills/teamsmith/tests/lib/*（判定共享库）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/scripts/lib/cmd-init.sh（一行提示）· skills/teamsmith-init/SKILL.md · skills/teamsmith-init/references/bootstrap.md · skills/teamsmith/references/protocol.md（若需一句）
deps:   P57（propose，已合并）· P40（`.pi/skills` 安装）· P54 的 F2（现场）
status: todo
budget: 一个工作块（B1 判定 + 帧 / B2 夹具 / B3 提示行 + 文档 / B4 翻转）
```

> 本地模式：不 push。**真源 = `openspec/changes/trust-prompt-and-fixtures/{design.md,tasks.md}`。**

## 硬要求

1. **判定**：**未预期的整屏覆盖层 ≠ 非空输入框**；实测案例是 Pi 的项目信任弹窗；**不许**报 `idle-read=NOT-EMPTY`。
2. **就绪等待**只认"**定位到的空输入框**"，不认"第一个整行分隔线"（弹窗自带分隔线会骗过裸等待）。
3. **弹窗在场而等待到期**：点名覆盖层、保留最后一帧、非零退出，**一个键都不敲进弹窗**（没定位到输入框就不许跑投递）。
4. **夹具仍跑在装了 `.pi/skills` 的项目里**（**不许** `--no-skills` 绕过），用**单次运行的信任覆盖**回答弹窗，
   **不动 Pi 的 trust store**。
5. **可证伪**：存一份**真实帧**到 `tests/frames/`，关掉覆盖层判据 → 同一帧必须被判成草稿（可见红侧）。
6. **产品行**：安装步打印一行说明信任后果（触发资源 + `pi --approve` / `/trust` / `team init --no-skills`），
   **不改退出码**、`--no-skills` **不打印**、由 `init`/`bootstrap` 共用的那一个实现打印；skill 与 `bootstrap.md` 同步。

## 必给的翻转（红→绿原始输出）

- 关掉覆盖层判据 → 存下的真实帧被判成草稿（红）；还原绿；
- 让夹具对着弹窗跑投递 → 断言红（不许敲键）；
- 去掉安装步那一行 → 断言红；`--no-skills` 下出现该行 → 红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/pm-box-real.sh          # 夹具自跑
```
