## 1. 输入冻结与串行交接

- [ ] 1.1 PM 记录接受提案、完整 `task-model-routing` 的私有输入 tip、S1/S2/S3 RECEIVED 及 shared-path 释放；在独立非部署 clone 核对模型路由接口/源树，不运行其 CLI 到真实团队。输入缺失则报告依赖阻塞，不以 P228 S1 候选冒充完整输入。
- [ ] 1.2 在两个独立复制品用原生 OpenSpec 做当前基线单投影与 routing→replies 双投影；另做 replies→routing 反序对照，保存 warnings/rc 和保留全部 routing 场景/第五页的语义断言。不修改另一 change，不以 validate 代替顺序断言。
- [ ] 1.3 PM 串行分配 A（CLI/helper/common/team 与核心夹具）、B（cmd-watch/panel/bundle/快照与 UI 夹具）、C（help/SKILL/references/smoke 登记）；每阶段写集合和冻结 tip 完成后移交，下一 owner 不借候选报告抢写共享文件。

## 2. A：发布与只读数据接口

- [ ] 2.1 实现 reply 分发/观察身份分类和 versioned helper；实现输入/上界校验及安全 project-state 定位。实现新测试入口 `key-replies.sh --select input,paths`，未知测试组必须报错而非 0 assertions 通过。
- [ ] 2.2 实现不可变原文、checked fixed-slot 索引、稳定 no、OS fd lock、durable saved/unconfirmed 及安全部分尾部恢复；实现 `original,concurrency,receipts,interrupt` 组。故障注入只在隔离 fixture，包含 body/write/fsync/link/index append/final fsync/receipt 前后的精确落点；记录 SHA、number、实际 syscall/锁等待和每次 rc。
- [ ] 2.3 实现 latest、cursor list、number show 与 raw/non-TTY 导出；实现 `paging,bounded,readonly` 组，导出逐槽/逐正文 IO trace。不要调用会 mkdir 的 state helper、不全扫、不把坏页变成不可继续空页。
- [ ] 2.4 建立 fixture-only 反例 `key-replies.sh --select flip`：实际改坏存储/helper 的独立 scratch 源码，使 no 锁、早 saved、raw 丢末尾换行、无 cursor、全历史读、追软链、readonly mkdir 等具名 guard 判红；还原源码哈希后判绿。A 的冻结包包含 CLI 参数/JSON 格式、测试场景清单与 tip，供 B 只读消费。

## 3. B：五页与异步正文

- [ ] 3.1 在接收的 routing UI 输入上扩 PageId/偏好/页文件/main snapshot 到 5，保留原页面/设置语义；实现总览 metadata 入口与 paged stable-number focus。用 `key-replies-pty.sh --select pages,overview,list,compose` 验真实页导航、旧答复到达、返回/PM compose；保留原 panel-b3 的 pages/settings/conf/queue/board/workdetail 断言。
- [ ] 3.2 实现回复专用 body 状态与只读 markdown 视窗、完整滚动及返回；用 `key-replies-pty.sh --select body,mouse,resize` 验上界正文尾标记、坏源、focus/viewport、鼠标开关及 pane resize，不能用 task discovery 或 truncation 成功替代正文读取。
- [ ] 3.3 实现三个 console-only bounded async block、wanted gating、cursor/number generation/cancel、超时与输出上限；在 scan warm 前路由新块。实现 `key-replies-ui.sh --select blocks,machine` 与 `key-replies-pty.sh --select async`，捕获真实 block argv/文件访问、慢/失败/输出泛滥/晚回复，验证输入时钟不被读源冻结。
- [ ] 3.4 加齐 zh/en、active-tab 窄屏短标签、所有新点击目标和安全显示；实现 `key-replies-ui.sh --select snapshots,routing-regression`、pty 的 `language` 组。所有新 views 覆盖四档宽度、两主题、双语，routing settings 的完整接受场景仍可观测，既有字符串双向守卫不弱化。
- [ ] 3.5 在同一源树 typecheck/build；先逐帧审查新增与既有快照差异，再 `panel-snapshots.sh --update` 并无 update 复跑。记录 bundle 哈希与源 tip，运行旧 B3/setting/strings/contrast 切片和新 UI 命令，冻结后移交 C。不把作者抓图当独立体验通过。

## 4. C：指引与集成

- [ ] 4.1 在冻结接口后更新 help、SKILL/协议的主动关键答复示例；不引入 Pi 工具、配置键、待办/提醒状态或扩展工程。实现 `key-replies.sh --select workflow`，用 fixture Agent 在 saved/invalid/unavailable/busy/unconfirmed 后仍输出同一正文，保存 body-free 回执/诊断与 BOARD/outbox/inbox/pending/配置不变证据。
- [ ] 4.2 将新测试入口/fixture 路径登记到 smoke/section-select 的 owning section，不新建绕过门禁的独立套件；确认公开产品检出也运行实质检查。归档投影、引用、隐私、diff 和 routing 的既有功能测试分别出结果，不把结构绿当功能通过。

## 5. 独立验证与授权采纳

- [ ] 5.1 不同 apply 作者的 verifier 在另一冻结、非部署 clone 运行下表全部新组与保留的 regression；重新做 flip、并发/中断、10万槽 IO 边界、真实 pty/capture 和逐帧审查。报告每场景 command/assertion/rc、skip 及原始包路径；缺测不标 pass。
- [ ] 5.2 最终交付/PM review 按共享资源纪律后台运行全量 smoke 与参考 perf，分别记录完整性/性能及负载前提。先确认 /tmp 容量，容器用干净独立 clone；真 tmux 夹具只用经过证明的私有 socket。性能 SKIP 是未得结论，不是体验通过。
- [ ] 5.3 PM 在独立 verify 后另取用户对 main/共享来源采纳、真实 Pulse 更新和 archive 的授权；保留 store 的回滚策略按 design 执行。真实归档顺序 routing→replies，所有任务完成且用户确认后才归档，不把本轮试归档或 checklist 文件存在当执行授权。

## 6. 实现后运行的验收命令与证据出口

以下 **不是本轮已运行的命令**。新入口和 select 组由对应任务实现后才能执行；现有命令也只在独立 fixture/非部署输入执行。各入口用 `TEAM_REPLY_EVIDENCE` 导出原始日志（测试旋钮，不是产品配置），拒绝继承 caller TEAM_*，写盘前断言 `team paths` 的 main_root 等于 fixture；真实 inbox/state 前后不变。单个组不能以零断言或依赖缺失的 silent skip 通过。

```bash
export TEAM_REPLY_EVIDENCE="$EVIDENCE/replies"
bash skills/teamsmith/tests/key-replies.sh --select input,original,concurrency,receipts,interrupt,paging,bounded,paths,readonly,workflow
bash skills/teamsmith/tests/key-replies.sh --select flip
bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots,routing-regression
bash skills/teamsmith/tests/key-replies-pty.sh --select pages,overview,list,body,mouse,resize,language,async,compose

# 原有前门，需保留原断言；不把五页当成删除四页/设置测试的理由。
bash skills/teamsmith/tests/panel-b3.sh pages settings conf queue board detail workdetail mouse wheel resize collapse
bash skills/teamsmith/tests/panel-p21.sh
bash skills/teamsmith/tests/panel-choices.sh
node skills/teamsmith/tests/panel-strings.mjs
node skills/teamsmith/tests/panel-contrast.mjs
(cd skills/teamsmith/scripts/panel && bun run typecheck && bash build.sh)
bash skills/teamsmith/tests/panel-snapshots.sh --update  # 先审查，再重钉
bash skills/teamsmith/tests/panel-snapshots.sh
# 路由独立输入已有的前门；沿其接受任务保留全部组，不止新回复的组。
bash skills/teamsmith/tests/task-model-routing.sh

"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
# 只在最终稳定树且获相应 gate 范围授权后，后台启动并收割，不在运行中写树。
bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/perf.sh --container --tree "$PRIVATE_CLONE"
```

## 7. Scenario → 命令组 → 任务 → 证据

本索引只引用 delta 的场景，形式约束不在此复制。反向映射是每条 command/group 都对应下列一行或多行；existing regression 行保留 MODIFIED 全块场景，不删除旧断言。新测试的 `--select flip` 覆盖所有破坏臂，非破坏组也包含正常对照。

| delta / Scenario（同一行列出的场景全部覆盖） | 前门/组 | tasks | 最低证据 |
|---|---|---|---|
| key-replies / Explicit body rather than chat inference; Input boundary is enforced before publication; Repeated submissions are distinct | key-replies / input,original | 2.1–2.2 | 输入/原文字节哈希、上限±1、拒绝与缺失 reader argv、distinct no |
| key-replies / Simultaneous publishers preserve both bodies; Restart retains numbering | key-replies / concurrency | 2.2 | 同时真实进程、restart、两个 hash、连续 no、并发读快照；exhaustion 控制 |
| key-replies / Unwritable directory does not produce false success; Bounded lock contention; Durability uncertainty after publication | key-replies / receipts | 2.2 | 非 root 权限控制、无正文 stderr、锁等待区间、每 rc/receipt、unconfirmed show |
| key-replies / Killed before the visibility point; Killed after the visibility point; Complete corrupt tail is not erased as an interruption | key-replies / interrupt | 2.2 | 各精确故障点落盘快照、SIGKILL→新 writer、slot/blob/锁状态，旧记录 hash 不变 |
| key-replies / More than one page is actually accessible; All corrupt page still advances; New posts do not disturb older continuation | key-replies / paging | 2.3 | 123条 cursor 链、全部 no 恰一次、50坏槽、append 与继续页 |
| key-replies / Byte-exact export and safe visible text; Broken body is not silently abbreviated | key-replies / original,paths | 2.2–2.3 | CRLF/尾换行/raw cmp、safe JSON/TTY raw refusal、丢失/hash/UTF-8/超限诊断 |
| key-replies / Large history does not turn every refresh into a scan; Latest metadata cannot be validated | key-replies / bounded | 2.3 | 10万合法槽，真实 IO trace 的 slot/body/open/readdir 计数、坏最新不回退 |
| key-replies / Traversal and nonregular sources are refused; Declared label and hostile markdown remain data | key-replies / paths | 2.1–2.3 | ancestry/record 替换、软链/FIFO/目录/外根、无执行/网络/链接读、declared 标记 |
| key-replies / Normal answer survives every publication result | key-replies / workflow | 4.1 | fixture Agent stdout 等于原答复，全部 outcome 后仍发送，pending/outbox/BOARD/config 哈希不变 |
| key-replies / Missing and damaged stores remain unchanged by observation | key-replies / readonly；key-replies-ui / machine | 2.3,3.3 | 缺目录仍缺、坏源 hash/mtime 不变、无 mkdir/write/recovery/patrol |
| panel / Pages switch and the position survives a restart; An out-of-range page file falls back; An empty block collapses; The messages page lists the queue | panel-b3 / pages,queue；key-replies-pty / pages | 3.1 | 原页真实 capture/state，不按新页删旧页断言 |
| panel / Fifth page is fixed and remembered; Narrow tabs remain reachable | key-replies-pty / pages,language,mouse | 3.1,3.4 | 空页重启、Tab、59列zh/en数字/点击可达、原1–4不移位 |
| panel / A corrupt file falls back to defaults; A preference applies immediately and persists; Preferences never reach the machine exits; The navigation row opens the view and writes no preference; Default-page preference includes key replies | panel-b3 / settings,conf；key-replies-pty / pages；key-replies-ui / machine | 3.1 | 偏好/页 file、无 preference machine read、default5 与 invalid 对照 |
| panel / The rows carry the three classes and the unset key its default; The raw key is exactly where the CLI is named; A search by the raw key still finds the row; A key the schema does not know falls back to the raw name; The string tables cover the command's schema, both directions; The row set and the classes come from the command, not from the bundle | key-replies-ui / routing-regression；panel-p21；panel-strings | 3.4–3.5 | 接受的 category/schema 输入、双向缺标签红臂、unchanged bundle+changed CLI 控制 |
| panel / A refuse row opens no editor and the route is named; The filter narrows and clears; The focus window and the clicks; The origin is remembered and `q` keeps its meaning; The machine exits stay byte-stable | key-replies-ui / routing-regression,machine；panel-p21；panel-b3 / settings | 3.4–3.5 | refusal/filter/click/origin captures、config hash、路由可观察变化不冻结成旧 bytes |
| panel / Latest answer is discoverable from the fixed entry; Empty or corrupt latest source remains explicit | key-replies-pty / overview；key-replies-ui / blocks | 3.1,3.3 | 新发布→实际显示 title/no→点击/5→Enter，summary IO 无 body |
| panel / User reaches an old answer beyond the first page; A corrupt page still offers continuation | key-replies-pty / list | 3.1 | Older两次→#1全文→Back→Newer两次/r；全坏页仍有可用route |
| panel / Long body and local errors have real return routes | key-replies-pty / body | 3.2 | 128KiB尾标记End/Pg/wheel可见、q/esc还原context、坏body返回 |
| panel / Keyboard and mouse use the same row and page actions | key-replies-pty / mouse | 3.2 | 首点focus再点open、Back、Older/Newer、mouse off及私有tmux链 |
| panel / Compose and original page keys do not become publication | key-replies-pty / compose,pages | 3.1–3.2 | PM草稿/发送 argv不变、no post、viewer离开取消body |
| panel / Slow reader does not block input or a newer selection; View demand closes body reads | key-replies-ui / blocks；key-replies-pty / async | 3.3 | generation过期控制、timeout/flood、真实键/clock capture及wanted/cancel argv |
| panel / Machine paths never read key replies | key-replies-ui / machine | 3.3 | print timestamp排除后cmp、JSON结构cmp、piped/聚合无reply argv/open和write |
| panel / Width and language do not hide the return or older route; Hostile strings are sanitized without losing the answer around them | key-replies-ui / snapshots；key-replies-pty / resize,language；panel-contrast | 3.4–3.5 | 4宽×2主题×2语言×多状态 diff、raw pane bytes、renderer边界敌意输入、resize context |
| 上述关键 guard 的坏源码→红→还原 | key-replies / flip；独立重复控制 | 2.4,5.1 | matched=1、mutation/restore hash、具名失败与baseline/restored rc |

10万槽规模 fixture 使用合法 checked slots 和合法最小正文，另有单个上界正文，不要求顺序发10万次或存12GiB正文。IO 计数由 syscall trace/独立受控文件接口观测，不能仅引用源码里写着50。真实 pty 体验、完整端到端和独立 verifier 的后续证据均未在 propose 阶段生成。
