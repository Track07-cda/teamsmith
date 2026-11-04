## 1. 提案接收后：parser 与 source pipeline

- [ ] 1.1 前置：PM 正式 proposal review 与独立实质评审接受同一候选后，才另派非本提案作者 Apply；确认 P393 的 `SKILL.md` 编辑先串行落定，P391 保持依赖，不修改其独立工件或创建平行提案。
- [x] 1.2 在 `scripts/reply-capture.mjs` 实现窄 parser/原 offset 映射，必要时从 `scripts/replies.mjs` 复用纯输入验证且保持原 CLI main；在拟新增 `tests/reply-capture.mjs` 直接 import 产品，覆盖精确语法/标题/MC/全部控制行清理、代码/未闭/不同 run/跨块 CRLF/Unicode/非 text 全字段。交完整 content、删除范围及原字节对拍。
- [x] 1.3 同组加入 R1 两个原始 escaped-first-tick-suffix 用例（inline-only 和再接真实尾行）、1/3 与 2/4 反斜线相邻控制及 in-span closer；在 disposable 产品副本把首 tick 转义误扩为整 run 忽略，证明两反例红、还原绿；inline 排除、任意 run 切换、unmatched 吞尾部变异也须红。
- [x] 1.4 在 `extension/team-reply.ts` 与窄模块接通 end→turn_end.messageEntryId→settled、latest supersession、source tuple、固定 journal/flock/原子事务和 eligible→attempting CAS；清理独立于资格/落盘。用 fake-host 驱动**真实 writer**，核 queued/tool/retry/abort/无绑定/首轮 null leaf、同文不同 entry、重复事件及超出最新页 saved，交条数/no/raw body/journal 证据。（实现与假宿主证据见 `docs/team/reports/P396-dev.md`；`node skills/teamsmith/tests/reply-capture.mjs --select state` 40/40）
- [x] 1.5 用 tests 外部 driver/wrapper/kill 覆盖 end/Pi append/binding/eligible/attempting/spawn/commit/receipt/result-journal 缝隙，真锁得5、现有 fail:index-fsync 得6，坏/丢 receipt 与结果落盘失败后 reload 不重发；不加产品故障开关。定点运行新 parser/source 入口及原 `key-replies.sh --select input,original,concurrency,receipts,interrupt`，不跑全 gate。（外部进程/真 writer 故障证据同报告；`--all` 114 项、原 `key-replies.sh --select input,original,concurrency,receipts,interrupt` 85/85）

## 2. 串行接入：PM 注入、身份与运行证据

- [x] 2.1 修改 `scripts/lib/common.sh` 的内置 PM 参数/进程局部环境，一次定向注入并保留既有扩展/模型/continuity。扩展核主检出、canonical config/state、真实 tmux/PID/starttime/cwd/spawn；在私有 PM 启动夹具验证初启 final proof 晚到及 foreign cwd+继承 root/config/state、worker、普通 Pi、自定义模板均不假启用，不写 tmux global、不重复 `/team`。（私有真 Pi 否定用例 foreign/worker/ordinary/custom/inherited/config-link 全绿，无 tmux global 写入）
- [x] 2.2 完成双路径拷贝的一个 owner/generation、跨进程 source CAS、过期 callback 隔离及 runtime 注册；修改 `cmd-update.sh`/`cmd-project.sh` 的依赖指纹/doctor。交 disk-present/launch-injected/runtime-ready 的各自证据，dependency-only edit、dead/reused PID、旧 loaded hash、只读诊断和旧 generation 清理反例；CAS/owner 变异必须红。（`--select identity,owner-mutations` 与 dependency-reload 用例；doctor 只读）
- [x] 2.3 在拟新增 `tests/reply-capture-real.sh` 用隔离 HOME/state/socket/受控模型跑私有**真 Pi**：end/append/turn/settled 顺序、queued/before-settle 续跑、全部终态/半前缀、最终 transcript/print stdout/下一请求历史、两路径加载、无入口 reload 对照与已有入口模块更新、session switch/tree/fork。交按各 case 实际 marker 匹配的 raw pty 阳性和终稿证据，不声称零闪现、固定时限或真实模型遵从率。（`bash skills/teamsmith/tests/reply-capture-real.sh` 23 个用例；不声称零闪现、固定时限或真实模型遵从率）

## 3. 串行迁移指令与既有 reply 集成

- [x] 3.1 捕获/注入路径可运行后，才同批修改 `templates/pm-prompt.md.tmpl`、`references/protocol.md` §4b、`SKILL.md`/相关 guide：读者判据保留，默认 marked normal answer/扩展发布、CLI 人工补录；去掉日常 temp/heredoc/post-then-repeat，明确失败不挡答复和 saved 的边界。对接后续 P391，不先发不可用的标记指令。（P393 已入 main 并合入本分支；三处表面同批改，`--select guide` 的 `guide-surfaces`/`guide-default` 逐面绿，见 `docs/team/reports/P396-dev.md` 的指令迁移补充节）
- [x] 3.2 用 marker 行为替换 `tests/key-replies.sh` 旧 guide 的默认 CLI 双写断言/变异；保留三处 duty/reader 缺失的红侧、真实 CLI 手工示例与 unknown-flag 反证、手工相同输入两条。新 source/Pi tests 接入同一 reply 入口和现有 smoke reply 段，不加独立 health/process gate；交被替代断言与保留覆盖清单。（旧五变异换成七条：三面锚点/判据红侧、旧默认 `then send that same body` 回插红、标记示例改坏由产品 parser 以 `invalid-title` 拒认、标记约定抹除红、`--stdinX` 手工示例红；`guide-marker` 用产品 parser + 真 writer 保存一次，手工 CLI 示例与 unknown-flag 反证保留；保留 `input` 组「手工相同输入两条」与 `capture` 组真 Pi/parser 入口）
- [x] 3.3 跑原 `key-replies.sh`、`key-replies-ui.sh`、`key-replies-pty.sh` 触及组，逐条核完整 raw body、当前/历史/分页、reader 只读、无 session/journal panel 读；私有 BOARD/tasks/inbox/outbox/notify/pending/wake 快照无出版副作用，明确 reply/journal/runtime 预期写入。提交小步证据，不在 live 团队做演示或自动启用。（`key-replies.sh --select workflow,guide` 44/44、`key-replies-ui.sh --select blocks,machine,snapshots` 72/72、`key-replies-pty.sh --all` 88/88、`reply-capture.mjs --all` 114/114；BOARD 哈希前后不变与真实仓库 inbox/state 隔离守卫均在日志里，见报告指令迁移补充节）

## 4. 不同作者的独立验证与有权归档

- [ ] 4.1 PM 另派未参与 Apply 的 agent，在独立 checkout 重新跑产品 parser/真实 writer/私有 Pi、故障和具名变异，按 `specs/verification/spec.md` 核每层证据，保留完整日志；完整 gate 仅交付/合入批次后台运行，不能以实现者自报、fake host 或本次 Propose 试归档代替功能验收。
- [ ] 4.2 独立验证后，PM 单独提出真实团队采用的 restart/reload 路径并等授权；不因规划完成或 version 标记自动 init、重启、merge、push 或发布。回滚按 `design.md` 保留原 store/session/journal，不删编号、不重新 eligible 旧 uncertain。
- [ ] 4.3 只有独立验证和用户确认归档后，由有权限的 owner 归档 change 并执行 `design.md` Migration Plan 中**精确 canonical Purpose 定点编辑**；验证三个真实 MODIFIED 和 Purpose 成文、未改 requirements/scenarios 保留、全量 specs strict 通过。不得以 delta Purpose 或绿色 archive 代替该编辑/检查。本轮仅在 repository 外副本演练此步骤，真实 change 不归档。
