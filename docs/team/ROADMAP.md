# pm-skills · Roadmap

> PM 维护。里程碑的退出标准必须是**可执行的验证**（能跑的命令 + 可看的证据），不是「感觉做完了」。

## 产品目标（一句话）

把「一个 PM + 若干 worker agent」的协作方式做成**可复用、可验证**的 skill（`skills/teamsmith`），
让任何 Pi 项目一条命令建队，并且每条行为承诺都有回归断言与独立复验。

## 里程碑

| 里程碑 | 目标 | 退出标准（可执行验证） | 状态 |
|---|---|---|---|
| M0 | 契约冻结：命令面/文档/测试一致 | `bash skills/teamsmith/tests/smoke.sh` 全绿；文档里不出现已删除命令（smoke 不变量） | 🟢 已完成（v1.11.3） |
| M1 | **自举**：teamsmith 管理 teamsmith 自身 | 本仓库用 teamsmith 跑完整闭环（任务书 → 派单 → 独立复验 → PM 合并 → BOARD done）**两轮**，且过程中发现的缺陷都被修掉并留证据 | 🟢 已完成（T1.1 + V1.1，v1.11.4→v1.11.8） |
| M2 | **规范层 + 门禁分层 + 依赖收窄** | `openspec validate --all --strict` 通过；派单/复验默认走快模式（<60s）、里程碑收口走全量；依赖只剩四项硬依赖 | 🔵 进行中（M2.2 已完成） |
| M3 | 对外可复用 + 任意 TUI Agent | **推迟（scope 收窄 2026-09-22，见 DECISIONS D35：只承诺 Pi，接缝保留为内部预留）** ① **M3.0 适配层**：`TEAM_AGENT_CMD` / `TEAM_AGENT_NOTIFY_CMD` / 可选日志 glob，并用一个**非 Pi** 的 TUI agent 真跑一轮；② 在新项目上只用 `bootstrap` + 文档走通一轮（含跨项目 `meeting`） | ⚪ 未开始 |

## M1 达成记录（证据）

| 任务 | 谁 | 交付 | 复验 | 结论 |
|---|---|---|---|---|
| T1.1 | agent:dev | `TEAM_SMOKE_FAST=1` 快模式（8.5s）+ 分层自检 + 文档 | PM clean checkout + 全量门禁 ✓312/✗0 | 合并（v1.11.7）→ `reviews/T1.1.md` |
| V1.1 | agent:verify | 不变量 A 绕过矩阵（8 类漏报/3 类误报）+ review 只读性实证 + 3 类误判 PASS + 5 条错误路径 | PM clean checkout + 全量门禁 ✓（强复验判定「满足」） | 合并 → `reviews/V1.1.md` |

这两轮直接暴露并修掉的 **skill 自身缺陷**（全部有回归断言）：

- **v1.11.4** 测试隔离 + 破坏性 tmux 守卫 —— smoke 继承 `TEAM_ROOT` 时会作用到**真实 session**，
  空目标 `tmux respawn-pane -k -t ""`（等于"当前 pane"）把我自己打死过两次。
- **v1.11.5** `review --dir` 校验：checkout 必须是根目录且 HEAD 等于任务分支（以前拿 main 也能 PASS）；
  文档一致性不变量改词边界口径 + 扫描范围补 README/scripts + **翻转自测**（当场又抓出 3 处真残留）。
- **v1.11.6** PM 身份归属校验（窗口里进程的 cwd 必须属于本项目）+ 复验拒绝脏 checkout。
- **v1.11.8** 强复验判定的 **SIGPIPE 静默假阴性**：`printf … | grep -q` 在 pipefail 下让
  "报告越长、证据越靠后越被判成缺"。

门禁规模：293 → **321 断言全绿**；耗时 快模式 8.5s / 全量 ~22s（目标 <60s 已达成）。

## V4.0 修复批进展（2026-09-14）

| 批次 | 状态 | 内容 |
|---|---|---|
| M6.1 状态诚实 | ✅ 已合并（v1.20.0） | F28 durable 记录 / F29 board 未知 ID / F1 done 需证据 / F2 close 诚实 / F5 死配置 |
| M6.2 复验证据 | ✅ 已合并（v1.20.0） | F7 fail-closed / F8 dirty 留痕 / F9 ignored / F10-F11 超时判定 / F12 no-gates / F13-F14 --strong / F3 revision 绑定 |
| M6.5 存活证明 | ✅ 已合并（v1.20.0） | 假存活（空窗口前台是 tmux → up 谎报 PM 在跑，连带 7 条门禁断言红）；TIMEOUT 归因改为"包装器真到点" |
| M6.3 派单/通知/边界 | 🔵 dev 进行中 | F16 分支比对 / F26 pm 收件人 / F15 项目外简报 / F18 死信 / F17 去重键 / F27 空目标集中守卫 / **F30 wrapper agent 启动证据** / OpenSpec 协议模板指引 |
| M6.4 digest/版本/会议 | ⏸ 排队 | F4 未 push 口径 / F6 id 含 '-' / F21 SIGPIPE 141 / F23 reload 承诺 / F19 TTL |
| M4.3 信号诚实 A–D | ⏸ 排队 | 卡死 pane 的派单假成功 / 复用长会话 + 小窗口模型 / 未提交草稿的措辞 / squash 合并后的永久"待收尾" |
| M5.3 规格可证伪不变量 | ⏸ 排队 | OpenSpec validate 不管"场景可证伪"（PM 实测：删 THEN/删场景仍绿）→ 加项目级断言 |

PM 侧最新基线（供各修复任务对照，均在我自己的 scratch 项目复现）：F16 把任务派到别的分支并记错 branch；F26 `notify pm` 在 PM 没跑时不可见；F21 陈旧 marker → `version --check` 退出 141；F6 `API-2` 报告被判为"忽略的非任务报告"；F19 `--ttl 0` 会议永不超时；F4 已 push 仍报"未 push"；F15 项目外简报被接受且被称作 repo-relative；F18 拼错收件人 → 死信且 exit 0。

## V4.0 修复批收口（2026-09-14，全部完成）

| 批次 | 版本 | 内容 |
|---|---|---|
| M6.1 状态诚实 | v1.20.0 | F28 durable 记录 / F29 board 未知 ID / F1 done 需证据 / F2 close 诚实 / F5 死配置 |
| M6.2 复验证据 | v1.20.0 | F7 fail-closed / F8 dirty 留痕 / F9 ignored / F10-F11 超时判定 / F12 no-gates / F13-F14 --strong / F3 revision 绑定 |
| M6.5 存活证明 | v1.20.0 | 假存活（空窗口前台是 tmux → up 谎报 PM 在跑，连带 7 条门禁断言红）+ TIMEOUT 归因 |
| M6.3 派单/通知/边界 | v1.21.0 | F16 分支比对 / F26 pm 收件人 / F15 项目外简报 / F18 死信 / F17 去重键 / F27 空目标集中守卫 / **F30 wrapper 启动证据** / OpenSpec 协议模板指引 |
| M6.4 digest/版本/会议 | v1.21.0 | F4 未 push 口径 / F6 id 含 '-' / F21 SIGPIPE 141 / F23 reload 承诺 / F19 TTL |
| M5.3 规格可证伪 | v1.22.0 | `tests/spec-lint.sh`（openspec validate 看不见"场景缺 THEN"）+ 进三段门禁 |
| M4.3 信号诚实 A–E | v1.22.0 | 长会话×小窗口守卫 / 卡死 pane 不再假成功 / 草稿措辞 / squash 已合并标注 / 假"回合结束"抑制 |

**V4.0 结论**：29 条 finding 全部修复并由 PM 逐条独立复现验证；期间 PM 又抓出 F30（wrapper agent 启动误报）与
OpenSpec 协议指引缺口（用户指出）。工作流决策见 DECISIONS D10/D11。

## M7 · 外部可复用与打磨（当前里程碑）

| ID | 任务 | 负责 | 依赖 | 状态 |
|---|---|---|---|---|
| M7.1 | 迁移/升级指南 `references/migration.md`（重命名、已删命令、必需依赖、行为变更、升级配方、回滚）+ doctor 指引 | dev | v1.22.0 | 🔵 |
| M7.2 | 看门狗单拍抖动**根因**（不再靠重试掩盖）：采样诊断 + 确定性判据（starting/running/stopped）+ 文档 | dev2 | v1.22.0 | 🔵 |
| M7.3 | 跨项目会议**实测**（需要另一个项目 PM 配合；此前只有本地协议测试） | PM | M7.1 | ⏸ 待人类牵线 |
| M7.4 | （可选）CLI 输出英文化 —— 见 DECISIONS D8，默认不做 | — | — | ⏸ |


## M8 · 让"任意 TUI Agent"这句话对 PM 也成立（当前里程碑）

| ID | 任务 | 负责 | 依赖 | 状态 |
|---|---|---|---|---|
| M8.1 | PM 侧适配：`TEAM_PM_CMD`/`TEAM_PM_BIN`/`TEAM_PM_RESUME_ARGS`（默认 Pi 逐字节不变）+ 真非 Pi PM 端到端（启动/提示词投递/崩溃重启/watchdog 重启）+ 文档（含"非 Pi PM 拿不到什么"） | **推迟（scope 收窄 2026-09-22，见 DECISIONS D35：只承诺 Pi，接缝保留为内部预留）** dev | v1.24.0 | 🔵 |
| M7.4 | 跨项目会议**实测**（需人类牵线另一个项目的 PM） | PM | — | ⏸ 待人类 |


## M10 · 规格补账（OpenSpec 流程首次真实运行；E1 探索已 ACCEPT，选项 D）

| ID | change / 任务 | 阶段 | owner | 说明 |
|---|---|---|---|---|
| E1 | `spec-backfill-m6-m8` 探索 | ✅ explore 完成并被我接受（D15） | dev2 | 32 条未覆盖行为 + 两个新 capability（`agent-adapters` / `pm-lifecycle`）+ 关键风险 |
| P1 | **`spec-delta-gate`**（C0） | 🔵 propose | dev2 | 门禁期检查坏的 MODIFIED delta（validate 抓不到、archive 才抓，太晚）→ 后续所有补账的前置 |
| — | `launch-and-adapter-evidence`（C1） | ⏸ 待 C0 收口 · **推迟（scope 收窄 2026-09-22，D35）** | — | 试点补账：适配层两侧 + 启动/退出证据 |
| — | C1 跟进（P4 finding F1）：给迁移来的「>100 KB 长提示词」场景造证伪器 —— worker 侧 `{prompt}` 逐字节比对 + 一个 >100 KB 的 brief | ⏸ 排队（需新测试代码，补账本身不写测试） | dev | 现状：该场景**没有可跑的检验器**（逐字节比对只在 PM 侧 §6i；没有任何测试用过大 brief）；限制已写进 C1 `design.md` 的 Risks |
| — | `review-evidence-integrity`（C2） / `ledger-and-channel-honesty`（C3） | ⏸ | — | 复验证据完整性 / 看板与通道诚实 |

流程（每个 change 各走一遍）：explore → **PM 接受方案（D15 模式）** → propose → **PM 审产物写 `reviews/<change>-proposal.md` ACCEPTED** → apply（dev）→ **独立 verify（verify）** → 最终门禁 → **用户确认后 archive**。

## 历史工作分解

| ID | 任务 | 负责 | 依赖 |
|---|---|---|---|
| M5.1 | MC + OpenSpec 升为必须依赖（doctor 缺则 fail、paths 暴露、dispatch 警告、bootstrap 指引；顺手修掉 11b 的既有 flake） | dev ✅ 已 PM 复验，待与 M5.2 一起合并 | v1.18.0 |
| M5.2 | OpenSpec 落地：本仓库 init + 8 个 capability specs + `validate --all --strict` 进门禁 + references/openspec.md + 工作流接线 | dev2（🔵 收尾中） | v1.18.0 |

| ID | 任务 | 负责 | 依赖 |
|---|---|---|---|
| ~~M4.1~~ | ✅ 文档面全英文（references ×6 + SCOPE.md，v1.17.0 `cd8bdb9`） | dev | M3 |
| M4.2 | （可选）CLI 输出 / `team help` / 断言标签英文化（DECISIONS D8 的边界另一半） | — | M4.1 |（M2）

| ID | 任务 | 负责 | 依赖 |
|---|---|---|---|
| M2.1 | OpenSpec 规范层：`openspec init --tools none` + 首批 capability 现状 spec（dispatch / review / watchdog / capacity / meeting / update / boundaries）+ `openspec validate --all --strict` 进验收入口 | PM（agent:verify 复核） | — |
| ~~M2.2~~ | ~~依赖收窄 + 哲学落盘~~ ✅ 已完成（v1.12.0）：删容器后端、forge 解耦、`references/philosophy.md`（8 信条）+ PM credo、magic-context 作为可选推荐依赖（doctor 三态 + memory-seed 模板） | PM | M1 |
| M2.3 | 补齐 T1.1 的「独立验证包」（`reviews/T1.1.md` 强复验清单里标为缺） | agent:verify | — |
| M2.4 | 看门狗单拍抖动根因：`team_pane_busy` 与 `make_pm_idle` 的时序（现在靠重试掩盖） | agent:dev | — |
| ~~M3.0~~ | ✅ agent 适配层已合并（v1.15.0，commit `26e297f`）：4 个新键 + 占位符引擎 + 非 Pi 实测（opencode/codex 真跑，抓到 2 个真 bug 并修掉）；PM 独立复验：渲染 diff、未知占位符报错、自跑一次真 codex 全通 | dev + PM | M2.2 |
| ~~M3.1~~ | ✅ 对抗性复核完成（V3.0，已合并 `4235d32`）：15 findings（1 blocker 注入 / 1 major OOM / 6 minor）+ 11 项攻不破；PM 已独立复现注入并复跑其验证包 | verify | M3.0 |
| ~~M3.2~~ | ✅ 适配层加固已合并（`116a997`，v1.16.0）：F1 改数据通道（`{summary_file}` + `--from-file`）、F4/F5/F6 模板校验、F7/F8 提示词真话；PM 用 6 种敌意摘要独立验证（0 执行、逐字节送达） | dev | M3.1 |
| ~~M3.3~~ | ✅ monitor 加固已合并（`43c94c3`）：256MB 日志 **584MB → 59.7MB RSS**、64MB 堆不再 exit 134、FIFO 不阻塞、0 个 ESC 字节；PM 独立复现 + 复跑其 120 条 A/B 包 | dev2 | M3.1 |
| M3.4 | 把 V3.0 验证包里两条**过时期望**翻转（b3 注入对照、d4 多行模板）并重录日志，让它在 main 上重新成为绿色回归门禁 | dev2（🔵 派单中） | M3.2 |
| M2.5 | magic-context 使用手册：把"三层记忆"（会话记忆/落盘证据/skill 版本）与 memory-seed 的用法写成 `references/memory.md` | PM | M2.2 |

## 遗留 / 观察（不阻塞，记着）

- `team_pm_state` 的 cwd 归属判定在没有 `/proc` 且没有 `lsof` 的环境会退化成旧行为（macOS 需 lsof）。
- 其他在用项目（<cep-project>/<erp-project> 等）需要跟上 v1.11+ 的命令面：`team merge/pr/gh/gl` 已删、`review` 必须带 `--dir`；
  现状靠"报错自解释 + `/reload`"覆盖，M3 时再评估要不要写一页迁移说明。
- 跨项目通道（`team meeting`）已在真实项目间跑通一次；M3 要在新项目上再验一遍。

## 阶段范围之外（Non-goals）

- 不把 skill 变成 git/forge 的包装层（v1.11 起明确删除 `merge`/`pr`/`gh`/`gl`）。
- 不替别的项目做决策或改别人的仓库（跨项目只走 `team meeting` 的 peer 交流）。
- 不引入 jq/python/node 运行时依赖（脚本只用 bash + git + tmux）。

## 关键约束

- 目标环境：Linux + bash ≥ 4 + tmux + pi；可选 podman（看门狗容器后端）。
- 测试即门禁：`skills/teamsmith/tests/smoke.sh`（临时仓库里端到端，不碰当前项目；带身份隔离自检）。
- 文档与命令必须一致：已删命令不得再出现在 `SKILL.md`/`references`/`templates`/`README.md`/`scripts`
  （smoke 有词边界判据 + 翻转自测；用法级不变量：#review 必须带 `--dir`）。
- 本仓库的 PM 是「当前 Pi 会话」（`pm-skills:pi`），agent 在 `.worktrees/{dev,verify}` 里工作。

## 状态快照（2026-09-14 收工）

- **版本**：v1.26.0（`main` @ `6c120ed`，已 push；GitHub Releases v1.14 → v1.26 共 13 个）。
- **当日主线**：把 skill 从"Pi 专用 + 文档说得好听"推进到"**两侧都能跑任意 TUI Agent、且状态/证据/存活都经对抗验证**"。
- **已完成里程碑**：M0 契约冻结 · M1 自举 · M2 规范层（OpenSpec 必需依赖 + spec-lint）· M3 适配层与对抗验证 · M4 文档面与语言边界 · M5 必需依赖与规格层 · M6 V4.0 全部 29 条 finding 修复 · M7 迁移指南/看门狗 starting 态/英文不变量/测试隔离规则 · M8 PM 侧适配与 worker 静默失败。
- **待办（仅 1 项，且需人类）**：M7.4 跨项目会议实测——需要另一个项目的 PM 一起开一次会（协议本身已有本地测试覆盖）。
- **三个 agent 空闲**，无未完成任务；PM 已进入 standby（watchdog 不再定时叫醒）。
- **恢复入口**（下一个人/会话）：`team digest` 看板 → `team roster` 名册 → `docs/team/DECISIONS.md` 看决策（D1–D13）→
  `docs/team/ROADMAP.md` 本快照 → `skills/teamsmith/references/migration.md` 升级/回滚。

### 队列（工具侧，按顺序）

| ID | 任务 | 状态 | 备注 |
|---|---|---|---|
| M9.2 | `done` 证据按 phase 判定（explore/propose/verify/archive；未声明 phase 保持原样） | 🔵 dev2（原 dev，已转派） | 派单前未确认"无未完成任务"导致的叠单（D16） |
| **M9.4** | **待复验清单不得越过看板决定**（已 done 的任务不再列出；证据以看板转变时为准）+ 叠分支导致的重复归属 | ⏸ 待 M9.2 收口后派 | 真实假信号：P1 已 REVIEW**+done** 仍在每拍被列为待复验 |
| **M9.5** | 复验任务的记录绑定**被审修订**而非验证者自己的分支（真实假 stale：`V2 [stale: verified 3987168, branch now 44788f0]`） | ⏸ 待派 | 同一类"检测器模型不认流水线"的第三次（M9.2 done 证据 / M9.4 待复验清空 / M9.5 stale 判据） |
| M11 | bootstrap 把 PM 窗口名写成当前窗口碰巧的名字（本项目实测：配置写了 `pi`，巡检报"窗口缺失"而 PM 活着） | ⏸ 待派 | 修复：固定写 `pm`，doctor 加漂移报警 |
| M15 | 巡检的代码漂移自检不覆盖 panel.js——bundle 更新后运行中的面板不会自动换新（本次实测：restart 才拿到新控制台） | ⏸ 待派 | 指纹纳入 panel/bundle 哈希，漂移时面板一并重启 |
| **M9.7** | smoke §11i-D squash 启发式抖动（V3 实测 8 次全量里挂 1 次）——有界轮询替换固定 sleep | ⏸ 待派 | V3 报告 logs/ 有原始日志 |
| **M9.6** | done 证据的必要条件补上"已提交的报告"——零提交的新分支现在能冒充"已合并"（探针实测：`done 证据：OK…代码真的落地了`是假的） | ⏸ 待派 | M9.3 探针时发现的真洞（F1 守卫的盲区） |
| M9.3（已交付 v1.30.0） | `dispatch` 在该 agent 仍有未完成任务时告警/拒绝（除非 `--force`） | ⏸ | D16 的工具侧落实 |

### 讨论中（未立项）

- **外部仓库平面融合**（GitHub Issue/PR 等外部来源 ↔ 本地文件台账）：方向草案已讨论（单向投影、巡检进料钩子、
  Issue 必须过分诊才成任务、PR 是可选评审面），**用户明确：先讨论阶段**，不动工。待拍点：回流范围 / 进料范围 /
  用户自己是否走 Issue 通道 / 是否立项。

| M13 | Pulse 控制台功能丰富（下一阶段主线）：消息入口、最小控制集、（延后）输入状态数据通道 | 🔄 E6 探索中 | 数据通道（去主题依赖的守卫）**延后**，用户确认不是当前重点 |
