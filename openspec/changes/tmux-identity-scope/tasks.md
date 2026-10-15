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

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/tmux-identity-scope-proposal.md`，逐条确认裁定点 A–E，
  结论摘进报告；与提案不同的裁定按其改写判定与场景（合同方向不变）。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec &&
  (cd /tmp/<x> && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y tmux-identity-scope &&
  "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)` 必须绿（拷贝要嵌在
  `<x>/openspec` 下）。归档后逐条核对两条 ADDED 与那条 MODIFIED：MODIFIED 的既有八条场景与三段正文
  逐字保留、没有第二个未归档 change 动 `pm-lifecycle`/`boundary`。 · 证据：投影命令与输出尾
- [ ] 0.3 冻结**改动前**基线并抄进报告（私有 socket、私有 fixture 项目，不许碰真实 server）：
  ① 机制探针：`new-session` 把启动者环境写进全局环境、`-e` 只写会话环境、`kill-*`/`list-*` 不建 socket；
  ② 真 CLI：`team up`（stub PM 命令）后 `tmux show-environment -g | grep -c '^TEAM_'`（本 worktree 实测
  **12**）、同一项目会话环境 **0**；③ 项目 B 的 pane 继承值 + 在 B 目录跑 `team up` 的
  **rc=1 + `身份冲突被拒`**；④ `smoke.sh --select 32` 改动前的 ✓/✗ 计数。 · 证据：基线日志

## 1 apply-1 · 写侧与审计（规格 `pm-lifecycle#Starting this project's tmux objects never writes its identity into the shared server's environment`、`boundary#The gate's actions are logged, and no window carries a destructive-call grant`）

- [ ] 1.1 `common.sh` 加 tmux 调用包装：建对象动词（`new-session`/`new-window`/`split-window`/`respawn-*`）
  在子进程环境里摘掉**整个** `TEAM_*` 命名空间；kill 类保留环境（M67 闸门要绑身份，且它们不可能启动
  server）。包装是产品面唯一的 tmux 出口（新增调用点必须走它）。 · 证据：改动后的函数 + `grep -n 'command tmux'` 的出口清单
- [ ] 1.2 建对象调用点接入包装：`team_tmux_ensure_session`（`common.sh`）、`team_tmux_new_window`
  （`common.sh`）、pulse 窗口（`cmd-watch.sh`）、派单占位窗口（`cmd-agents.sh`）、草稿窗口（`cmd-draft.sh`）。
  按裁定点 B：若裁「加 `-e`」，`new-session` 带四个身份变量的 `-e`（会话作用域），并证明全局环境不变。
  · 证据：每个调用点的 diff + 会话环境/全局环境的对照
- [ ] 1.3 裁定点 C 选 A1 时：`shim/tmux` 的日志目标在 `$TEAM_TMUX_CALLS_LOG` 缺席时解析到 cwd 所属项目的
  `state/tmux-calls.log`（向上找 `.pi/team`，不启子进程；找不到就不写），pin 存在时行为逐字节不变。
  · 证据：改后的解析片段 + 两条路径的实测日志行
- [ ] 1.4 新夹具 `tests/tmux-identity-leak.sh`：私有 socket/私有 fixture（沿用 `tests/lib/tmux-iso.sh` 的
  隔离写法），`--all/--select`、末行 ✓/✗ 计数；红侧 1（全局环境零 `TEAM_*`：真 CLI `team up` 后
  `show-environment -g` 无本项目 `TEAM_*`、项目 B 的 session pane 也没有）与红侧 4（审计：pin 缺席时
  cwd 所属项目日志恰好 +1 行、非项目目录不写）。 · 证据：`--all` 输出尾 + 两条红侧的原始输出
- [ ] 1.5 红侧 1/4 的**翻转**：把建对象调用改回「带环境」（一行变异）→ 红侧 1 必须红并点名全局环境里的
  变量；去掉 A1 的 fallback → 红侧 4 必须红；各自还原后绿。 · 证据：两次变异的原始输出 + 还原后的绿
- [ ] 1.6 门禁接入（裁定点 D）：`smoke.sh` §32 调用新夹具；`section-budgets.tsv` 的 §32 行按**实测**
  max(host/container/ci) 重填；`section-paths.tsv` 的 §32 patterns 补
  `skills/teamsmith/scripts/lib/common.sh`。`section-guard.sh --budget-check` 必须绿。
  · 证据：三处 diff + `--budget-check` 输出尾

## 2 apply-2 · 读侧归因与自愈（规格 `pm-lifecycle#Identity inherited from the shared server's global environment resolves by the working directory`）

- [ ] 2.1 `common.sh` 加**来源归因**：冲突对里**每一个**变量的继承值都等于 `tmux show-environment -g V`
  的值（且 TMUX 非空）→ 判为共享 server 残留。全部可归因才放行（半可归因 = 不可归因）。实现复用既有的
  冲突对函数，不新造第二份身份解析。 · 证据：改动后的函数 + 两种形状（全/半）的判定输出
- [ ] 2.2 可归因路径：按 cwd 解析、**stderr** 一行点名「运行中的 tmux server 的全局环境」+ 那条清除命令；
  **不**清、**不**重写共享 server 的任何东西；只读/机读出口的 stdout 不受影响。 · 证据：真 CLI 的输出
  （stdout/stderr 分开抓）
- [ ] 2.3 不可归因路径逐字不变：显式外来环境（§32③/§32⑧a 的形状）、值不在全局环境里的分歧、无 tmux、
  真嵌套 —— 拒绝措辞/退出码/`TEAM_ALLOW_FOREIGN_IDENTITY=1` 出路照旧。 · 证据：§32③/⑧a 的原始输出
- [ ] 2.4 `team doctor` 只读残留行（裁定点 E）：点名变量 + 清除命令，跑完全局环境逐字节未变。
  · 证据：doctor 输出 + 前后 `show-environment -g` 的字节比较
- [ ] 2.5 夹具补红侧 2/3：② 污染模拟（`set-environment -g` 设成 A 的值 → B 的目录里 `team up` rc=0、
  说明行、建出 B 的对象、A 未动、全局环境未变）；③ 非归因照旧拒绝 + 真嵌套不误清（无说明行、无清除、
  无全局环境写入）。 · 证据：两条红侧的原始输出
- [ ] 2.6 红侧 2/3 的**翻转**：关掉归因（改成不可归因）→ 红侧 2 必须红（回到 rc=1 + `身份冲突被拒`）；
  把归因改成无条件放行 → 红侧 3 必须红；各自还原后绿。 · 证据：两次变异的原始输出 + 还原后的绿

## 3 隔离与可单跑

- [ ] 3.1 夹具只写私有 socket 与私有 fixture 根；跑完断言真实仓库 `docs/team/inbox/**`、
  `.pi/team/state/**`（含 `tmux-calls.log`）未被改动（前后 hash 对比），任一变化即 fail 并打印差异。
  · 证据：隔离断言输出 + 前后 hash
- [ ] 3.2 `perl tests/tmux-lint.pl --selftest` 与 `perl tests/tmux-lint.pl` 绿（新夹具的 tmux 调用全部
  私有 socket、无绝对路径）。 · 证据：两条命令的输出尾
- [ ] 3.3 `bash tests/tmux-identity-leak.sh --select <组名>` 可单跑并打印本组 ✓/✗。
  · 证据：单跑输出

## 4 验收与交付

- [ ] 4.1 跑齐 proposal「Acceptance」的全部命令（新夹具 `--all`、`smoke.sh --select 32`、
  `section-guard.sh --budget-check`、`tmux-lint.pl --selftest`、`spec-refs.sh --check`、`ledger-ban`、
  `openspec validate --all --strict`、投影自证），报告贴真实命令与输出尾。
  · 证据：命令日志
- [ ] 4.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 1.5/2.6 节的变异与还原
  **原始输出**就是本任务的翻转证据（红→绿、绿→红→绿）；写明任何未测项与失败。
- [ ] 4.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；不合并不推送，分支留本地；
  `team notify pm` 一行交付说明。

## 5 独立验证（另一席位，不是 apply 作者）

- [ ] 5.1 在独立克隆上重跑 `tests/tmux-identity-leak.sh --all` 与 `smoke.sh --select 32`，确认既有
  §32①–⑧ 回归 + 新组全绿。 · 证据：独立日志
- [ ] 5.2 逐条重做第 1.5/2.6 节的四次变异与还原（不是只复跑绿侧）。 · 证据：复验记录
- [ ] 5.3 自设计反例：① 全局环境里**只**有部分冲突变量时是否仍拒绝；② 归因后同一 pane 里连续多条命令
  是否都按 cwd 执行（且都不写共享 server）；③ 会话里**人手**新开窗口的 `kill-*` 判定是否与今天一致
  （裁定点 B 的对照臂）；④ `-e` 的会话身份是否**只**落在会话作用域（全局环境仍逐字节干净）。
  · 证据：反例输出
- [ ] 5.4 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。
  · 证据：`docs/team/reviews/<ID>.md`
