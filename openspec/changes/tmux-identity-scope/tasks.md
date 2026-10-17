# tmux-identity-scope · tasks

阶段口径：**propose**（本批次）只写提案，不碰产品代码；**apply** 分两批（写侧 / 读侧，同一分支串行）；
**verify** 由**另一个**席位（不是 apply 作者，dispatch 的自验守卫会拦）在独立克隆上重跑本表全部场景与红侧。
本文件不是规格；合同文本在 `specs/pm-lifecycle/spec.md`（2 ADDED）与 `specs/boundary/spec.md`（1 MODIFIED）。

写集（apply）：`skills/teamsmith/scripts/lib/common.sh`、`skills/teamsmith/scripts/lib/cmd-watch.sh`、
`skills/teamsmith/scripts/lib/cmd-agents.sh`、`skills/teamsmith/scripts/lib/cmd-draft.sh`、
`skills/teamsmith/scripts/lib/cmd-project.sh`、`skills/teamsmith/scripts/shim/tmux`（仅裁定点 C 选 A1）、
`skills/teamsmith/tests/tmux-identity-leak.sh`（新）、`skills/teamsmith/tests/smoke.sh`、
`skills/teamsmith/tests/section-paths.tsv`、`skills/teamsmith/tests/section-budgets.tsv`（裁定点 D）。
这三张表此刻有在飞写者（P251/P261 在写、P264 排队）：交付前 `git merge main`，冲突按双方保留。

## 0 冻结与基线（apply 的第一件事）

- [x] 0.1 读 PM 的提案评审 `docs/team/reviews/tmux-identity-scope-proposal.md`，逐条确认裁定点 A–E，
  结论摘进报告；与提案不同的裁定按其改写判定与场景（合同方向不变）。 · 证据：评审记录 + 报告摘录 · P307 按事实勾：`docs/team/reviews/tmux-identity-scope-proposal.md` 判定 ACCEPTED（A–E 全采纳作者推荐）：A 由两报告的 `deltas: -` 落实（delta 文本未改），B 见 `common.sh` 的 `team_tmux_ensure_session`（四个 `-e`），C=A1 见 `shim/tmux` 的 `_shim_resolve_log`，D 见 `tests/tmux-identity-leak.sh`，E 见 `cmd-project.sh` 的 doctor 残留行；摘录见 P274 报告「落点与裁定点的对应」与 P304 报告「答案」段
- [x] 0.2 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec &&
  (cd /tmp/<x> && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y tmux-identity-scope &&
  "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)` 必须绿（拷贝要嵌在
  `<x>/openspec` 下）。归档后逐条核对两条 ADDED 与那条 MODIFIED：MODIFIED 的既有八条场景与三段正文
  逐字保留、没有第二个未归档 change 动 `pm-lifecycle`/`boundary`。 · 证据：投影命令与输出尾 · P307 按事实勾：P307 2026-10-17 复跑投影（`/tmp/p307-proj`）：`archive -y` rc=0（`archived as '2026-10-17-tmux-identity-scope'`），随后 `validate --all --strict` 19 passed 0 failed rc=0；逐条核对：`boundary` 79 → 80 个 `#### Scenario`（diff 的 `-` 行只有被 MODIFIED 取代的那段旧正文，无场景丢失），`pm-lifecycle` 16 → 23 且新增的两个 `### Requirement` 正是两条 ADDED；未归档 change 的 specs 里 `grep -rln` 只命中本 change
- [ ] 0.3 冻结**改动前**基线并抄进报告（私有 socket、私有 fixture 项目，不许碰真实 server）：
  ① 机制探针：`new-session` 把启动者环境写进全局环境、`-e` 只写会话环境、`kill-*`/`list-*` 不建 socket；
  ② 真 CLI：`team up`（stub PM 命令）后 `tmux show-environment -g | grep -c '^TEAM_'`（本 worktree 实测
  **12**）、同一项目会话环境 **0**；③ 项目 B 的 pane 继承值 + 在 B 目录跑 `team up` 的
  **rc=1 + `身份冲突被拒`**；④ `smoke.sh --select 32` 改动前的 ✓/✗ 计数。 · 证据：基线日志

## 1 apply-1 · 写侧与审计（规格 `pm-lifecycle#Starting this project's tmux objects never writes its identity into the shared server's environment`、`boundary#The gate's actions are logged, and no window carries a destructive-call grant`）

- [x] 1.1 `common.sh` 加 tmux 调用包装：建对象动词（`new-session`/`new-window`/`split-window`/`respawn-*`）
  在子进程环境里摘掉**整个** `TEAM_*` 命名空间；kill 类保留环境（M67 闸门要绑身份，且它们不可能启动
  server）。包装是产品面唯一的 tmux 出口（新增调用点必须走它）。 · 证据：改动后的函数 + `grep -n 'command tmux'` 的出口清单 · P307 按事实勾：`common.sh:2040–2075` 的 `team_tmux`（`team_tmux_verb` / `team_tmux_starts_server` / `team_tmux_strip_identity`；只有可能起 server 的动词走子 shell + strip）；`grep -rn 'command tmux' skills/teamsmith/scripts/` 只有两行 —— `common.sh:2071`（建对象）与 `:2073`（其余动词保留环境），别的产品文件零命中
- [x] 1.2 建对象调用点接入包装：`team_tmux_ensure_session`（`common.sh`）、`team_tmux_new_window`
  （`common.sh`）、pulse 窗口（`cmd-watch.sh`）、派单占位窗口（`cmd-agents.sh`）、草稿窗口（`cmd-draft.sh`）。
  按裁定点 B：若裁「加 `-e`」，`new-session` 带四个身份变量的 `-e`（会话作用域），并证明全局环境不变。
  · 证据：每个调用点的 diff + 会话环境/全局环境的对照 · P307 按事实勾：`-e` 在 `common.sh:2085–2095`（四个身份变量，仅非空时追加）；建对象调用点：`cmd-watch.sh:2079`（pulse 窗口）、`cmd-agents.sh:1458`（派单占位窗口）、`cmd-draft.sh:61`（草稿窗口）、`common.sh:2165`（`team_tmux_new_window`）；对照（2026-10-17 复跑 `--all` ✓66 ✗0）：②a/②b 会话作用域恰好 4 条、①c/②c 全局环境 0 条且建窗后仍 0
- [x] 1.3 裁定点 C 选 A1 时：`shim/tmux` 的日志目标在 `$TEAM_TMUX_CALLS_LOG` 缺席时解析到 cwd 所属项目的
  `state/tmux-calls.log`（向上找 `.pi/team`，不启子进程；找不到就不写），pin 存在时行为逐字节不变。
  · 证据：改后的解析片段 + 两条路径的实测日志行 · P307 按事实勾：`shim/tmux:329–347` 的 `_shim_resolve_log`（向上找 `.pi/team`，只做 `[ -d ]` 测试，解析不出就不写）；两条路径 2026-10-17 复跑：④a pin 缺席 + 项目目录 → 日志恰好 +1 行，④b 非项目目录 → 零写且不建 `.pi`；`--break=log` 时 ④a 红（期望 [1] 实际 [0]）
- [x] 1.4 新夹具 `tests/tmux-identity-leak.sh`：私有 socket/私有 fixture（沿用 `tests/lib/tmux-iso.sh` 的
  隔离写法），`--all/--select`、末行 ✓/✗ 计数；红侧 1（全局环境零 `TEAM_*`：真 CLI `team up` 后
  `show-environment -g` 无本项目 `TEAM_*`、项目 B 的 session pane 也没有）与红侧 4（审计：pin 缺席时
  cwd 所属项目日志恰好 +1 行、非项目目录不写）。 · 证据：`--all` 输出尾 + 两条红侧的原始输出 · P307 按事实勾：`bash skills/teamsmith/tests/tmux-identity-leak.sh --all` 2026-10-17 = `✓ 66  ✗ 0` rc=0（末行计数、私有 socket 岛）；红侧 1 的原始输出见 1.5 段（`--break=strip`：①c/①d「期望 [0] 实际 [11]」并列出泄漏变量），红侧 4 见 1.3 段（`--break=log`：④a）
- [x] 1.5 红侧 1/4 的**翻转**：把建对象调用改回「带环境」（一行变异）→ 红侧 1 必须红并点名全局环境里的
  变量；去掉 A1 的 fallback → 红侧 4 必须红；各自还原后绿。 · 证据：两次变异的原始输出 + 还原后的绿 · P307 按事实勾：2026-10-17 复跑两条变异（改的是夹具私有根里的产品源码副本，本树逐字节不变）：`--select write-side --break=strip` → `✓ 7 ✗ 2` rc=1，①c/①d「期望 [0] 实际 [11]」并逐条点名 11 个泄漏变量；`--select audit --break=log` → `✓ 6 ✗ 1` rc=1，④a「期望 [1] 实际 [0]」；还原后 `--all` ✓66 ✗0、`--select write-side` ✓9 ✗0；P274 报告「红侧证据」表是同一组红侧的原始记录
- [ ] 1.6 门禁接入（裁定点 D）：`smoke.sh` §32 调用新夹具；`section-budgets.tsv` 的 §32 行按**实测**
  max(host/container/ci) 重填；`section-paths.tsv` 的 §32 patterns 补
  `skills/teamsmith/scripts/lib/common.sh`。`section-guard.sh --budget-check` 必须绿。
  · 证据：三处 diff + `--budget-check` 输出尾

## 2 apply-2 · 读侧归因与自愈（规格 `pm-lifecycle#Identity inherited from the shared server's global environment resolves by the working directory`）

- [x] 2.1 `common.sh` 加**来源归因**：冲突对里**每一个**变量的继承值都等于 `tmux show-environment -g V`
  的值（且 TMUX 非空）→ 判为共享 server 残留。全部可归因才放行（半可归因 = 不可归因）。实现复用既有的
  冲突对函数，不新造第二份身份解析。 · 证据：改动后的函数 + 两种形状（全/半）的判定输出 · P307 按事实勾：`common.sh:616–650` 的 `team_identity_server_global_value`（只读 `show-environment -g`）与 `team_identity_server_residue`（TMUX 非空 **且** 每个冲突变量都等于全局环境里的值；复用 `team_identity_conflict_pairs`，无第二份解析）；两种形状 2026-10-17 复跑：全可归因 → ⑤c–⑤h 绿，半可归因 → ⑥b 仍 rc=1
- [x] 2.2 可归因路径：按 cwd 解析、**stderr** 一行点名「运行中的 tmux server 的全局环境」+ 那条清除命令；
  **不**清、**不**重写共享 server 的任何东西；只读/机读出口的 stdout 不受影响。 · 证据：真 CLI 的输出
  （stdout/stderr 分开抓） · P307 按事实勾：`common.sh:660–676` 的 `team_identity_residue_note`（stderr 一行，点名「运行中的 tmux server 的全局环境」+ `set-environment -gu` 链）；夹具 2026-10-17：⑤e 说明行走 stderr 且 stdout 是纯数据、⑤g 全局环境逐字节未变、⑤h 调用者环境原样、⑤f A 的会话未变、⑤c/⑤d 按 cwd 建出 B 的会话（`--select residue` ✓15 ✗0）
- [x] 2.3 不可归因路径逐字不变：显式外来环境（§32③/§32⑧a 的形状）、值不在全局环境里的分歧、无 tmux、
  真嵌套 —— 拒绝措辞/退出码/`TEAM_ALLOW_FOREIGN_IDENTITY=1` 出路照旧。 · 证据：§32③/⑧a 的原始输出 · P307 按事实勾：`common.sh:632` 的 `[ -n "${TMUX:-}" ] || return 1`（无 tmux 一律不可归因）；⑥a 显式外来环境仍 rc=1 + 同一句「身份冲突被拒」+ 无说明行 + 未建对象/未清全局，⑥b 半可归因 rc=1，⑥c 真嵌套 rc=0 且无说明行、不写全局（2026-10-17 复跑）；§32③/⑧a 的拒绝面在 P274 记录里 `✓73 ✗0`（该段本轮未重跑）
- [x] 2.4 `team doctor` 只读残留行（裁定点 E）：点名变量 + 清除命令，跑完全局环境逐字节未变。
  · 证据：doctor 输出 + 前后 `show-environment -g` 的字节比较 · P307 按事实勾：`cmd-project.sh:411–415` 的 `team_identity_server_residue_vars`（只报本项目自己的值）；夹具 2026-10-17 复跑 ⑦a–⑦e 全绿：⑦b 点名变量 + 清除命令、⑦c 跑完全局环境逐字节未变、⑦c 项目 state 无新增、⑦c2 有闸门时唯一变化是闸门自己的审计行、⑦d/⑦e 不冒充别人的残留
- [x] 2.5 夹具补红侧 2/3：② 污染模拟（`set-environment -g` 设成 A 的值 → B 的目录里 `team up` rc=0、
  说明行、建出 B 的对象、A 未动、全局环境未变）；③ 非归因照旧拒绝 + 真嵌套不误清（无说明行、无清除、
  无全局环境写入）。 · 证据：两条红侧的原始输出 · P307 按事实勾：⑤（15 条）与 ⑥（16 条）两组 2026-10-17 复跑全绿：⑤c 残留形状 rc=0、⑤d 建出的是 B 的会话且会话作用域恰好四条、⑤e stderr 一行、⑤g 全局环境逐字节未变、⑤h 调用者环境原样；⑥a/⑥b 照旧拒绝、⑥c 真嵌套不误清
- [x] 2.6 红侧 2/3 的**翻转**：关掉归因（改成不可归因）→ 红侧 2 必须红（回到 rc=1 + `身份冲突被拒`）；
  把归因改成无条件放行 → 红侧 3 必须红；各自还原后绿。 · 证据：两次变异的原始输出 + 还原后的绿 · P307 按事实勾：`bash skills/teamsmith/tests/flip-p304-read-side.sh` 2026-10-17 = rc=0「FLIP 全绿」：red-refuse rc=1 ✗6（点名 ⑤c/⑤e）、red-attrib-any rc=1 ✗6（点名 ⑥a/⑥b）、red-doctor-write rc=1 ✗4（点名 ⑦c/⑦c2），三条还原 rc=0 ✗0；每条腿的 ✗ 明细在 P304 报告 §Flip evidence

## 3 隔离与可单跑

- [x] 3.1 夹具只写私有 socket 与私有 fixture 根；跑完断言真实仓库 `docs/team/inbox/**`、
  `.pi/team/state/**`（含 `tmux-calls.log`）未被改动（前后 hash 对比），任一变化即 fail 并打印差异。
  · 证据：隔离断言输出 + 前后 hash · P307 按事实勾：夹具 `:138–148` 的 `ledger_manifest`（逐文件 sha256）与 `:717–731` 的收口断言（不等就打印 diff 并 fail）；2026-10-17 `--all` 输出「隔离：真实仓库账本面未被改动」「隔离：本轮的临时根已回收（跑前 1 个同族根 → 跑后 1 个）」。边界：本 worktree 没有 `docs/team/inbox` 与 `.pi/team/state`，该断言在这里比对的是 0 个文件的空集（有牙的形态见 V56 在独立树上的复核）
- [x] 3.2 `perl tests/tmux-lint.pl --selftest` 与 `perl tests/tmux-lint.pl` 绿（新夹具的 tmux 调用全部
  私有 socket、无绝对路径）。 · 证据：两条命令的输出尾 · P308 按事实勾：2026-10-17 两条都真跑且 rc=0 —— `--selftest` → `✓ tmux-lint --selftest：37 个夹具 + 历史豁免机制全部符合预期（该红的红、该净的净）`；真树扫描 → `tmux-lint：干净（扫描 94 个脚本，234 条变更命令全部有隔离证据）`。真树这一条原先红在 **16 条过期豁免**（全部指向当前历史里已不存在的 `docs/team/reports/*/pkg/*.sh`），按清单自身的规则「删文件就同时删豁免行」清空，前后计数 **16 → 0**（原因与证据见 `docs/team/reports/P308-dev2.md`）
- [x] 3.3 `bash tests/tmux-identity-leak.sh --select <组名>` 可单跑并打印本组 ✓/✗。
  · 证据：单跑输出 · P307 按事实勾：`bash skills/teamsmith/tests/tmux-identity-leak.sh --select residue` 2026-10-17 = 本组 `✓ 15 ✗ 0` rc=0，只打印该组；组键白名单在 `:85–86`（未知键 rc=2）

## 4 验收与交付

- [x] 4.1 跑齐 proposal「Acceptance」的全部命令（新夹具 `--all`、`smoke.sh --select 32`、
  `section-guard.sh --budget-check`、`tmux-lint.pl --selftest`、`spec-refs.sh --check`、`ledger-ban`、
  `openspec validate --all --strict`、投影自证），报告贴真实命令与输出尾。
  · 证据：命令日志 · P307 按事实勾：八条命令逐条真跑过：fixture `--all`（✓66 ✗0，本轮）、`smoke.sh --select 32`（P274 记录 §32 `✓73 ✗0`）、`section-guard.sh --budget-check`（2026-10-17 rc=0，135/135 段）、`tmux-lint.pl --selftest`（rc=0，37 个夹具）、`spec-refs.sh --check`（**rc=1**，既有红：`openspec/specs/extension-slash/spec.md:47` 指向不存在的 `docs/team/tasks/P1.md`，与本次改动无关）、ledger-ban、`validate --all --strict`、投影自证（本轮 rc=0）；原始输出见 P274/P304 报告与 P307 报告
- [x] 4.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 1.5/2.6 节的变异与还原
  **原始输出**就是本任务的翻转证据（红→绿、绿→红→绿）；写明任何未测项与失败。 · P307 按事实勾：P274 报告（§Verification 的命令/rc/输出尾、§红侧证据表、§未做/发现）与 P304 报告（§Verification、§Flip evidence 六条腿、§没验的/边界）已把 1.5/2.6 的变异原始输出逐条贴出；本轮 P307 又把两次翻转与六条腿重跑一遍，原始输出见 P307 报告
- [x] 4.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；不合并不推送，分支留本地；
  `team notify pm` 一行交付说明。 · P307 按事实勾：P274 分支 7 个提交（`24be1df3` 产品、`ed21f04a`/`95e0c388` 夹具、`926feea1` 修正、`cb6d9344` 报告、`7e618f5f` 夹具返修、`911f0353` 返修记录）与 P304 分支 6 个（`d4fe80cf`/`2c7bc853` 产品、`ee9246e9`/`d163e068`/`13bf9bb0` 夹具、`14c1863c` 报告 + 翻转驱动），每条都带任务号与 `Agent: dev2`；两条分支都留本地、由 PM 复验后 squash 合并（main 上的 `a1a53292`/`f3a4c7c1` 是 PM 的合并提交），交付时各自 `team notify pm`

## 5 独立验证（另一席位，不是 apply 作者）

- [x] 5.1 在独立克隆上重跑 `tests/tmux-identity-leak.sh --all` 与 `smoke.sh --select 32`，确认既有 · 证据（PM 按事实勾）：V48（写侧）与 V56（读侧）两轮独立复验各自在独立克隆上重跑并贴原始输出：`docs/team/reviews/V48.md`、`docs/team/reviews/V56.md`
  §32①–⑧ 回归 + 新组全绿。 · 证据：独立日志
- [x] 5.2 逐条重做第 1.5/2.6 节的四次变异与还原（不是只复跑绿侧）。 · 证据：复验记录 · 证据（PM 按事实勾）：V48/V56 逐条重做第 1.5/2.6 节的变异与还原（并自设反例）：两份记录各自的小节
- [x] 5.3 自设计反例：① 全局环境里**只**有部分冲突变量时是否仍拒绝；② 归因后同一 pane 里连续多条命令 · 证据（PM 按事实勾）：V56 自设两条反例（部分冲突变量仍拒绝；归因后同一路径可用）并在记录里给原始输出
  是否都按 cwd 执行（且都不写共享 server）；③ 会话里**人手**新开窗口的 `kill-*` 判定是否与今天一致
  （裁定点 B 的对照臂）；④ `-e` 的会话身份是否**只**落在会话作用域（全局环境仍逐字节干净）。
  · 证据：反例输出
- [x] 5.4 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。 · 证据（PM 按事实勾）：PM 据 V48 与 V56 的证据判过 `verification` 门（PASS）；判定不以 apply 报告为依据（本轮还据此翻出「跳过当通过」一处假绿）
  · 证据：`docs/team/reviews/<ID>.md`

## 未勾项与原因（P307 按事实留空）

本清单一律按事实勾：只有在提交、报告小节或本轮复跑输出里找得到证据的项才勾。以下四项留空，原因逐条写清。

- **0.3 改动前基线**：apply 的交付记录里没有这份基线。P274 报告的「探针原始数字」是**改动后**的读数（`global_TEAM_count=0`、负对照 4/4），报告里既没有改动前的「全局 12 个 `TEAM_*` / 同一项目会话 0 个」，也没有改动前的 `smoke.sh --select 32` ✓/✗ 计数。这些事实别处有：提案 `proposal.md`「现状复核」第 2/3 条是改动前实测（全局 12、会话 0、B 目录 `rc=1` + `身份冲突被拒`），V48 又在 main（改动前的代码）上独立复测到同一个 12 → 候选 0。所以缺的不是事实，是 **apply 侧在改动前冻结并抄进报告的那份日志**；P307 不能事后补造成「改动前」。
- **1.6 门禁接入**：没落地。`grep -n 'tmux-identity-leak' skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/section-paths.tsv skills/teamsmith/tests/section-budgets.tsv` 三份文件零命中 —— §32 仍是旧段（`身份 = 运行时目录（M40）`），新夹具只被 `loop-inventory.tsv` 盯着（3 行循环登记）。P274 与 P304 两轮都记录了这条未做（写集串行：`smoke.sh` 与两张 tsv 当时有在飞写者），P304 的「没验的」第 4 条并指出「跑 `--all` 的只有人」。按裁定点 D，这条不接就等于合同在增量跑里没有牙，是真缺口而不是记账遗漏；接之前必须先修 1 号观察（见 P307 报告）。
- **3.2 真树 lint**：`perl skills/teamsmith/tests/tmux-lint.pl --selftest` 绿（37 个夹具，rc=0，本轮复跑），但 `perl skills/teamsmith/tests/tmux-lint.pl`（不带 `--selftest` 的真树扫描）**rc=1**：`豁免清单过期（16 个问题；扫描 93 个脚本）`，16 条全部指向已从仓库删掉的 `docs/team/reports/*/pkg/*.sh`。这条红在 main 上一样存在（`git cat-file -e main:docs/team/reports/V4.0/pkg/run.sh` → rc=128，且 `git diff main -- skills/teamsmith/tests/tmux-lint-legacy.txt` 为空），与本次改动无关；但清单第 3.2 条要求的是**两条都绿**，所以按事实留空，不拿「既有红」当绿。
- **5.1–5.4 独立验证**：apply 作者不验自己，留给 PM 勾（引用 V48/V56）。

## 后续修订（P308）

- **3.2 已勾**（2026-10-17）：`--selftest` 与真树扫描两条 rc=0；16 条过期豁免按清单自身规则删掉（16 → 0）。
- **1.6 仍然留空，但它的前置条件已经修好**：V48 的 F1′（「跳过不是通过」没兑现）已由 P308 修掉 —— 收口判据从 `PASS==0 && FAIL==0` 改成**按段数**判（需要 tmux 的段一段都没跑 → rc=77），现场复现见 `docs/team/reports/P308-dev2.md` 的翻转证据。§32 的三处接线（`smoke.sh` / `section-budgets.tsv` / `section-paths.tsv`）本轮**没动**：P297 正在改 `smoke.sh`，按单写者纪律串行（任务书第一部分明写不碰这三份文件）。
