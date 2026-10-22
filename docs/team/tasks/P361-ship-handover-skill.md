# P361 · 把 handover 技能打进包，并让 `team init` 装它

task: P361
agent: dev3
phase: apply
category: code
change: -
specs: teamsmith#installation
anchor: none (infra) — 打包与安装面
deltas: -
branch: task/P361-ship-handover-skill

## 背景

一个长期会话即使上下文占用稳定，**会话形状**仍在退化（有的模型在长会话里不再输出思考）。治法是换新会话，而
「换会话」需要一份指针式交接文档 + 一次**切换**（旧会话写完就停手）。这套做法已写成一个独立技能：

`skills/handover/SKILL.md`（PM 已放进仓库，121 行，英文）。**它必须随包发布，并由 `team init` 装进项目的
`.pi/skills/`**，否则别的机器、别的项目拿不到。

`npm pack` 已确认会带上它（`files` 是 `skills/`）。

## 要做的

1. **注册源**：`skills/teamsmith/scripts/lib/cmd-init.sh` 的 `team_skill_sources()` 现在只认
   `teamsmith` 与 `teamsmith-init`（而且是「兄弟目录」形状）。加上 `handover` —— 注意它同样是
   `$TEAM_SKILL_DIR` 的兄弟目录；源不存在时不能报错、不能静默漏装（沿用现有「只列真实存在的源」语义，
   但**现有命名口径要改**：现在是 hardcode 两个名字，建议改成「`skills/` 下的真实目录，且 SKILL.md 的
   `name:` 与目录名一致」，这样以后再加技能不用改代码）。
2. **全局安装**：`install.sh` 已经是 `for src in "$REPO"/skills/*/`，确认它对 `handover` 也生效
   （含 `/team` 扩展那一套不动）。
3. **断言跟着契约走**（关键）：`install-shape.sh` 里写着「逐 skill 一条 link 行 = 2」、
   「`.pi/skills/` 里仍然只有两条 = 2」。这些数字会在装上第三个技能后变红——**必须按新契约更新，并且
   把断言从「固定 2」改成「与源清单一致」**（数出源里有几个真实技能，断言安装后一样多），否则下次加技能
   又红一遍。同样检查 `smoke.sh`、`team help init` 文档、`README` 里所有「两个技能」的说法。
4. **文档同步**：`skills/teamsmith/SKILL.md` 与 `skills/teamsmith-init/SKILL.md` 提到技能清单的地方、
   `team help init` 文案、`references/` 里相关段落。
5. **版本**：`0.3.3`，`CHANGELOG` 加一条（写明「新增 handover 技能 + init 会装它」）。

## 必须交的读数

1. `bash skills/teamsmith/tests/install-shape.sh`：改前（有红）与改后（0 红）两段真实输出；
   并贴「`.pi/skills/` 计数」那条断言现在怎么算出来的。
2. `team init` 在一个**私有夹具项目**里跑一次：贴 `.pi/skills/` 的 `ls`，三个技能都在，且 `SKILL.md`
   的 `name:` 与目录名一致。
3. `--no-skills` 仍然一个都不装；`--copy` 三个都是真目录。
4. **红侧**：在私有副本里把 `handover` 的 `SKILL.md` 的 `name:` 改成别的名字 → 必须红并点名；
   把 `handover` 目录整个删掉 → 安装不该崩，且要**可见地**说出少了一个技能（不是静默）。
5. 轻量收口：`bash -n`、`--loop-check`、`section-select.sh --check`、账本禁令、`git diff --check`。

## 边界

- 写集：`skills/teamsmith/scripts/lib/cmd-init.sh`、`skills/teamsmith/tests/install-shape.sh`、
  `install.sh`（若需要）、相关文档、版本六处、`CHANGELOG.md`、报告。
- **不改** `skills/handover/SKILL.md` 的正文（那是产品文案，改了要单独说）。
- 不新增门禁段；不碰信号闸门；不动 `/team` 扩展安装逻辑。

## 返修（V93 判 PARTIAL 后；一次收完，别再开验收轮次）

V93（`docs/team/reports/V93-verify.md`）确认行为全对（四种布局都装上、对称盲区关上了、三态都在、`--no-skills`/`--copy`/`npm pack`/路由判据符合），
但候选在**门禁上留了一处真红**，你报的选段没跑到它：

1. **必修 · `smoke.sh` §0b 又写死了一个名字**：`for P16_SD in "$SKILL_DIR" "$SKILL_INIT_DIR" "$SKILL_HANDOVER_DIR"`。
   于是任何「产品面检出 / 部分树」形状都会红——`checkout-shape-probe` 自建的 scratch 树只拷 `teamsmith` 与
   `teamsmith-init` 两个目录，`skills/handover` 不存在 → §0b 判红。读数：候选 `ok 126 / bad 21 / rc=1`，
   `main` `ok 147 / bad 0 / rc=0`。按你自己这次的论点改：**跟着 `skill_src_names` 走**，并让探针的拷贝集合也由
   源清单派生（V93 在副本上实测过这个改法：产品面 scratch 树 `--select 18,19` 从 ✗1 → ✗0；完整探针从
   `126/21` → `147/0`，与 main 同读数）。
   **这是本任务第二次栽在「写死的名字 vs 从源派生」上**（第一次是夹具数「2」），报告里要写清这一点。
2. **必修 · `note` 分支没有断言**：把 `handover` 从 `team_skill_declared` 里删掉，新夹具仍 `57 ✓ / 0 ✗` 全绿——
   也就是「源里有、声明里没有 → 喊 `note`」这条分支没有任何人钉住，声明面可以静默漂移一步。补一条断言 + 一条红侧
   （从声明面删掉一个名字 → 必须红并点名它变成了未登记）。
3. **本轮验收范围**：除了你原来的选段，**必须跑 `bash skills/teamsmith/tests/checkout-shape-probe.sh`**（作者漏的正是它；
   V93 花了很久才发现）。它约 11 分钟。跑之前 `ps` 确认没有别人的 `smoke.sh`。若它在你的树上仍红，先看清红在哪一段。
4. 报告里加一句：这次改动让 §0b 与探针拷贝集合**都从源派生**，以后加技能不需要再改这两处。

改完交 V93 同一席位定点复看（只看这两处差异 + 它自己那次探针读数）。
