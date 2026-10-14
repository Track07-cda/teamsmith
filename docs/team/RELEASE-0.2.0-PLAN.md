# 0.2.0 发布与迁移计划（PM 备好，等用户放行）

## 0.2.0 里有什么

| 内容 | 状态 |
|---|---|
| 任务类别模型路由（`task-model-routing`）：类别→模型映射取代席位/默认模型；派单与续跑复用同一记录（模型 + 会话），换模型必须新会话；面板类别编辑与「策略 vs 实际」分离；init/模板/指南换成新式输入；门禁 §61/§61b | 已并入 main、三份独立复验（V19/V21/V23）通过、**已归档** |
| 关键回复页（`pulse-key-replies`）：`team reply post/list/show`、固定槽位存储、面板第五页 | 已并入 main、两轮独立复验（V27）通过、**已归档** |
| 长作业车道（`long-job-suspend`）：工具侧 A 刀、归属返工（P236）、工人提示词三态合同 B 刀——「起完结束回合、叫醒带结果」 | 已并入 main、各刀独立复验（V20/V22/V24）通过、**归档待门禁 + 一句确认** |
| 门禁与工具面：路由前门进闸门（P238）、账本禁令对报告类改动开火（P239）、squash 合并的合并判据（P244）、选段覆盖（P243）、对端名清理与账本扫描面收紧（P231）、发布检查修好（P247）、临时根与容量（P141/P144）、本版预算表修正 | 均已并入 main |

破坏性变化（要在发布说明里写明）：**旧的 `TEAM_AGENT_MODELS`/`TEAM_DEFAULT_MODEL` 不再被接受**——旧项目在任何写入之前被拒，并指向 `team config upgrade-models`。

## 发布序列（PM 执行，不可逆步骤逐条取用户点头）

```bash
# 0. 前置：长作业变更归档 + 全量门禁在最终 tip 上全绿（容器 + 冻结克隆）
# 1. 六处版本落点 → 0.2.0（两个 SKILL 的 front-matter **带引号**，别用不带引号的 sed）
#    package.json · skills/teamsmith/SKILL.md · skills/teamsmith-init/SKILL.md
#    skills/teamsmith/scripts/lib/common.sh 的 TEAM_VERSION · README 的四处 pin · CHANGELOG 新段
bash docs/team/tools/release-check.sh            # 期望：版本落点一致 + HEAD 就在 v0.2.0 上（先别打 tag）
git tag -a v0.2.0 -m 'teamsmith v0.2.0'
bash docs/team/tools/release-check.sh            # 期望全绿
bash docs/team/tools/release-check.sh --self-test # 期望 4/4 + tag 判据 4/4
# 2. 推（不可逆，需点头）：产品提交不带 [skip ci]、与账本提交分两次推（D97）
git push public main v0.2.0                       # ⚠️ 只推本次 tag，**不用 --tags**
bash docs/team/tools/release-check.sh --remote    # 期望：公开远端与本地 main 同点
# 3. npm（不可逆，需点头 + 用户网页 2FA）
npm stage publish --access public --registry https://registry.npmjs.org
# 4. 发布后验证：新克隆 + 三条安装路线 + `team version --check`
```

## 其他项目的迁移（用户已授权由 PM 做；逐项目给 diff）

现状：三个项目的**工具入口路径已在 10-13 改好**（都指向 `~/.agents/skills/teamsmith/scripts/team`），共享技能软链已指向 npm 包——但它们用的是 **0.1.2**（旧配置仍合法）。0.2.0 上线后：

```bash
# 每个项目：先看现状（只读）
cd <项目> && git status --short && rg -n 'TEAM_(AGENT_MODELS|DEFAULT_MODEL|PM_MODEL|TASK_MODELS)=' .pi/team/config.sh

# 1. 装新版并刷新共享技能（一次，全局）
npm i -g teamsmith@0.2.0 --registry https://registry.npmjs.org
bash "$(npm root -g)/teamsmith/install.sh"

# 2. 逐项目迁移配置（PM 执行；改前把 config.sh 备份到仓外）
bash ~/.agents/skills/teamsmith/scripts/team config upgrade-models \
  --task-models '<category=provider/model …>' --pm-model '<provider/model>' --yes
bash ~/.agents/skills/teamsmith/scripts/team doctor      # 复核
```

注意：**绝不用 `team init` / `init --force`** 做迁移（它按缺省值重渲染身份、`--force` 还会覆盖 `config.sh` 与五份治理文件，见 #1981/#1982）；只改 `config.sh` 的模型键。迁移后各项目的 agent 会话要**重启**才会读到新技能文本与配置语义。

## 等用户定三件

1. **版本号**：建议 **0.2.0**（破坏式配置迁移 + 两个新功能面；0.1.x 只做补丁）。
2. **推公开仓 + npm 发布的授权**（0.1.2 那次已授权，本次是新一轮不可逆动作）。
3. **长作业变更的归档确认**（门禁跑绿后即可执行；它的清单只剩这一项）。

## 三个本地项目的迁移现状（PM 2026-10-14 只读盘点 + 干跑）

工具入口路径已在 10-13 改好（都指向 `~/.agents/skills/teamsmith/scripts/team`），共享技能软链已指向 npm 包——
所以 `npm i -g teamsmith@0.2.0` 之后它们立刻拿到 0.2.0，而**旧配置会被拒**。三个项目的现状各不相同：

| 项目 | 现在的模型配置 | 迁移动作 |
|---|---|---|
| `agent-base` | 旧式三键：`TEAM_AGENT_MODELS`（按席位 6+ 个，含 `product`）、`TEAM_DEFAULT_MODEL=kimi-coding/kimi-for-coding`、`TEAM_PM_MODEL=kimi-coding/k3` | **真迁移**：`upgrade-models` 移除两个退休键、写入新的类别映射与 PM 模型 |
| `ai_interview` | 旧式：`TEAM_AGENT_MODELS`（多席位，值多为 `deepseek/deepseek-flash`）、`TEAM_DEFAULT_MODEL="deepseek/deepseek-flash"`、`TEAM_PM_MODEL="kimi-coding/k3"` | **真迁移**（干跑已通过：会移除两个退休键并写入新映射） |
| `erp` | **已经是新式**：`TEAM_TASK_MODELS=implement=… verify=… docs=… test=…` + `TEAM_PM_MODEL=kimi-coding/k3`（退休键只剩注释） | 基本是空操作：只装新版 + 重启会话；`upgrade-models` 若要跑，也应当**保留它自己的类别词汇**（`implement/docs/test`），不要套用别处的 `code/verify` |

待用户定一处：**新映射里的模型值**。
- 推荐（A）：把这些项目的类别与 PM 都指向本机已知可用的默认模型 `opencode-go/deepseek-v4.1-flash`
  （依据：用户 D129 补记「默认模型与 kimi-k3 能力相当」；且 kimi 周额度本周两次用尽，把它们绑在 kimi 上会硬阻塞）。
- 备选（B）：尽量保留它们原来的值（`deepseek/deepseek-flash`、`kimi-coding/kimi-for-coding`、`kimi-coding/k3`）——
  代价是这些值是否在本机 Pi 上可用需要它们各自确认，且 PM 模型绑 kimi 的会在额度用尽时起不来。

**执行顺序（同一窗口）**：① `npm i -g teamsmith@0.2.0 --registry https://registry.npmjs.org` → ② `bash "$(npm root -g)/teamsmith/install.sh"`（刷新共享软链）→ ③ 逐项目 `config upgrade-models`（改前把 `config.sh` 备份到仓外，执行后给用户看前后 diff）→ ④ 逐项目 `team doctor` 复核 → ⑤ 重启各项目的 agent 会话（它们才会读到新技能文本与配置语义）。**任何一步都不用 `team init` / `--force`**（#1981/#1982）。
