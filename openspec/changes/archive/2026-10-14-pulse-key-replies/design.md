## Context

动机见 proposal。以下是本轮读取的基线，不是待实现能力的证明：

- `scripts/team` 当前没有 reply 入口；common 的 identity gate 为观察形式放行，`team_state_dir()` 会 mkdir，不能给新只读入口直接调用。
- `cmd-watch.sh` 的 `__panel-data --block` 和 panel `data.ts` 已按块异步起子进程、设超时、维护内存缓存。`detail` / `settings` 按需加入 wanted set；当前缓存按块名，没有回复 cursor/number 的请求代际，需要增加过期响应隔离。
- `types.ts` 的 PageId、App/布局、偏好/页文件和 snapshot CLI 当前只接受 1–4。现有 board/work 详情从任务文档发现集读正文，shell 命令替换会丢末尾换行，且读盘上限允许 truncation；**不把此读盘实现直接当成回复原文存储/完整读取**。复用的是安全 markdown 渲染和视窗，不是它的发现集或截断行为。
- 机器出口使用 `MACHINE_BLOCKS`，与 console-only blocks 分开；markdown 链接是文本。现有显示净化移除控制序列并保留两侧可见文字。
- 输入 HEAD 为 `5329f72`。`task-model-routing` 的接受工件可读；P228 S1 候选控制记录 tip 为 `16842c9`，报告列产品 tip `ba783c7`、补齐测试 tip `017fbf9`。D106 明确尚未独立接收，S2 UI/S3 指引也不是 main 的现有能力。本轮不运行候选 CLI、不读取实际会话或凭据。

## Goals / Non-Goals

**Goals:** 让保存、摘要、当前列表页和按需正文各有明确数据职责；增长主要消耗磁盘而非每帧 CPU；让失败、并发及中断可以用隔离故障点检验。可观察边界只在两份 delta 中定义。

**Non-Goals:** 不给正文建立送达状态；不借 outbox/inbox/BOARD 存储；不创建通用消息中心、新配置 schema 或全局清理服务；不修改 Pi/provider 消息和会话。原本每拍的 monitor 扫描是否有其他开销不在此项优化范围，规模证据单独计算回复读路径。

## Decisions

### 1. CLI 主动提交，同一正文仍正常发送

选择 `reply post --from <label> --title <title> --stdin`、`reply list [--before <no>] [--json]`、`reply show <no> [--json|--raw]`。不加正文 argv、文件路径入口、tag/status/priority/filter/edit/delete 子命令。正文用 stdin 的原始 Buffer 校验 UTF-8 与字节上界，原文不通过 shell 变量或显示净化；声明的 publisher 不从 assignment/Pi 推断，不包装成身份认证。

新增 `cmd-reply.sh` 处理命令分发/身份分类，`scripts/replies.mjs` 处理数据。使用 common 已解析的 JS runner 和项目 state 路径；显示净化共享同一规则并由双向测试防漂移，不增加第二套宽松净化。不引入 SQLite/native npm 模块或 Python 运行时依赖。系统 `flock` 已用于现有门禁排队，新增 helper 使用它锁定安全打开的文件描述符。门禁在缺 flock 时允许有提示降级，本项发布不能无锁降级：缺 flock 或安全 fd 锁能力时 post 返回 storage unavailable，list/show 无需 flock。此项因此新增发布入口的系统能力前提，但不增加项目配置键或包安装步骤。

静态例子（**实现后才可运行**）：

```bash
bash skills/teamsmith/scripts/team --root "$FIXTURE_ROOT" reply post \
  --from dev2 --title '完整结论与取舍' --stdin < "$FIXTURE_ROOT/answer.md"
bash skills/teamsmith/scripts/team --root "$FIXTURE_ROOT" reply list --json
bash skills/teamsmith/scripts/team --root "$FIXTURE_ROOT" reply show 1 --raw > "$FIXTURE_ROOT/export.md"
cmp "$FIXTURE_ROOT/answer.md" "$FIXTURE_ROOT/export.md"
```

SKILL/协议说明 Agent 先尝试发布、再正常答复，失败或 busy/unconfirmed 也不跳过答复。由 fixture Agent 验证两次出口使用同一正文，不能自动验证真实 Agent 一定遵守指引。发布只给 body-free receipt，不调用 notify、send、watch 或强制面板刷新；不新增正文审计日志。不可写时 stderr 是可靠诊断出口，同目录 audit 并非可靠后备。

### 2. 固定长度提交索引 + 不可变原文，不做全历史扫描

选择项目解析所得 state 下的 `key-replies/`：

```text
key-replies/
  writer.lock                   # 正规文件，只供 OS advisory lock
  index.v1                      # 追加的固定 4096-byte 提交槽位
  bodies/<random-32-hex>.md      # 不可变原文字节；文件名不来自标题/标签
  .tmp-<random-32-hex>           # 本次 publisher 的临时原文；读者永不枚举
```

索引是自包含提交目录，不另存 latest pointer/count/sequence 文件，避免多文件 head 更新造成「发布成功但最新摘要落后」和复杂恢复。每个槽位前 4064 字节为 `uint32BE(json_length)` + UTF-8 JSON + 零填充，最后 32 字节为前部 SHA-256。元数据含 `version,no,body_id,title,from,at,bytes,sha256`；JSON 长度有固定上界，body_id 与 no 都验证，不接受索引里任意相对/绝对路径。标题/标签限制保证元数据远小于一槽容量。时间记录 UTC ISO；排序依据提交编号，不依据时钟或 mtime。

`no = slot_offset / 4096 + 1`；show 用算术直接定位并检查槽内 no 一致。list 每次反向读取最多 50 槽，返回 cursor；坏槽显示对应 number unavailable，仍占一槽并可越过。summary 只读最后一个完整槽；坏最新槽明确 unavailable，不往前扫描并伪称最新。total_slots 只是编号槽数，不能当作已验证全文数。body 的 bytes/hash 在打开时验证，未打开时不读取全文。

读者先取 index 的长度快照，忽略并警告非整槽尾部；所有偏移运算校验安全整数和编号上界。按已有 cursor 请求旧页时，新 append 不改变已存在偏移。`before` 超出当前 newest 但仍在编号域内按最新界限夹住；非正整数/越界/路径式参数拒绝。list JSON 为 `{available,total_slots,entries,next_before,warnings}`，每行只有元数据或 `{no,available:false,reason}`。summary 有相同 empty/unavailable 语义，不读正文。show JSON 用 `display_text`、`bytes`、`sha256` 等，不声称显示文本哈希等于原文；raw 非 TTY 导出才是原文出口。

替代方案：单份 JSON manifest 的读写每次 O(N)，目录枚举再排序也 O(N)；只留最新 N 条切断旧答复；UUID 虽易并发但仍需排序/索引；SQLite 可正确事务化，但增加部署依赖。这套索引付出每槽 4 KiB 和一个小型版本化格式，换取直接定位、无需额外 head 事务及可测的恒定读预算。只支持单主机本地文件系统；不承诺 NFS/跨机分布式锁或任意外部改写后自动修复。

### 3. 锁与持久提交点

publisher 在读满至上限+1、校验输入之后，安全打开 writer.lock。helper 通过传入子进程的专用 fd 调用 `flock -w 2 <fd>`，锁属于仍由 helper 持有的同一 open-file description；helper 退出/被 kill 后内核释放，不依赖删除 PID 文件。锁路径本身不能是 symlink/FIFO；不用 O_TRUNC，不允许异步读者等待此锁。flock 等待限额与磁盘 I/O 耗时分别记录。

取得锁后只检查 EOF 邻近槽位和尾长：明确不足 4096 字节的尾部先截到此前完整槽边界，保留完整坏槽并拒绝继续。然后按下一槽编号构造元数据，使用随机 blob 名以免复用中断遗物；临时 body 用 exclusive create，写满、fsync，再无覆盖地发布到 bodies 并 fsync 目录。最后追加带校验的完整索引槽并 fsync。body 先 durable，槽校验完成才有可读条目；最终 fsync 后才输出 saved。state/key-replies/bodies 的新建目录按需 fsync，模式使用仅项目用户可写的私有权限。

```text
stdin -> bounded validation -> lock (<=2 s wait)
     -> fsync immutable original -> append checked index slot -> fsync -> saved receipt
                                                    |
                                 summary/list/show see committed slot only
normal Agent answer ----------------------------------------------> normal chat
```

中断 before index：孤立 body 不可通过 show 暴露，因为 show 先验证 committed slot；临时/孤立 blob 不列入任何页。中断 in partial append：读者返回旧完整槽加尾部警告，下个 writer 在锁内回收明确 partial tail。中断 after durable append before receipt：条目已可读；缺回执不自动重发。append 可见但最终 fsync 失败：`unconfirmed` 和候选编号，不假装 saved 或不存在。临时正文尽力清理；kill 造成的孤立 blob 保留而不引入后台 GC/全盘扫描。完整坏槽不当成可截的 partial tail，需由 PM/管理员另行诊断；本项不设计修复命令。

安全路径用解析项目内的 state 根，不用 cwd/继承 foreign TEAM_* 拼 storage。reply 存储不得逃出 main_root；如果既有自定义 state 不符合此条件，本能力可见拒绝，不重写配置。helper 验证目录 ancestry，并通过安全打开的目录 fd 锚定操作、文件 O_NOFOLLOW/fstat 校验拒绝 symlink 和非正规类型；实现需在现有 Linux 环境用 `/proc/self/fd` 的目录锚或等效 openat 路径完成，不能把仅 `realpath` 一次检查当成 TOCTOU 防线。验证用中途替换目录/文件的隔离控制，拒绝不安全目标，不声称可对抗已控制整个账号/内核的攻击者。

### 4. 三个按需块，复用渲染而不扩机器输出

新增 console-only `reply_summary`、`reply_list`、`reply_body`：对应 latest、cursor 和 number。内部接口为 `__panel-data --block reply_summary`、`__panel-data --block reply_list [--before <no>]`、`__panel-data --block reply_body --no <no>`；不借用任务详情的 `--id/--file`。摘要 TTL 15s，list 在 page 5 才 wanted（进入/翻页即后台强制读，稳定页 TTL 15s），body 仅查看时请求一次，手动刷新可重读。每块 10s child timeout；摘要 stdout cap 16 KiB，list 512 KiB，body 1 MiB（允许控制字符在 JSON 中膨胀），stderr 4 KiB。读取界限在 helper，管道界限在 data 层；不沿用每块统一 32 MiB 的宽界限作正文预算证明。

request key 包含块/游标/编号及代际。改变 key 时清旧错误/缓存、取消旧 child；后来的旧回调即使抵达也不 adopt。frame/input/render 只读内存 snapshot，不等待 block completion 或做同步文件读。坏源在本块有 empty/unavailable/partial-tail 标记；clock 与其他块继续运行。原来的 tick run loop 完全保持，不因回复创建工作。

`MACHINE_BLOCKS`、兼容 `team __panel-data` 聚合、piped/print/json 分支一律不加入 reply blocks。内部 __panel-data 的这三个块在 scan warm 前直接进入只读 helper，避免回复边界被既有 board/report 的全量扫描掩盖。`reply list/show` 加到 identity observation 分类，post 保持修改操作身份拒绝。读 helper 不调用会 mkdir 的 `team_state_dir`、不写 cache/audit，也不修 index。

### 5. 固定 page 5 与完整 body viewer

扩 PageId、页持久文件、defaultPage 偏好、snapshot `--page` 到 5，原数字键不挪位。Tab 顺序 1→2→3→4→5→1；settings 仍覆盖层。保留旧 requirement 标题 `The console composes four pages and remembers the position` 作为现有引用锚，正文明确五页，不通过新平行 requirement 留下两个相反合同。

overview 只放最新元数据与 `5`/点击跳转；到 page 5 后 Enter 打开同一个回复正文视窗。页签在 59 列采用短标签+数字、活动页清晰可见；不让用户横向滚页签。list 维护 cursor 链、stable no focus、row viewport；Older/Newer 是明确按钮与左右键，不拿隐藏计数冒充翻页。r 重置到 newest；从正文 esc/q 返回保持原页状态。list 的 wheel 是 viewport，不顺手改 focus；body 的 wheel/方向键/Pg/Home/End 只滚全文。正文沿用 markdown/width/layout，状态类型与任务文档详情隔离，避免数字 no 被误用为 task glob 或 `--file`。

回复不增加编辑、审批、已读按钮，正文中链接/图片不抓取。metadata/title/diagnostic 显示先净化再布局；body 原文存储与 display_text 分开。现有 `m`、发送/草稿仍是人→PM 通道，不变成回复 post。所有新 label/hint/error state 加进 zh/en；所有新可见 action 有等价鼠标目标。snapshot 矩阵加 summary/list/empty/corrupt/长文+四档宽度/双主题/双语；真实 pty 验证返回、页签、鼠标/resize 和末尾可达性，不能只用 JSON/快照宣称体验完成。

### 6. 模型路由的实际顺序与单写者交接

`task-model-routing` 修改 panel 的 `The console shows the project contract with its effect class, and refuses what it must not change`；本项必须修掉其中“not a fifth page / four-page composition”。本项该 MODIFIED 块以模型路由接受 delta 为基准全文保留其 category 命令和 machine-output 限定，只改变末尾为 settings 非顶层、page 5 给回复。其余两个 MODIFIED 块以当前 canonical 为基准。native validate 不会证明两个 MODIFIED 的排序正确，spec-refs 也不解析 proposal 的 deps 文本。

支持的最终投影顺序：先完整 `task-model-routing`，再 `pulse-key-replies`。当前基线单独投影只检验 delta 格式和 canonical 结构，不是可直接先部署的独立产品基线（它引用了 category settings 的已接受未来语义）。反序会让路由的旧完整块覆盖“page 5”，必须有反序冲突证据，不能作为并列可采纳方案。试归档只在独立复制品；PM 的真实 archive 仍需完整独立 verify + 用户确认。

未来 PM 分派三个串行写阶段：A 冻结 reply CLI/helper 与接口；B 读取接收后的模型路由 UI/核心和 A 接口，独占 panel/`cmd-watch.sh`，重建 bundle/快照；C 在两者冻结后独占 SKILL/references/help 与 smoke 入口。共用 common/team/cmd-watch/panel/字符串/bundle/snapshots/SKILL/协议/help 的每个路径都需要 PM 的 RECEIVED/释放记录，不能因 S1 候选报告就自行写，也不能让两个 change 同时改同一源文件。不同 verify owner 用另一个独立非部署 clone，分别记录 routing 的原有断言与 reply 新断言；不得弱化 routing 检查让此项绿。

P228 的 S1 冻结只提供 CLI/assignment 候选，不提供 UI/文档释放。后续输入必须是 PM 接收并标定的完整私有路由树，不是实际 main 或共享软链接目标；若路由尚未接收、S2/S3 未冻结，apply 进入依赖阻塞，不把缺失状态写成已完成。只读观察无需运行路由候选到真实团队。

## Risks / Trade-offs

- [新索引格式增加维护成本] → 单版本、小字段、固定 seek/checksum；故障注入和读量探针优先于功能点扩展，不加入自动修复/压缩。
- [正文与槽之间可能留孤立 blob] → 不可见、不枚举、不覆盖；记录磁盘增长，后台 GC 留在本范围之外。已提交内容不因空间紧张自动删除。
- [磁盘 fsync 很慢或失败] → 只界定锁等待，I/O 失败有 unavailable/unconfirmed；panel 独立超时隔离，不包装成全程 2s 承诺。
- [publisher 是自称、不能证明实际 seat/可信内容] → 界面写明 declared/self-declared，不引入认证与审批，不将正文作为可执行指令。
- [受上界限制，超长答复无法收录] → 明确拒绝、不截断，正常聊天仍完整发送；本次选择 128 KiB 与既有 detail 默认预算同量级，但不把旧 truncation 开关继承成新产品配置。
- [规模耗费磁盘] → 100000 条索引约 391 MiB，正文另计；规模夹具可用单字节合法 body，不需要 12 GiB 长文库。读预算用 syscall/受控 IO 记录证明，CPU/首帧只沿用既有 perf 前提，不把高负载 skip 当 pass。
- [反序覆盖 settings 合同] → tasks 的双投影/反序反例和 PM 手工顺序锁；本项不修改另一个 change。

## Migration Plan

1. 提案由不同作者独立审核；本轮不派 apply，也不勾实现任务。
2. PM 明确私有接收/释放后，在独立非部署路由输入上依次执行 A/B/C；空 store 无需迁移，无新配置键，不重写旧 config。bundle 和快照只在 B 的同一冻结源树重新生成。
3. 作者运行切片，独立 verifier 在冻结输入上运行全部场景和反例；最终 wrap-up 的全量 smoke/perf 由 PM 按机器资源与既有门禁纪律安排。
4. main 采纳前先解决共享技能软链接来源的影响授权/隔离；真实 Pulse 重启/配置采纳由用户另行确认。归档顺序与上述投影一致，不把试归档成功当真正 archive 权限。
5. 回滚采用上一冻结产品/bundle（保留 reply store，不删正文）；旧四页程序无法显示 page 5，会按其原合同 fallback。此行为不是新程序读坏页；回滚不启动共享服务、不自动删除 page/conf 或原文。格式破坏修复、跨主机 store 迁移另行评估。
