# P253 · 旧配置的拒绝信息要能自助修：打印一条**按它自己配置推导出来的**可粘贴命令

task: P253
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — 只改拒绝信息的可执行性与首行位置，不改契约与判据
branch: task/P253-migration-self-service
deps: -

## 缺陷（PM 2026-10-14 以「普通用户」视角实测）

在一个**带着旧配置**的项目里（我拿迁移前的真配置在 `/tmp` 复刻了一份），跑写路径命令（`team dispatch … --print`）：

- 拒绝如实出现了，两条退休键都点到名，也给了修法命令——**这一层是好的**；
- 但它被夹在一堆别的 blocker 中间（任务书缺锚、worktree 不存在…），而且命令里是 `<完整映射>` / `<独立模型>` 这样的占位符：**用户必须自己知道怎么把旧的席位映射翻译成类别映射**，这正是他们最容易卡住的地方；
- 而我作为 PM 给三个项目做迁移时，是**手工推导**那张映射的（旧 `TEAM_AGENT_MODELS` 的每个 `席位=模型` + `TEAM_DEFAULT_MODEL` 当兜底类别）。这段推理工具完全做得到——它手里就有旧配置。

## 要求

1. **打印一条可粘贴的建议命令**：`team_model_policy_issues`（`scripts/lib/common.sh:1383` 起）在发现退休键时，除了点名，还要**从当前配置推导**出一份建议映射并打印完整命令，例如
   ```
   修法（建议，改类别名随你）：team config upgrade-models \
     --task-models 'verify=<旧 verify 的值> verify2=<旧 verify2 的值> product=<旧 product 的值> … code=<旧 TEAM_DEFAULT_MODEL 的值>' \
     --pm-model '<旧 TEAM_PM_MODEL 的值，缺省则用 TEAM_DEFAULT_MODEL>' --dry-run
   ```
   推导规则写清并配夹具：旧 `TEAM_AGENT_MODELS` 的每个 `席位=模型` → 同名 `类别=模型`（类别名要过新校验的形状 `[a-z][a-z0-9-]*`，不合法的席位名要被规范化并**在信息里说明**）；旧 `TEAM_DEFAULT_MODEL` → 一个兜底类别（建议 `code`，若与席位名撞则换名并说明）；PM 取旧 `TEAM_PM_MODEL`，为空则用默认值。**这是建议**：信息里要写明「这是按你现在的配置推导的，类别名可以改」，不得暗示这是唯一正确映射。
2. **不许猜**：旧键的值解析不出来（注释、多行、变量展开、重复键——既有 `upgrade-models` 已经会拒的形状）时，退回今天的占位符写法并**说明为什么算不出来**，不许打印一条可能错的命令。
3. **位置与可读性**：这条（连同 `TEAM_TASK_MODELS`/`TEAM_PM_MODEL` 的另一条）应当在写路径的拒绝输出里**成块出现在前面**或单独成块，不要被无关 blocker 冲散；同一项目里**两条退休键只打一条迁移建议**（今天是每条键一行，重复）。
4. **红侧**（每条给「改前红/改后绿」或「破坏必红、还原复绿」）：
   - 把推导规则去掉（回到占位符）→ 夹具红；
   - 打印出来的命令**真的能粘贴执行成功**（在夹具项目里 `--dry-run` 通过，随后 `--yes` 落地、`config list` 显示新键、退休键消失）；
   - 旧配置形状不可解析（注释/多行/变量）→ 退回占位符并点名原因，**不许**打印建议命令；
   - 旧键值为空/缺失 → 用 `TEAM_DEFAULT_MODEL` 兜底；两者都缺 → 不打印误导性建议。

## 边界

- 只碰 `scripts/lib/common.sh`（`team_model_policy_issues` 及它用到的解析辅助）、必要的 `scripts/lib/cmd-config.sh`（若推导逻辑更适合放那儿）、`references/migration.md` §5b 与 `references/config.md` 的对应段落（说明拒绝信息会给出建议命令）、以及夹具/登记。
- **不改**判据本身：旧配置仍然被拒、仍然指向 `upgrade-models`、`--yes` 与预览的语义、审计与写入器都不动。
- 不改 `upgrade-models` 的既有行为（它今天的报错与拒法不动），只改**建议文本**。
- 不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

外加一段**端到端现场**（报告里贴）：拿迁移前的真配置（仓外 `pm-skills-ledger/team/reviews/migration-0.2.0/*.config.sh.pre-0.2.0`，**只读引用**，别改那几个文件）在临时项目里复刻，跑写路径命令 → 复制它打印的那条命令 → 粘贴执行 `--dry-run` → 再 `--yes` → `config list` 复核。全过程贴输出。
