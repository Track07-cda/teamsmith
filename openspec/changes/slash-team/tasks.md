# slash-team · tasks

范围：`extension-slash`（新能力）与 `init-skill` 的三条 MODIFIED（delta 文件见 `specs/`），设计见 `design.md`，
动机与裁定点见 `proposal.md`。**apply 只能在 PM 的提案评审（`docs/team/reviews/slash-team-proposal.md`）判
ACCEPTED 之后开始**——本清单是 apply 席位的执行面，写它的阶段一条都不执行。

## 1 冻结与读入口

- [x] 1.1 读 PM 的提案评审，确认四个裁定点（大输出进上下文 / 环境剥离 / doctor 行 / 安装默认软链）的结论；与
  `proposal.md` 的推荐不一致的，按评审的结论改**规格**并重新评审，不改验收方向。 · 证据：评审记录的点名引用 · **P298 按证据勾**（dev2，任务 P298）：`docs/team/reviews/slash-team-proposal.md`（提交 `6030bc20`）「四个裁定点：全部采纳作者的推荐」逐条点名（全量进正文 + 保险丝 / 剥离三个变量 / 加 doctor 行 / 默认软链），与 `proposal.md` 推荐一致 ⇒ 无需改规格或重评审；落点可复核：`team.ts` 的 `UNSET_VARS`/`FUSE_*`、`cmd-init.sh:294,298`、`cmd-project.sh` 的 `/team` 行（V50 §5–§7 各自复跑过）
- [x] 1.2 读基线：`openspec/specs/init-skill/spec.md` 的三条被 MODIFIED 的需求（逐字，含全部场景）、
  `boundary#Actions stay inside the project and its own session`（跨项目边界不在本变更重写）、
  `verification#A changed-path list selects the sections to run, or the full suite`（新段的登记规则）。 · 证据：读过的行号 · **P298 按证据勾**：『行号』这一形态在已提交证据里没有（我查了 `P270-dev.md` 与 `V50.md` 全文，`grep '行号\|spec\.md:'` 0 命中；也没有 `docs/team/reports/P270-dev/` 目录）；基线的对照证据在提案复核的「基线场景对照（`init-skill` 三条 MODIFIED）零丢失（3→3、5→5、3→4）」，我在现树复算 `#### Scenario:` 数一致，delta 只动 `extension-slash` 与 `init-skill`（`boundary` 未被重写）
- [x] 1.3 冻结两张表：白名单十五条（`design.md` §3.2 的表，用户确认过的清单）与拒绝清单；冻结后不再增删
  （增删＝改合同，回提案）。 · 证据：`git diff` 只出现规格里写明的行 · **P298 按证据勾**：同上的形态缺口（没有「只出现规格里写明的行」的 diff 记录）；冻结的证据是 V50 §4.1（独立导出 11 读 + 4 动 = 15 行，与用户确认清单逐行一致）与 §4.3（往副本加一行 ⇒ 判据红）；我核 `522cc24b..753d787e` 间只有 `a9054126` 动过 `team.ts`（4 行注释、`TEAM_ROWS` 未变）且 `bun -e` 得 `rows=15`；拒绝清单不是第二张表（表外一律拒绝）

## 2 扩展本体（规格：`extension-slash` 六条需求）

- [x] 2.1 `skills/teamsmith/extension/team.ts`（单文件、零运行时依赖、Pi 侧只 `import type`，所以
  `bun -e "await import(...)"` 能加载）：默认导出工厂（`registerCommand("team", …)`），并把**纯逻辑**具名导出
  （白名单表、分词、匹配、菜单渲染、项目根/CLI 解析、`runTeamCommand(deps, argv)`）——纯逻辑不碰任何 Pi API，
  夹具用假 pi 直接驱动。文件首行是安装标记 `// teamsmith /team extension`（§3.6 的识别依据）。 · 证据：文件 +
  `bash -n` 无关、`bun -e` 导入成功；`grep -c registerTool` = 0 · **P298 按证据勾**：提交 `522cc24b`；我复跑 `bun -e` 导入 → `default=function rows=15 unset=[三个]`，首行标记与「只 `import type` Pi + node 内建」都核过；V50 §3 是独立的假 pi 注册面复跑
- [x] 2.2 白名单：十五条（11 读 + 4 动），读行严格形状、动行路径 + 自由尾巴；匹配器把整个 argv 吃完才算命中。 ·
  证据：`design.md` §3.2 的表与代码逐行对应 · **P298 按证据勾**：V50 §4.1/§4.2（独立 60 条 argv：确认集 20 全 run / 表外与破形状 38 全 refuse，含 `ps extra`、`config list --json` 这类 argv 没吃完的）；我复跑 `--all --flip` = 151 ✓ 作旁证
- [x] 2.3 分词：空白分隔、单/双引号、引号外反斜杠转义；**未闭合引号 ⇒ 拒绝且不起进程**。 · 证据：夹具里的
  引号/空格/未闭合三组 · **P298 按证据勾**：夹具 `slash-team.sh:190-217` 的 `tokens` 组（`"two words"` 逐字、单引号原样、引号外反斜杠、`meeting say "unclosed` ⇒ 拒绝且零 exec）；我复跑 151 ✓
- [x] 2.4 项目根与 CLI 解析（顺序见 §3.5）：向上找 `.pi/team/config.sh`；CLI = 项目本地 skills 路径 →
  `${TEAM_CLI}` → 扩展兄弟目录 → 拒绝并指名 `team init`。 · 证据：夹具逐格（有/无项目本地、有/无 env、都不是） · **P298 按证据勾**：夹具 `slash-team.sh:384-414` 的 `resolve` 组（向上找 config.sh、项目本地赢 `TEAM_CLI`、无项目本地用 `TEAM_CLI`、都没有用扩展兄弟目录、三条全空 ⇒ 拒绝并指名 `team init`）；我复跑 151 ✓
- [x] 2.5 菜单与补全：`/team`（无参）与 `/team help` 从同一张表渲染两组 + 结尾一句「表外命令请到终端」；
  `getArgumentCompletions` 的首词集合来自同一张表的命令路径。 · 证据：夹具断言「表加一行 ⇒ 菜单与补全都出现」 · **P298 按证据勾**（**实际做法**）：夹具不是「给副本的表加/删一行再看菜单」，而是「菜单 == 从同一张表独立重算」逐字比对 + 逐行点名 + 「命令行列数 = 表行数」+ `/team help` 同一份 + 补全同表（`slash-team.sh:273-303`）；我用 `menu-decoupled` 臂验非空洞：对照 23 ✓ → 变异 5 ✓ 18 ✗
- [x] 2.6 拒绝路径：表外命令、读行的多余 token、`up`/任何带 `--fresh-pm` 的调用——各自的文案**点名**被拒的命令/
  token，表外说明「这是 PM / 席位的命令，请到终端执行」，`up`/`--fresh-pm` 说明「这个会话就是 PM 会话，从这里
  重启会把当前对话一起带走」，全部**零副作用**。 · 证据：夹具里 `exec` 未被调用 · **P298 按证据勾**：报告 R2/R3 行 + V50 §3/§4.4；我复跑 `refuse` 组对照 54 ✓、`refuse-short-circuit` 臂 54 ✓ → 20 ✓ 34 ✗（首两条红行即「表外拒绝且零进程…execs=1」）
- [x] 2.7 执行与输出：`pi.exec("bash", ["-c", 'unset TEAM_ASSUME_YES TEAM_UPGRADE_CONFIRMED TEAM_ALLOW_FOREIGN_SESSION; exec "$0" "$@"', cli, …tokens], {cwd, timeout: 60000})`；
  短结果（单行 ≤ 200 字符、退出 0）→ 通知；其它 → `pi.sendMessage({customType: "teamsmith-team", content, display: true})`，
  正文头是 `$ team <argv…>` + `exit <code>`（或 killed 原因）+ stdout/stderr；失败再加 error 通知；保险丝 500 行/
  64 KiB（前 200 + 后 100 + 省略说明）；`up`/`--fresh-pm` 之外不注入任何 token。 · 证据：夹具逐格（短/长/失败/杀/超量） · **P298 按证据勾**：我逐条核 `team.ts:292-297` 的常量（60000 / 200 / 500 行 / 64 KiB / 前后 200+100）；V50 §7（真 pi 上 600 行与 1200×110B 两条保险丝）+ §2.2；我复跑三臂：`no-failure-notify` 13✓→11✓2✗、`entry-to-notify` 13✓→3✓10✗、`no-fuse` 13✓→11✓2✗
- [x] 2.8 结构性保证：`registerTool` 零调用、`ui.confirm` 零调用（前门不给自己加政策）。 · 证据：假 pi 的调用记录 · **P298 按证据勾**：V50 §3 假 pi 记录 `"tools":0,"confirms":0` + 静态调用点 0；我复跑 `grep -c registerTool team.ts` = 0

## 3 安装面（规格：`init-skill` 三条 MODIFIED）

- [x] 3.1 `scripts/lib/cmd-init.sh`：在同一个安装实现里加扩展安装（`<main>/.pi/extensions/team.ts` ←
  `$TEAM_SKILL_DIR/extension/team.ts`），默认软链、`--copy` 复制、`--no-skills` 连扩展一起跳过；冲突表与技能同款：
  同源软链/同字节副本 = skip；指向别处/带标记的副本 = 冲突（`--force` 换本源）；**不带标记的普通文件连
  `--force` 都不删**（红线）。 · 证据：`tests/install-shape.sh` 的扩展组（4.3） · **P298 按证据勾**：提交 `52373d0d`；V50 §6 三条路径真跑 + §8 的 `ext-skip` 变异；我复跑 `install-shape.sh` = `✓136 ✗0 SKIP0`，含 `⑧a` 对照（拒绝未标记文件）→ 翻转（改成 `rm -f` 必红）
- [x] 3.2 `team_gitignore_add` 加 `.pi/extensions/`；安装输出每个条目一行（`link/copy/skip`），扩展那一行与技能同格式。 ·
  证据：夹具输出尾 · **P298 按证据勾**：我核 `cmd-init.sh:293-294`（`.pi/skills/` 与 `.pi/extensions/` 各一条、装完一次）；夹具断言「.gitignore 有 `.pi/extensions/` 且只一条」「`--no-skills` 没被塞进」；V50 §6 贴了真跑输出的 `link  <repo>/.pi/extensions/team.ts → …` 一行
- [ ] 3.3 信任提示行同时点名 `.pi/skills/` 与 `.pi/extensions/`（答案不变、仍一行、`--no-skills` 不打）；同步
  `skills/teamsmith-init/SKILL.md` 的安装节与 `skills/teamsmith-init/references/bootstrap.md` 的项目技能行一句。 ·
  证据：两个文件里 `.pi/extensions/` 与 `/trust` 同页出现（`init-skill` 的场景 3 红侧：删掉再搜必红） · 证据（**留空**，见报告缺口 G1）：产品侧成立（`cmd-init.sh:298` 那一行确实点名两个目录，夹具运行输出原文为证；两个文档也都带 `.pi/extensions/` 与 `/trust`）——但夹具对「信任行含 `.pi/extensions/`」没有断言（`install-shape.sh:386-398` 的 `case` 只要求 `.pi/skills/` + `pi --approve` + `/trust` + `init --no-skills`），场景 3 的「两文档搜四个串 + 删掉再搜必红」在 `skills/teamsmith/tests/` 里没有任何实现。断的是这半条新增契约的 falsifier，不是产品
- [x] 3.4 `scripts/lib/cmd-project.sh` 的 doctor 加一行 `/team` 扩展：有项目本地安装时——软链指向本源或副本字节等于
  本源 = pass；缺失 = warn + 修法 `team init`；指向别处/副本漂移 = warn + `team init --force`；没有项目本地安装
  **一行都不打**；不影响 doctor 退出码。 · 证据：`install-shape.sh doctor` 组 · **P298 按证据勾**：夹具 `doctor` 组四态；我复跑 136 ✓ 的输出含「扩展缺失：warn…team init」⇒修复后 pass、「扩展漂移：…`--force`」⇒修复后 pass、「没有项目本地安装：一行都不打」，以及 `⑧b` 对照/翻转；V50 §6/§8 独立复跑
- [x] 3.5 `team bootstrap` 走同一实现（含既有 config 的升级路径）、`bootstrap --print` 照样只打印不写；扩展**不进**
  `team_skill_hash`（指纹仍只哈希 `SKILL.md` + `extension/team-notify.ts`）。 · 证据：夹具 + `grep team_skill_hash` · **P298 按证据勾**（**实际做法/口径差**）：清单括注写「只哈希 `SKILL.md` + `extension/team-notify.ts`」，实现是 `cmd-update.sh:16` 的 `team_skill_exts` = notify **与 bg**（本变更之前就是两文件）——结论不变：`extension/team.ts` 不在指纹里。夹具断言「bootstrap 装回扩展（config.sh 未动）」「`--print` 计划点名扩展一步」，我复跑 136 ✓ 里都在

## 4 测试与门禁接线

- [x] 4.1 `skills/teamsmith/tests/slash-team.sh`：bun `import` 源文件 + 假 pi 驱动（记录 `registerCommand`/
  `registerTool`/`exec`/`sendMessage`/`notify`/`confirm`），覆盖 2.2–2.8 的每一格（argv 逐字、cwd、菜单同源、
  补全、拒绝零副作用、短/长输出落点、退出码、被杀、保险丝、unset 列表、无工具/无确认）。 · 证据：脚本的
  `✓/✗` 计数与逐条名字 · **P298 按证据勾**：报告「验收命令」表的 `RESULT pass=151 fail=0`（8 条翻转臂）；V50 §2.1 冻结树独立复跑同数；我在合并后的树上复跑同数（1m14s，load1 ≈28），红侧原文见报告 §3
- [x] 4.2 `skills/teamsmith/tests/slash-team-e2e.sh`：夹具项目（装扩展 + 记录 argv/cwd/env 的 `team` 桩）里跑
  `pi --mode rpc --no-session --approve`（`PI_CODING_AGENT_DIR` 指向夹具自己的空目录，**不读 `$HOME` 的 pi 配置、
  不写 trust store、不用网络、不用模型**），stdin 发 `/team …`，判 JSONL：回执 `disposition:"handled"`、
  `message_start` 的 `content`/`display`、notify 的 `notifyType`、桩记录的 argv/cwd/env。 · 证据：原始 JSONL 尾 · **P298 按证据勾**（**证据形态偏差**）：作者报告与 V50 §2.1 都只有计数/断言名，没有原始 JSONL 尾 → 我复跑 `--flip --keep` = `✓34 ✗0`，并从保留的临时根取出原始 JSONL（`message_start` 的 `customType/content/display`、`extension_ui_request` 的 `notifyType=info/error`、`response … disposition:"handled"`），原文见报告 §3（G3）
- [x] 4.3 `skills/teamsmith/tests/install-shape.sh`：加扩展组（不存在/软链同源/软链别处/副本同字节/副本漂移/无标记
  文件连 `--force` 拒绝/`--no-skills` 两条都不装）+ doctor 组（3.4 的四态）；沿用它的 scratch-tree 翻转法做红侧。 ·
  证据：扩展组逐条 `✓` · **P298 按证据勾**：V50 §2.1（独立复跑 `✓136 ✗0 SKIP0`）+ §8 的 `ext-skip` 变异；我复跑全量 `install-shape.sh` = `✓136 ✗0 SKIP0`，`⑧a/⑧b` 两条对照→翻转都在（原文见报告 §3）
- [x] 4.4 表 ↔ CLI 的探针（放进 4.1 或独立小组）：表里每行路径喂 `--teamsmith-slash-probe`，判据是**不得**出现顶层
  `未知子命令：<命令>`（`design.md` §3.2；`proposal.md` Evidence ④ 是实测样本）。红侧：临时加一行 `frobnicate` ⇒
  该条必红，删掉 ⇒ 绿。 · 证据：红→绿两次输出 · **P298 按证据勾**：夹具 `probe` 组（`slash-team.sh:426-450`：18 条 + 非空洞「至少 5 行」+ 红侧样本）；**红→绿两态**由 `--flip` 的对照/变异两轮给出，我复跑原文：对照 `pass=20 fail=0` ⇒ `table-frobnicate` 变异 `pass=20 fail=1`（红行 `✗ 表里这一行 CLI 真的分发：team frobnicate（✗ 未知子命令：frobnicate…）`），删掉即回绿
- [x] 4.5 门禁接线：`tests/smoke.sh` 加新段（**下一个空闲段号，以 apply 时 sources 为准**；形状照 §62/§63：跑 4.1，
  真进程的 4.2 放进有可见 SKIP 的分支或全量，FAST 里显式打印跳过并点名）；`tests/section-paths.tsv` 一行
  （覆盖 `skills/teamsmith/extension/team.ts`、`tests/slash-team.sh`、`tests/slash-team-e2e.sh`、
  `scripts/lib/cmd-init.sh`、`cmd-project.sh`）；`tests/section-budgets.tsv` 一行（**必须有实测 band**，不许留空）。
  · 证据：`section-select.sh --check` rc=0 + `--paths skills/teamsmith/extension/team.ts` 的 RUN 决定点名新段 · **P298 按证据勾**：报告有 `--select 65`（`✓2 ✗0 SKIP0`）、`--check`（ok 8 bad 0 SKIP 1）、`--budget-check`（132/132）与 64→65 的冲突处置；我复跑 `--check` rc=0、`--paths skills/teamsmith/extension/team.ts` → `65 ← …` rc=0、`TEAM_SMOKE_FAST=1 … --select 65` → `✓1 ✗0 SKIP1` rc=0（SKIP 行逐字点名端到端段）；段表两行在 `section-paths.tsv:156`/`section-budgets.tsv:158`（覆盖本项点名的五个路径 + `cmd-bootstrap.sh`）
- [x] 4.6 红侧总表（每条都要「破坏实现 ⇒ 必红 ⇒ 还原 ⇒ 绿」的原始输出）：改白名单表一行 / 短路拒绝分支 /
  清空 unset 列表 / 去掉失败通知 / 把 sendMessage 换成 notify / 去掉保险丝 / 安装改成无条件覆盖。 · 证据：红→绿
  原始输出（写进报告） · **P298 按证据勾**（**证据形态偏差**）：报告贴了汇总 + 安装层 `⑧a/⑧b` 的原始输出，七条纯逻辑臂的具名红行没贴 → 我复跑 `--all --flip` 取原文（7/7：`table-frobnicate`/`refuse-short-circuit`/`unset-empty`/`no-failure-notify`/`entry-to-notify`/`no-fuse`/`menu-decoupled`，每条「对照绿 → 变异红 + 具名红行」，见报告 §3）

## 5 收尾

- [x] 5.1 `skills/teamsmith/SKILL.md` 的扩展表加一行：`extension/team.ts` → 由 `team init` 装到
  `.pi/extensions/`（自动发现、`/reload` 生效、**不在 worker worktree**），与 `-e` 那一行的差别写清楚。
  （不承载规格场景；新能力的用户可见性。） · 证据：`grep -n 'extension/team.ts' skills/teamsmith/SKILL.md` · **P298 按证据勾**：我复跑该命令 → `167:`（`team init` 装到 `.pi/extensions/`、自动发现、`/reload` 生效、不在 worker worktree、与 `-e` 的差别写成 `deliberately not injected with -e`）；提交 `26731d00`
- [x] 5.2 `skills/teamsmith/references/troubleshooting.md` 的扩展小节加一行「`/team` 不出现怎么办」：
  `team doctor` → `team init`（缺失）或 `team init --force`（漂移）→ `/reload`。
  （不承载规格场景；doctor 行的排障出路。） · 证据：`grep -n '/team' skills/teamsmith/references/troubleshooting.md` · **P298 按证据勾**：我复跑该命令 → `649-652` 即那一小节（doctor 的 `/team 扩展安装` 行 → `team init`/`--force` → `/reload`）；提交 `26731d00`
- [x] 5.3 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check`；全量门禁
  留给 PM 复验，按纪律后台跑（不进树、跑前跑后指纹一致）。 · 证据：各命令 rc 与输出尾 · **P298 按证据勾**（**证据缺口 G2**）：`TEAM_SMOKE_FAST=1` 与 `spec-refs.sh --check` 在作者报告与 V50 里都 0 命中（我全文查过）→ 我在合并后的树上补跑：FAST `--select 65` rc=0 `✓22 ✗0 SKIP1`、`spec-refs.sh --check` rc=0 `undeclared 0`、`validate --all --strict` 22/0、`ledger-ban` hits=0；报告已记的三次全量选段的红逐条归因（P67 那 9 条＝D194 已知环境红）。全量留给 PM
- [x] 5.4 报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、4.6 的红→绿、4.2 的 JSONL 尾、未跑什么
  （点名承担者），并按报告模板的节名组织。 · 证据：报告提交在分支 tip 上，产品提交都在它之前 · **P298 按证据勾**（**实际做法**）：报告在 `f5cf8503`，其后只有两个只动该报告的记录提交（`5f5f3ece`、`753d787e`）——字面的「报告在 tip 上」不成立，意图成立（`git diff --stat f5cf8503..753d787e -- . ':(exclude)docs/team/**'` 为空）；另：报告里第三次门禁的树 `f5f3ece` 在仓里解析不了（应是 `5f5f3ece`，见 G4）

## 6 独立验证（另一席位，不是 apply 作者）

- [x] 6.1 在独立冻结克隆上重跑 4.1–4.5 的全部组与保留回归（`install-shape.sh` 全组、相关门禁段）；逐条给 · 证据（PM 按事实勾）：V50 在独立克隆（`reviews/V50/checkout`，受检 `753d787e`）上重跑了第 1–5 节的全场景与保留回归：`docs/team/reviews/V50.md`（8 项全绿）
  command/assertion/rc 与 skip，缺测不标 pass。 · 证据：独立记录 + 原始日志
- [x] 6.2 逐条重做 4.6 的红侧（不是复跑绿侧），并**独立**造两格：把表里一行改成 CLI 不认的命令（4.4 的方向）与 · 证据（PM 按事实勾）：V50 自造三段红侧（白名单外命令、变量剥离、安装三路径）各自破坏→红点名→还原→绿：`docs/team/reviews/V50.md`
  一个会话里 `TEAM_ASSUME_YES=1` 的真 CLI 预览（配置字节不变）。 · 证据：red→green 原始输出
- [x] 6.3 反面证据：`/team up`、`/team --fresh-pm`、表外命令、读行多余 token、未闭合引号 —— 每条都要 · 证据（PM 按事实勾）：V50 逐条重做作者的三层翻转证据并自设至少一条相邻反例（含「对话里提到 /team 不执行任何东西」的探针）：`docs/team/reviews/V50.md`
  「零子进程」的证据（桩日志为空），不是只看文案。 · 证据：桩日志与命令行
- [x] 6.4 判 `verification` 的 correctness 门：只有证据通过；不因为「作者报告说绿」判过。 · 证据： · 证据（PM 按事实勾）：PM 据 V50 的证据判过门（PASS，见本清单下方注记与 `docs/team/reviews/P298.md`）；判定不以 apply 报告为依据
  `docs/team/reviews/<ID>.md`

## 7 apply / verify 的验收命令（本阶段不运行）

```bash
bash skills/teamsmith/tests/slash-team.sh                 # 纯逻辑（bun + 假 pi）
bash skills/teamsmith/tests/slash-team-e2e.sh             # 真 pi RPC（无模型/无网络/不碰 ~/.pi）
bash skills/teamsmith/tests/install-shape.sh install conflict doctor
bash skills/teamsmith/tests/smoke.sh --select <新段 key>
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

红侧按 4.6 逐条现场改坏再还原；场景名与红侧方向不得改（改合同要回提案）。

**粒度**：一个 apply 简报能独立做完（一个新产品文件 + 安装/doctor 接缝 + 三层测试 + 门禁登记），不拆多任务；
4.5 里的段号以 apply 时的 sources 为准。
