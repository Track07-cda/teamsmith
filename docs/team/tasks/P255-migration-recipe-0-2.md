# P255 · 升级指南跟上 0.2.0 的形状（npm 分发 + 配置迁移 + PM 身份）

task: P255
agent: dev-bob
phase: apply
category: docs
change: -
anchor: none (infra) — 只改升级文档与它的夹具，不改产品行为
branch: task/P255-migration-recipe
deps: -

## 缺陷（用户 2026-10-14 在真项目上照文档升级时暴露）

用户拿一个 0.1.2 的项目按文档升级，第一步就撞在 `team up` 的身份拒绝上（见任务书旁边那串原始输出）。查 `skills/teamsmith/references/migration.md` 的 **§6 Upgrade recipe**：它**过时**了，而且是关键处的过时：

1. **第 1 步还是「`git -C <skill checkout> pull --ff-only`」** —— 但 0.2.0 起本机的技能来源是 **npm 包**（`~/.agents/skills/teamsmith → ~/.local/lib/node_modules/teamsmith/skills/teamsmith`），升级方式是 `npm i -g teamsmith@<v>` + 跑包内 `install.sh`，**没有 checkout 可 pull**。
2. **完全没提配置迁移与 `team up` 的关系**：§6 第 4 步只说「旧配置会在 `team init` 处被拒，先跑 `upgrade-models`」，但**没有**说清楚「升级后第一次 `team up` 会因缺 PM 启动身份记录而被拒」这件事、也没有给两条出路（`--fresh-pm` 开新对话 / 补记录以续旧对话）与各自后果。
3. §6 没有 `--agents`（席位）那一步，也没写「各项目自己的会话要重启才会读到新技能文本」。
4. 顺带：§6 第 4 步的 `team init` 对一个既有项目**不是无副作用的**（本项目自己记过两次：#1981 `--force` 会覆盖配置与五份治理文件；#1982 普通 `init` 用参数缺省值渲染身份并可能新建错的账本目录），文档里没有这条警告。

## 要求

1. **重写 §6 为 0.2.0 的升级配方**，步骤要能被一个不懂 teamsmith 的人照做：
   - 升级工具本身：`npm i -g teamsmith@<v> --registry https://registry.npmjs.org` → `bash "$(npm root -g)/teamsmith/install.sh"`（刷新共享软链）→ 验证 `team version` 与 `readlink -f ~/.agents/skills/teamsmith`；
   - 逐项目：**先备份 `config.sh`** → `team config upgrade-models --task-models '<map>' --pm-model '<model>' --dry-run`（看一眼）→ `--yes` → `team config list`（rc=0）；
   - **PM 启动身份**：讲清 `state/pm-launch.env` 是什么、为什么会缺（0.1.x 升上来的项目就是缺）、两条出路及其后果（`--fresh-pm`＝新对话、磁盘即交接、Pi 历史不动；补记录＝续上一场对话，但模型必须与记录一致）、以及**模型改了就不能续**这条约束的理由（一场对话固定一个模型）；
   - 会话：`team up` 恢复 PM、`team up --agents` 一并拉起席位、重启各项目自己的 agent 会话才会读到新技能文本；
   - 收尾验证：`team doctor`、`team config list`、一次 `dispatch --print` 证明 `category:` 与模型解析生效；
   - **回滚**：配置回 `cp` 备份、`--fresh-pm` 不动 Pi 历史这两条要写明。
2. **升级路径的每一步都要能证伪**：给一份**夹具**（`tests/` 下新段或既有段的扩展），用一个 0.1.x 形状的配置在临时项目里走完整条配方（工具升级那步用夹具桩），断言关键中间态（迁移前被拒 → 迁移后 `config list` rc=0 → `pm-launch.env` 缺失时 `up` 拒绝且信息含两条出路 → 补记录或 `--fresh-pm` 后 `up --print` 给出 `continued`/`fresh` 判定）。**红侧**：把文档里的任一步删掉 → 夹具（若它能跑）必须红；至少给一条「文档写了但工具不做」的检查（例如文档承诺某条输出 → 探针找不到该字符串则红）。
3. **不要重写历史记录**：§5b 里已有的正确内容保留；本次只改 §6、补 §5b 的交叉引用与 README 的指针（README 现在指向 `migration.md`，确认指向的锚点仍存在）。
4. **与 P252（help 分级 + 语言层）的分工**：本任务只改 `references/**` 与夹具，**不碰** `cmd-project.sh` 的帮助段；若必须碰，先 `BLOCKED:` 给 PM。

## 边界

- 只碰 `skills/teamsmith/references/migration.md`（必要时 `references/config.md` 的交叉引用）、`README.md` 的相关指针、`tests/` 的夹具与登记。
- 不改产品行为、不改判据、不改既有 `§51` 的强度。
- 不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
- **排期**：todo（等现有席位空出来再派），任务书先写好——用户报的这一遍不该发生第二次。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 范围更新（2026-10-15，启动自愈已并入 main 之后）

`startup-self-heal` 已落地：**`team up` 现在会自己完成机械迁移**（写前打印计划、留备份、逐键打印 before→after、写一行审计），`--print` 只预测不写、`--no-migrate` 拒绝并点名手工命令，缺 PM 身份记录时会自动登记并打印一行。所以 §6 的配方要**以自动路线为主**：

1. 升级工具（npm + `install.sh`）；
2. 逐项目：**先备份 `config.sh`** → 直接 `team up`（它会自己迁移并打印每一处改动）→ 若它拒绝（形状定位不了 / 兜底名撞车 / 值不合法），按它给的**可粘贴命令**走手工路线（`team config upgrade-models … --dry-run` → `--yes`）；把两条路线都写清，并说明「拒绝时它会给一条从你项目自己的配置推导出来的命令」；
3. **PM 启动身份**：讲清 `state/pm-launch.env` 是什么、0.1.x 升上来的项目为什么会缺、两条出路（自动登记 / `--fresh-pm`）及后果；
4. 会话与收尾验证（`--agents`、重启各项目自己的 agent 会话、`team doctor`、`team config list`、一次 `dispatch --print` 证明 `category:` 与模型解析生效）；
5. **回滚**：配置回 `cp` 备份；`--fresh-pm` 不动 Pi 历史。

判据仍按你任务书原样（夹具 + 每一步可证伪 + 真项目形状的现场）。

## 返修轮次 1（2026-10-15，独立复验 V40 判 FAIL：两项必修，**都是文档说错、不是工具错**）

复验记录 `docs/team/reviews/V40.md`（受检 `91b40ab`）。我按复验者的清单**逐条复现**过，并把它判成「文档 vs 工具」哪一侧错——**板子打在文档上，工具与规格一致**：

**F1 · §6 Step 2（原第 255–256 行）说「拒绝时会打印一条从你自己配置推导的可粘贴命令」——不成立。**

我的复现（临时项目，只跑 `--print`，不写盘）：

| 形状 | 工具实际打印 |
|---|---|
| `shape-not-locatable`（值里带变量展开 / 多行字面量） | 点名障碍 + **占位符路线** `--task-models '<完整映射>' --pm-model '<独立模型>'` |
| `fallback-name-collision`（席位名 `default` 与兜底撞名） | 同上（占位符） |
| `invalid-model-value`（`not-a-model`） | 同上（占位符 + 点名哪个席位的值不合法） |
| **可定位**形状 + `up --print --no-migrate` | **推导命令**：`team config upgrade-models --task-models 'dev=… verify=… default=…' --pm-model 'kimi-coding/k3' --dry-run` |
| **可定位**形状 + `config set` | **推导命令**（路线 ①）＋两条路线都点名 |

**合同在哪**：`openspec/specs/init-skill/spec.md` 的迁移一节写得很清楚——拒绝必须点名文件与**确切障碍**；**「当推导本身无歧义时」才打印一条可粘贴的 `upgrade-models` 命令，「有歧义时不打印」**；场景「The legacy refusal carries a command derived from the project's own configuration」还有一行 **AND**：「a shape the derivation cannot locate **falls back to the placeholder route** and names the obstacle」。所以：**工具是对的，文档把条件句写丢了**。

**改法（F1）**：把那句话改成符合合同的写法（保留条件句与「有歧义时只点名障碍、给占位符路线」），并把两条路线的**触发条件**写清楚（可定位 → 推导命令；不可定位/撞名/值非法 → 占位符）。改完请按你新写的句子**逐条对照上表**自证（哪一句对应哪一行输出）。

**F2 · §6 Step 4（原第 315–316 行）说「`team up` 重建巡检窗口」——不成立。** `team up` 只起 PM；**建/重建巡检窗口的是 `team pulse up`**。复验者在私有 tmux 里逐窗口名取证（跑完 `team up` 只有 `pm`，没有 `pulse`）。改法：那句话改成「（PM 与席位都需要重启才会读到新技能文本；**巡检窗口由 `team pulse up` 建立**，`team pulse status` 看它的状态）」。

**交付要求**：改完跑一遍 `upgrade-recipe.sh`（并确认夹具**没有**把这两处错误文本钉住——若有 needle 钉着旧句子，一并同步），更新 `docs/team/reports/P255-dev-bob.md`（返修轮次一节：两处 diff、你的对照自证、夹具结果），然后 notify pm。我随后派 **V40 第二轮**定点复检（同一验证席位，换会话）。

## 返修轮次 2（2026-10-15，V40 第二轮判 FAIL：**一项，一句话**）

第二轮复检结论（`docs/team/reviews/V40.md` 文末「第二轮复检」一节）：**F1、F2 判为真修好**，新守卫**确实有牙**，第一轮绿面**一条未回退**；唯一必修是 **F3**。

**F3（文档内部不一致，不改产品行为）**：`references/migration.md` 第 231–232 行（`--no-migrate` 那一句）仍写着**无条件**承诺：

> `team up --no-migrate` is the same promise from the other side: it refuses, writes nothing, and prints the **manual command derived from *your* configuration**.

而同一次改写新写的 255–262 行已经把这层条件讲清了（「两份形态，取决于你的配置」）。复验者造了**六种推导停住的形状**（`shape-not-locatable`、`fallback-name-collision`、`invalid-model-value`、`category-not-normalizable`、`contradictory-values`、`unknown-shape`），这六种下 `--no-migrate` 打印的都是**占位符路线**，不是推导命令。

**修法（一句话，二选一都行，你定）**：把 232 行改成两形态表述（例如「… prints the manual transaction in whichever of the two forms your configuration supports — the derived command when the derivation is unambiguous, the placeholder route when it is not」），或直接指向下面那一节（「… prints the manual transaction in one of the two forms described below」）。**不要动产品行为**、不要改 255–262 已写好的那节。

**交付**：改这一句 → 跑 `upgrade-recipe.sh`（若它钉了这句，同步）→ 报告里写一行 → notify pm。我随后让验证席位用**它自己的两套脚本只跑文档面与 §64** 做定点复检（它已这么提议）。
