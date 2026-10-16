# slash-team · tasks

范围：`extension-slash`（新能力）与 `init-skill` 的三条 MODIFIED（delta 文件见 `specs/`），设计见 `design.md`，
动机与裁定点见 `proposal.md`。**apply 只能在 PM 的提案评审（`docs/team/reviews/slash-team-proposal.md`）判
ACCEPTED 之后开始**——本清单是 apply 席位的执行面，写它的阶段一条都不执行。

## 1 冻结与读入口

- [ ] 1.1 读 PM 的提案评审，确认四个裁定点（大输出进上下文 / 环境剥离 / doctor 行 / 安装默认软链）的结论；与
  `proposal.md` 的推荐不一致的，按评审的结论改**规格**并重新评审，不改验收方向。 · 证据：评审记录的点名引用
- [ ] 1.2 读基线：`openspec/specs/init-skill/spec.md` 的三条被 MODIFIED 的需求（逐字，含全部场景）、
  `boundary#Actions stay inside the project and its own session`（跨项目边界不在本变更重写）、
  `verification#A changed-path list selects the sections to run, or the full suite`（新段的登记规则）。 · 证据：读过的行号
- [ ] 1.3 冻结两张表：白名单十五条（`design.md` §3.2 的表，用户确认过的清单）与拒绝清单；冻结后不再增删
  （增删＝改合同，回提案）。 · 证据：`git diff` 只出现规格里写明的行

## 2 扩展本体（规格：`extension-slash` 六条需求）

- [ ] 2.1 `skills/teamsmith/extension/team.ts`（单文件、零运行时依赖、Pi 侧只 `import type`，所以
  `bun -e "await import(...)"` 能加载）：默认导出工厂（`registerCommand("team", …)`），并把**纯逻辑**具名导出
  （白名单表、分词、匹配、菜单渲染、项目根/CLI 解析、`runTeamCommand(deps, argv)`）——纯逻辑不碰任何 Pi API，
  夹具用假 pi 直接驱动。文件首行是安装标记 `// teamsmith /team extension`（§3.6 的识别依据）。 · 证据：文件 +
  `bash -n` 无关、`bun -e` 导入成功；`grep -c registerTool` = 0
- [ ] 2.2 白名单：十五条（11 读 + 4 动），读行严格形状、动行路径 + 自由尾巴；匹配器把整个 argv 吃完才算命中。 ·
  证据：`design.md` §3.2 的表与代码逐行对应
- [ ] 2.3 分词：空白分隔、单/双引号、引号外反斜杠转义；**未闭合引号 ⇒ 拒绝且不起进程**。 · 证据：夹具里的
  引号/空格/未闭合三组
- [ ] 2.4 项目根与 CLI 解析（顺序见 §3.5）：向上找 `.pi/team/config.sh`；CLI = 项目本地 skills 路径 →
  `${TEAM_CLI}` → 扩展兄弟目录 → 拒绝并指名 `team init`。 · 证据：夹具逐格（有/无项目本地、有/无 env、都不是）
- [ ] 2.5 菜单与补全：`/team`（无参）与 `/team help` 从同一张表渲染两组 + 结尾一句「表外命令请到终端」；
  `getArgumentCompletions` 的首词集合来自同一张表的命令路径。 · 证据：夹具断言「表加一行 ⇒ 菜单与补全都出现」
- [ ] 2.6 拒绝路径：表外命令、读行的多余 token、`up`/任何带 `--fresh-pm` 的调用——各自的文案**点名**被拒的命令/
  token，表外说明「这是 PM / 席位的命令，请到终端执行」，`up`/`--fresh-pm` 说明「这个会话就是 PM 会话，从这里
  重启会把当前对话一起带走」，全部**零副作用**。 · 证据：夹具里 `exec` 未被调用
- [ ] 2.7 执行与输出：`pi.exec("bash", ["-c", 'unset TEAM_ASSUME_YES TEAM_UPGRADE_CONFIRMED TEAM_ALLOW_FOREIGN_SESSION; exec "$0" "$@"', cli, …tokens], {cwd, timeout: 60000})`；
  短结果（单行 ≤ 200 字符、退出 0）→ 通知；其它 → `pi.sendMessage({customType: "teamsmith-team", content, display: true})`，
  正文头是 `$ team <argv…>` + `exit <code>`（或 killed 原因）+ stdout/stderr；失败再加 error 通知；保险丝 500 行/
  64 KiB（前 200 + 后 100 + 省略说明）；`up`/`--fresh-pm` 之外不注入任何 token。 · 证据：夹具逐格（短/长/失败/杀/超量）
- [ ] 2.8 结构性保证：`registerTool` 零调用、`ui.confirm` 零调用（前门不给自己加政策）。 · 证据：假 pi 的调用记录

## 3 安装面（规格：`init-skill` 三条 MODIFIED）

- [ ] 3.1 `scripts/lib/cmd-init.sh`：在同一个安装实现里加扩展安装（`<main>/.pi/extensions/team.ts` ←
  `$TEAM_SKILL_DIR/extension/team.ts`），默认软链、`--copy` 复制、`--no-skills` 连扩展一起跳过；冲突表与技能同款：
  同源软链/同字节副本 = skip；指向别处/带标记的副本 = 冲突（`--force` 换本源）；**不带标记的普通文件连
  `--force` 都不删**（红线）。 · 证据：`tests/install-shape.sh` 的扩展组（4.3）
- [ ] 3.2 `team_gitignore_add` 加 `.pi/extensions/`；安装输出每个条目一行（`link/copy/skip`），扩展那一行与技能同格式。 ·
  证据：夹具输出尾
- [ ] 3.3 信任提示行同时点名 `.pi/skills/` 与 `.pi/extensions/`（答案不变、仍一行、`--no-skills` 不打）；同步
  `skills/teamsmith-init/SKILL.md` 的安装节与 `skills/teamsmith-init/references/bootstrap.md` 的项目技能行一句。 ·
  证据：两个文件里 `.pi/extensions/` 与 `/trust` 同页出现（`init-skill` 的场景 3 红侧：删掉再搜必红）
- [ ] 3.4 `scripts/lib/cmd-project.sh` 的 doctor 加一行 `/team` 扩展：有项目本地安装时——软链指向本源或副本字节等于
  本源 = pass；缺失 = warn + 修法 `team init`；指向别处/副本漂移 = warn + `team init --force`；没有项目本地安装
  **一行都不打**；不影响 doctor 退出码。 · 证据：`install-shape.sh doctor` 组
- [ ] 3.5 `team bootstrap` 走同一实现（含既有 config 的升级路径）、`bootstrap --print` 照样只打印不写；扩展**不进**
  `team_skill_hash`（指纹仍只哈希 `SKILL.md` + `extension/team-notify.ts`）。 · 证据：夹具 + `grep team_skill_hash`

## 4 测试与门禁接线

- [ ] 4.1 `skills/teamsmith/tests/slash-team.sh`：bun `import` 源文件 + 假 pi 驱动（记录 `registerCommand`/
  `registerTool`/`exec`/`sendMessage`/`notify`/`confirm`），覆盖 2.2–2.8 的每一格（argv 逐字、cwd、菜单同源、
  补全、拒绝零副作用、短/长输出落点、退出码、被杀、保险丝、unset 列表、无工具/无确认）。 · 证据：脚本的
  `✓/✗` 计数与逐条名字
- [ ] 4.2 `skills/teamsmith/tests/slash-team-e2e.sh`：夹具项目（装扩展 + 记录 argv/cwd/env 的 `team` 桩）里跑
  `pi --mode rpc --no-session --approve`（`PI_CODING_AGENT_DIR` 指向夹具自己的空目录，**不读 `$HOME` 的 pi 配置、
  不写 trust store、不用网络、不用模型**），stdin 发 `/team …`，判 JSONL：回执 `disposition:"handled"`、
  `message_start` 的 `content`/`display`、notify 的 `notifyType`、桩记录的 argv/cwd/env。 · 证据：原始 JSONL 尾
- [ ] 4.3 `skills/teamsmith/tests/install-shape.sh`：加扩展组（不存在/软链同源/软链别处/副本同字节/副本漂移/无标记
  文件连 `--force` 拒绝/`--no-skills` 两条都不装）+ doctor 组（3.4 的四态）；沿用它的 scratch-tree 翻转法做红侧。 ·
  证据：扩展组逐条 `✓`
- [ ] 4.4 表 ↔ CLI 的探针（放进 4.1 或独立小组）：表里每行路径喂 `--teamsmith-slash-probe`，判据是**不得**出现顶层
  `未知子命令：<命令>`（`design.md` §3.2；`proposal.md` Evidence ④ 是实测样本）。红侧：临时加一行 `frobnicate` ⇒
  该条必红，删掉 ⇒ 绿。 · 证据：红→绿两次输出
- [ ] 4.5 门禁接线：`tests/smoke.sh` 加新段（**下一个空闲段号，以 apply 时 sources 为准**；形状照 §62/§63：跑 4.1，
  真进程的 4.2 放进有可见 SKIP 的分支或全量，FAST 里显式打印跳过并点名）；`tests/section-paths.tsv` 一行
  （覆盖 `skills/teamsmith/extension/team.ts`、`tests/slash-team.sh`、`tests/slash-team-e2e.sh`、
  `scripts/lib/cmd-init.sh`、`cmd-project.sh`）；`tests/section-budgets.tsv` 一行（**必须有实测 band**，不许留空）。
  · 证据：`section-select.sh --check` rc=0 + `--paths skills/teamsmith/extension/team.ts` 的 RUN 决定点名新段
- [ ] 4.6 红侧总表（每条都要「破坏实现 ⇒ 必红 ⇒ 还原 ⇒ 绿」的原始输出）：改白名单表一行 / 短路拒绝分支 /
  清空 unset 列表 / 去掉失败通知 / 把 sendMessage 换成 notify / 去掉保险丝 / 安装改成无条件覆盖。 · 证据：红→绿
  原始输出（写进报告）

## 5 收尾

- [ ] 5.1 `skills/teamsmith/SKILL.md` 的扩展表加一行：`extension/team.ts` → 由 `team init` 装到
  `.pi/extensions/`（自动发现、`/reload` 生效、**不在 worker worktree**），与 `-e` 那一行的差别写清楚。
  （不承载规格场景；新能力的用户可见性。） · 证据：`grep -n 'extension/team.ts' skills/teamsmith/SKILL.md`
- [ ] 5.2 `skills/teamsmith/references/troubleshooting.md` 的扩展小节加一行「`/team` 不出现怎么办」：
  `team doctor` → `team init`（缺失）或 `team init --force`（漂移）→ `/reload`。
  （不承载规格场景；doctor 行的排障出路。） · 证据：`grep -n '/team' skills/teamsmith/references/troubleshooting.md`
- [ ] 5.3 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check`；全量门禁
  留给 PM 复验，按纪律后台跑（不进树、跑前跑后指纹一致）。 · 证据：各命令 rc 与输出尾
- [ ] 5.4 报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、4.6 的红→绿、4.2 的 JSONL 尾、未跑什么
  （点名承担者），并按报告模板的节名组织。 · 证据：报告提交在分支 tip 上，产品提交都在它之前

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
