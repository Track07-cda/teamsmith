## Context

动机见 `proposal.md`。既有 `scripts/replies.mjs` / `scripts/lib/cmd-reply.sh` 是唯一编号/原文 writer，Pulse 和 CLI 的只读读取、分页、receipt、原子可见合同保留。Pi 1.4.0 的公开 `message_end` 返回 `{message}` 可替换终稿；它发生在 Pi append 前，不能把当时 leaf 当成本条 entry。`turn_end.messageEntryId` 才能绑定已持久消息，`agent_settled` 才表示自动续跑结束，但其 aborted=false 不是成功证明。

依据是已接受探索 `683d591a3e91:docs/team/reports/P394-dev2.md` 的修订、独立三轮复核 `ebeaba36:docs/team/reports/V115-dev3.md`，以及 D213/D214 和 P395 的转义补充。原报告早期 literal probe/哈希恢复草案已被后文替代，不作产品验收。D214 已接受控制文字在流式中暂现，不再讨论上游显示前改写或 provider 桥接。

## Goals / Non-Goals

**Goals:** 将显式标记的当前 PM 回答送入原 store；正文只减完整控制行；活动资格、来源身份和执行权分别可核实；失败不破坏回答。

**Non-Goals:** 历史挖掘/批量导入、正文哈希认领、exactly-once/必达、worker/普通 Pi 捕获、provider 改写、隐藏思维链变换、完整 Markdown AST、第二回复页、daemon/调度/提醒、新配置键或 slash/adapter 接口。正文上限沿用 131072 字节，标题沿用 160 码点；不增加或放宽限额，不静默截断正文。

## Decisions

### 1. 最小模块与唯一存储边界

```text
内置 PM 启动参数 → extension/team-reply.ts
                         │ message_end 返回净化 message
                         ├→ scripts/reply-capture.mjs（窄 parser、offset、source journal）
                         │ turn_end 绑定 → settled 授权 → attempting 耐久
                         └→ 原 team reply post --from pm --title <title> --stdin
                              → 原 cmd-reply.sh → replies.mjs → 原编号 store
                                                           ↑ Pulse / CLI 原 reader
```

扩展只做 Pi 事件/身份/owner 粘合；一个窄模块导出 parser、状态转移与 journal 操作，不建插件框架或独立服务。必要时从 `replies.mjs` 导出现有纯标题/输入验证，并将 CLI main 保留为直接执行入口，避免导入时执行 CLI；这不是新 writer，也不改变手工合同。不将扩展放到 `.pi/extensions/` 自动发现目录，不由 `/team` 启用。

操作 journal 仅保留原回复进入 writer 前后的证据/净化 intent，无第二编号、页面、待办计数或 Pulse reader。其权限与现有本地 state 一致，拒绝非普通文件、symlink/不安全祖先/替换身份；诊断不回显正文。没有新保留期限/清理任务；saved source 离开当前页后仍是执行屏障。

替代方案：CLI 默认双写违反用户已定流程；扫 session/hash 对账无法区分同文不同回复；provider 变异框架扩大范围。三者均不采用。

### 2. 精确语法、代码保护和 offset

语法合同见 `specs/key-replies/spec.md#Complete control lines are removed without rewriting answer content`。只认列 0 的两种完整行，标题第二式保留原样；最后非空白逻辑行才有资格，其后 spaces/tabs 空行保留。形成未保护的完整控制行集合 C：C=0 不变；C>1 清理所有行但 ambiguous；一条非尾行清理但 misplaced；非法标题/全空白净化正文清理但终止。所有 assistant end 终态都执行这一步，user/custom/toolResult/thinking 不是扫描目标，assistant 的 toolCall 保留但使发布不合格。

扫描分三步，不作 Markdown 重排：

1. text blocks 按原顺序直接拼接，不插分隔符，保留原块边界和 offset 映射。先划出 fence 保护区；inline pairing 仅在连续围栏外片段进行，不跨 fence。围栏长度/类型/info/关闭规则见规格，未闭围栏保护到消息末尾。
2. 围栏外从左到右消费 Markdown 反斜线转义，再形成未转义 backtick maximal opener。连续反斜线奇数只转义紧接的**首个** tick，后缀仍可成为 maximal opener；偶数不转义首 tick。未转义 run 不拆。对 opener 找最近的**完整 run 长度恰等**的 closer；span 内反斜线只是内容，不能转义 closer。只有配对成功才记录区间并跳过；未匹配 opener 当字面，继续考察后续 run，不吞剩余文本。可用同长度后继索引避免逐 opener 重扫尾部；外部 opener 转义处理不能改变 span 内 closer 的物理 run。
3. 不与 fence/已配对 span 相交的完整控制行才进入 C。仅将其原区间及自身 LF/CRLF 投回原块删除；不删前行换行/尾空行，不合并块、不删空块、不动 metadata、thinking/tool/签名/usage。用 JS 字符 offset 定位、UTF-8 编码验证原文字节，不能把二者混用而拆码点。跨 text blocks 的拼接是本 parser 合同，不声称 Pi 分块 Markdown 渲染也如此。

第三轮反例必须在产品 parser 中直接运行。下面代码块是**原始输入**，首行有一个反斜线、两个 backtick，末行一个 backtick：

````text
示例：\``
[[team-reply]]
`
````

第一 tick 被转义，第二 tick 与末行配成长度 1 的 span；仅此输入须 C=0、完整 content 深相等、无 intent/无 writer。再追加 `答复。\n[[team-reply]]`（这里 `\n` 表示实际 LF），须 C=1，仅删真实尾行；在合格活动链下真实 writer 恰好一次且 raw body 等于原串只去真标记。

产品测试还必须含：

| 输入族 | 必须观察到的结果 / 红侧 |
|---|---|
| 首 tick 前 1/3 个反斜线；2/4 个反斜线 | 奇数只转义首 tick、偶数不转义；忽略整个物理 run 的变异必须使奇数后缀用例红，忽略奇偶使相邻对照红 |
| span 内 backslash + 精确等长 closer | backslash 不屏蔽 closer；将其误作外部 escape 必须红 |
| 跨行双 tick 原例、后接真实标记 | inline-only 全文不变；inline+real 只删真尾行；去掉 inline 排除必须红 |
| opener 长度 2、中间长度 1/3、最后长度 2 | 只等长完整 run 关闭，任意 run 切换/拆 run 必须红 |
| unmatched 长度 2，后有长度 1 的合法配对 | 未闭 opener 不保护到末尾，后续 pair 仍被考虑；unmatched 吞尾部变异必须红 |
| 双 tick 横跨 text blocks、CRLF/CJK/emoji/空块/非 text | 保护原例、仅原 offset 删除真实尾行，完整 content 深比较、raw SHA/字节相等 |
| 反引号/tilde fence、不同关闭长度/类型、未闭、引用/缩进/转义/列表前缀 | 保护显式例子；不推断复杂隐式 Markdown 延续；prose 后裸放保留行仍 opt-in |

无标题只做标题视图派生：首个非空行去其行首 `§<decimal>§` 与紧邻 spaces/tabs；若只剩编号继续下一行；trim、去不安全标题控制、最多 160 完整码点、空则“关键回复”。不去正文里的编号/Markdown/空白。显式标题不派生、不代修；按 writer 原验证失败即 invalid-title。正文全空白终止；NUL/非法 UTF-8/131073 字节等按现有合同失败，不拆分补发。

### 3. 活动、最新消息与三阶段资格

一个 `before_agent_start` 到对应最终 `agent_settled` 是一次活动；扩展自产随机 activity ID 和活动内单调 assistant ordinal，不假设 Pi 提供 run ID。低层 agent_start/end、responseId、timestamp、turnIndex/hash 都不是恢复身份。

| 事件 | 内存 / 耐久动作 | 明确禁止 |
|---|---|---|
| before_agent_start | 开 activity，记录 startLeaf 和 session identity | 将同活动的 queued/retry 当新活动 |
| assistant message_start | 立即替换 latest ordinal，旧候选 superseded；包括普通/错误/tool 消息 | settled 回头搜索上个带标记者 |
| message_end | parser 先算净化结果；有候选则原子暂存 unbound intent；捕获落盘错误后总返回 `{message: sanitized}` | 以当前 leaf 作本条 ID；写盘异常跳过净化；此时发布 |
| turn_end | 用 messageEntryId/getEntry/getBranch 核对 latest intent、净化消息和终态，绑定 source，unbound→pending | 以同文/时间猜绑定；仅 binding 就授权 |
| agent_end | 不授予发布资格 | 认为低层循环结束即最终 idle |
| agent_settled | 全条件通过才将 pending + settled witness 同事务持久为 eligible，关闭 activity | aborted=false 直接当成功；重复 settled 开新 activity |
| session_start/reload/switch/fork/tree | 重核身份；丢弃未完成内存关联；仅按恢复规则读取明确 eligible | 扫 getEntries 全文件、重建丢失 pending、导入 fork 复制的 entry |

资格同时要求：current owner/PM 身份有效；完整活动关联；最新 assistant 已 end 且唯一绑定；stopReason=stop、无 toolCall；C=1 且尾行/body/title 合格；settled 非 aborted；startLeaf→source→settledLeaf 在当前 `getBranch()` 的祖先顺序成立。startLeaf=null 代表会话根，不能拒绝首轮回复。绑定丢失、乱序、消息不一致、activity 失效、end 暂存失败均不得在后续事件补猜授权。

普通 unmarked 只在内存更新 latest/扫描，无该消息的 journal/store 访问、进程或模型请求；session_start 的注册/恢复以及后续 settled 的恢复是独立生命周期工作，不冒充普通消息捕获。消息清理先于 writer 的慢操作，writer 异步在最终授权后运行；journal I/O 无任意硬延迟保证，失败须具名诊断，不吞未知错误。

### 4. 一个 source、一份 journal、一轮尝试

稳定元组为 `(canonical project root, canonical state dir, Pi session UUID, canonical session file, messageEntryId)`。leaf/activity 不进 key；路径可用身份摘要编码，但记录内保留完整元组核对，绝不以正文摘要作 source。同 session 固定快照 `state/reply-capture/<session-key>.json` 包含活动暂存和 source 索引，避免按时间命名造出多个执行权。无持久 session file 或身份不可核实则禁用持久捕获。

固定、不为抢锁而 unlink 的本地 flock 锁串行读改写。快照同目录暂存→fsync 文件→atomic rename→fsync 目录，所有成功回执后才推进动作；目录/记录/锁拒绝非普通文件、symlink/不安全祖先和 canonical identity 改变。进程内 owner 与跨进程锁均需要：前者防重复净化/回调，后者保护同 source 执行权。

```text
unbound → pending → eligible → attempting → saved | unconfirmed | not-written | uncertain
   └─ 缺绑定/终态/身份/settled：保留诊断，绝不自动升级
```

在锁内 CAS eligible→attempting，记录唯一 attempt token、owner PID/starttime、source 与时间；**attempting 耐久后才 spawn**。锁外 argv 数组调用原 `team reply post --from pm --title <title> --stdin`，固定已验证 cwd/state/config 环境，完整正文 stdin，无 shell 插值。成功推进后不能回滚 eligible；旧异步回调核 owner generation/attempt token 再记录结果。

| 实际结果 | 记录及恢复 |
|---|---|
| exit0 + 完整一致 saved receipt | saved + 真 no；不意味着送达/已读/页面刷新 |
| exit6 + 完整一致 unconfirmed receipt | unconfirmed + candidate_no；不冒充 saved、不补发 |
| 明确 input(2)、busy(5)、证明未创建进程的 ENOENT | not-written，具名 input/busy/not-started；MVP 同样不自动重试 |
| exit4、信号、管道/等待异常、缺失/坏/矛盾 receipt | uncertain；不能因非零或无回执推导没写 |
| writer 已可见/已保存，结果 journal 写失败 | 原 attempting 保持屏障，进程内可留 receipt、正文外诊断；重启按 uncertain，不补发 |
| startup 见 attempting | owner 活着跳过；已死转 uncertain；未知不接管；PID/starttime 防重用 |
| journal 丢失/损坏/无法读取 | 保留故障证据并停自动恢复；不扫描 session 或当前页重建来源 |

恢复只在 session_start 或后续 settled、没有开放新活动时进行；只处理完整当前 tuple、source 与 settledLeaf 仍在当前分支、明确 eligible 且从未 attempting 的记录。unbound/pending 永不靠进程死亡推定成功。相同 body/title/from 的不同 entry 各有一次权利；同 entry 随分支增长不变 key。saved 记录即使被 50+ 新回复挤出当前页仍挡重发；不做最新页或全历史 hash 对账。

崩溃缝隙由外部测试 driver 覆盖：

| 断点 | 重启允许做什么 |
|---|---|
| end 暂存前/后、Pi append 前/后、turn_end 前/后 | 无 eligible，不能发；可能漏自动保存，证据留作人工核对 |
| settled 发生但资格事务前/中 | 仅 durable eligible 可恢复，不能靠事件日志“看起来结束”授权 |
| eligible 已耐久、attempting 前 | 当前身份/分支仍符合同，恢复一次 |
| attempting 事务中 / 耐久后 spawn 前后 | 未完成 durable CAS 不 spawn；已 attempting 不再获权，即便其实没启动 |
| writer commit 前后、receipt 前后、结果事务前后 | 有合法结果则记录；其余 uncertain，绝不自动再试 |

缺少 receipt 就承认无法自动定位；有 candidate_no 可用既有 show 只读检查，但读到不等于补成 durability 确认。人工可据正文/日志显式另 post，算新提交，原 uncertain 不回到 eligible。此取舍用可能漏存换不盲目重复，不承诺 exactly-once 或 eventual delivery。

### 5. PM 定向加载、真实身份与更新证据

`common.sh:team_pm_pi_args` 的内置 PM Pi 分支加一次 `-e <skill>/extension/team-reply.ts`，保留 bg/inbox-watch、模型和 continuity。`team_pm_launch_cmd` 仅内置 PM 进程前缀固定本次 `team_load_config` 已解析的 `TEAM_STATE_DIR`、`TEAM_CONFIG_FILE`、`TEAM_PM_WINDOW`，不新增配置键、不改 worker、不写 tmux global。

身份必须同时核对：

- `ctx.cwd` 与实际 process cwd 独立解析、canonical 一致且是主检出；foreign cwd 不回退 inherited root，继承 ROOT/MAIN_ROOT 若在也须一致。
- canonical config/state 及已解析启动身份/配置指纹；显式外置 state 仍可用，但只能来自本次已验证启动上下文，不能借 foreign env 猜；符号链接/配置身份变化拒绝发布。
- 真实 tmux socket/server/pane/session/window 与配置一致；实际 PID/starttime/cwd 和 pane 进程/祖先关系匹配本项目 `pm.pid.spawn` 或有效 pm.pid + 运行证明。无 tmux/不足证据则 capture disabled，答复继续。
- 初启 final pm.pid/pm-launch.env 可能晚到；exec 前 spawn 文件和真实 pane/process 可证明当前启动，不能要求旧 pm.pid 已换新，也不能借旧 final launch 元数据放行别的进程。发布前重核。这是同 UID 本地证据，不是抵抗同 UID 伪造者的安全认证。

进程全局 `Symbol.for` 协调槽按真实 project/state/Pi session + generation 只给一个 owner。第二路径拷贝的非 owner 不注册 ready、不二次净化/暂存/spawn；shutdown/reload/switch 只清自身 generation，不删新注册；旧 callback 改 state 前验 generation/token。跨进程仍走 journal CAS，不依赖 loader 按路径去重。

一份 `state/reply-capture/runtime.json` 记 PID/starttime/cwd、root/state/config 指纹、tmux socket/pane、session/file、扩展真实路径、**模块求值/依赖装载时**保存的源码指纹、generation、ready/degraded。fingerprint 是实际被执行的模块字节摘要，不在 doctor 时补读当前磁盘冒充；reload 要真实重新装载 parser/journal 依赖，否则不能报新 fingerprint。注册用同样原子/路径纪律；仅生命周期更新，无 heartbeat。新 owner 的有效注册不能被旧退出回调清掉。

`cmd-update.sh:team_skill_exts/team_skill_hash` 覆盖入口与 parser/journal 依赖。`cmd-project.sh:team_cmd_doctor` 分开显示 disk source、内置启动注入、当前 live runtime 及 disk/loaded hash。无注册/死 PID/错 starttime/cwd/pane/会话报 unknown/stale/degraded，不能因为 mark-loaded 或磁盘有文件就说启用；诊断只读、不重启。

首个旧 PM 没带该 -e：仅 /reload 不会增加启动输入，须用户/PM 获权后经已有生命周期显式重启，保留旧会话。已经带 -e：可授权 reload，然后核新 generation/hash。自定义 TEAM_PM_CMD 不重写、不加 `{reply_ext}`；手动 Pi-shaped 模板也须同身份且单独验证，首版不作兼容承诺。支持范围只为独立验收过的内置 Pi 链。

### 6. 指令、测试与可执行切片

三处指令 `templates/pm-prompt.md.tmpl`、`references/protocol.md` §4b、`SKILL.md` 命令表一起改：保留读者判据和完整正文，默认标记式普通回答，插件发布，CLI 仅手工。删除 temp/heredoc→post→重复的默认步骤，示例保护为代码，不谎称自动决定哪些回答应标记。P393 的 SKILL 改动先完成；P391 后续集成本合同，不在此提案修改它的文件或另开规格。

实施按 `tasks.md` 三个串行切片：parser/source pipeline → PM 注入/诊断 → 指令和完整集成，均由非本提案作者实现，每片完成定点验证并记录证据；最后由不同 agent 做独立完整 Verify。模块/夹具是实现期拟新增，当前不存在，以下不是本轮已通过的命令：

```bash
# Apply 后才存在的新入口，接入既有 key-replies.sh/workflow/guide 调用链，不增新 smoke section
node skills/teamsmith/tests/reply-capture.mjs --all
bash skills/teamsmith/tests/reply-capture-real.sh --all
```

现有可直接执行入口，Apply/Verify 按触及范围跑、交付/合入前才由 PM 选定完整批次：

```bash
bash skills/teamsmith/tests/key-replies.sh --select input,original,receipts,interrupt,concurrency,workflow,guide
bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots
bash skills/teamsmith/tests/key-replies-pty.sh --all
```

新行为替换 guide 的旧默认 post/重复与旧变异，不增健康/流程 guard 或新 gate section；新增 parser/journal/Pi 测试是产品自身无法证明的事件/崩溃/显示行为证据，集中接入原 reply 入口。现有 input/original/receipts/interrupt/paging/UI/pty 保留。不添加产品故障开关：writer 复用既有 fixture 故障入口，其余 driver/wrapper/kill 在 tests，必要事件桩只算状态机层。

证据层分别承担：产品 parser 深比较 + 原 writer/raw body；fake host 的事件乱序/owner/CAS/故障组合；私有 real Pi + controlled model 的实际替换/时序/加载。真 writer.lock 持锁得5；既有 fail:index-fsync 得6/candidate；不能用 stub receipt 代替。私有 Pi 含 queued/unmarked supersession、stop 后整体 abort、retry、before-settle 续跑、terminal cleanup、print stdout/JSONL/下一 provider request 历史、两路径拷贝、无入口 reload 对照和已有入口 reload、switch/tree/fork。读取 print 场景应通过同一真实 PM 启动/身份约束，不能为测试放宽产品身份。

原始 pty 按 case 的实际 marker（含分块前缀）设阳性 selector 和最终清理断言，不复用只搜旧 probe 名的计数；采样帧只辅助，不能从阴性推零闪现。controlled stream 不证明真实模型遵从率。私有根前后快照分别列 reply/journal/runtime 预期写入，与 BOARD/tasks/inbox/outbox/notify/pending 不变；所有 socket/HOME/agent dir/state/日志隔离在 /var/tmp 或专属磁盘缓存，绝不对 live 团队测试。

## Risks / Trade-offs

- [流式 marker 仍可见，网络/中断改变窗口] → 已获用户选择；验收记录实际 raw 边界，无零闪现/毫秒上限承诺，完整行 end 清理，半条前缀保留。
- [settled 资格或 attempting 记录失败会漏存] → 正常答复仍在，具名诊断/人工补录；不以 hash/历史猜成功，不新建提醒或重试系统。
- [同 UID 注册可伪造、代码/依赖 reload 可能仍旧] → 明示不是认证，核 process/pane/加载 fingerprint；真实私有 Pi 证明重新求值，不能拿 disk hash 冒充。
- [原始流字节和 protected example 含同样文字] → 最终清理保证仅指识别的控制元数据；不删除用户字面例子，不承诺追回已经发出的 updates。
- [三处旧指令先上线会驱动不存在的功能] → 捕获/注入/诊断先落候选、指令最后同批；P391/P393 按串行依赖处理，不授权 live 采用。

## Migration Plan

1. 正式 PM proposal review 和独立实质评审接受**同一提交**后，PM 才可另派非作者 Apply。当前 tasks 全未勾选，规划完成不等于功能已完成。
2. 三串行实现切片和独立验证完成后，PM 才可提出真实团队采用；先展示启动参数/现有 PM 是否带入口/预期重启或 reload。无单独授权不 init、reload、重启、合入、push 或发布。
3. 失败回滚是撤回新入口/配套指令到原版本并按既有权限恢复加载；保留原 reply store、session 与 journal 证据，不删 numbered records、不重置 attempting，也不把旧 uncertain 自动补发。已有自动发布与人工发布同属原 store，不做破坏性迁移。
4. **归档时 canonical Purpose 的同批定点编辑**属于本 change 的计划范围，由有规格写权限的 PM/归档 owner 在独立验证和用户确认归档后执行；本轮只在副本演练，不把 delta Purpose 当作可合入机制。将 `openspec/specs/key-replies/spec.md` 的 `## Purpose` 至 `## Requirements` 之间原段完整替换为：

   > Let users return to complete answers explicitly marked by the PM or manually published, without searching chat history. Keep this project-local reply store and its readers separate from delivery and patrol work. Only the directed PM extension may observe explicitly marked live assistant messages of the current activity and recover proven eligible source operations; historical Pi inference or bulk import remains forbidden, and Pulse/CLI reply readers never read Pi sessions or the capture journal.

5. 试归档只复制 openspec 到 repository 外 `mktemp -d -p /var/tmp p395-trial.XXXXXX`，运行 `openspec archive -y pi-marker-key-replies`，按上段改副本 Purpose，再 `openspec validate --all --strict`。逐段检查三个真实 MODIFIED 名称各一份、默认 marker/CLI manual 职责、Purpose 窄例外与无历史/无 panel session 读取、原未改 requirement 和未替代 scenario；留下合并正文摘要/hash，随后删自己精确 trial 根。真实 change 保持 unarchived。

没有待用户重新裁决的架构/产品问题；接下来的判定是正式提案评审，不是继续实现的默许。
