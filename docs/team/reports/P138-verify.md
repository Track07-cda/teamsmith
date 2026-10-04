# P138 · <peer-c> 的 settled + dirty 场景：当前 tmux 降级通道仍可卡住追问

agent: verify   status: PARTIAL（诊断交付；发现留给 PM 另开 apply）   time: 2026-09-30
branch: `task/P138-<peer>-team-say`   PR/MR: -（local，不 push）
被测 main：`59f5463e1486a184bd9d47ad6dea21c30ea221e9`；没有修改实现。

## 结论

**仍复现，但必须限定通道与“成功”的含义。**

- **默认 Pi inbox-watch 通道不复现**：真实 Pi 回合写出未提交文件并 settle 后，`say` 写 durable 行、wake、`read → intent → sent` journal，真实会话收到消息、调用模型、再次 settle；输入框不被打字。tracked 修改与 untracked 文件都测过。
- **无 watcher、走 tmux 降级通道时仍可复现“退出 0 / 绿色输出，但没有进入会话”**：上一条追问已经完成，真实 editor 为空，守卫却把聊天区读进输入框，判 BUSY。下一条追问返回 `✓ queued`，两次 flush 后仍在队列，真实会话/模型请求均没有它。Pi 0.99.1 上两次 dirty 与一次 clean 都复现。
- **没有复现“明确报已确认送达，实际上未送达”**。当前输出明说 queued，不能把它描述成假 ACK。问题是空框误判使本应排水的队列卡住，而非队列丢掉消息；durable 副本仍在。
- 未提交文件不是必要条件：clean 对照也出现空框误判和第二条追问卡住；投递判据读框几何，不检查 git dirty。不要派成“放宽脏工作树检查”。

<peer-c> 的两份指定原文只有现象句，没有 Pi 版本、原始帧、具体消息、启动参数和时序。因此，上述是**当前树上独立构造的同类投递失败**，不是声称重建了 <peer-c> 当时的完整现场。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P138-verify.md` | 结论、原始输出、代码路径、可派单发现及边界 |
| `docs/team/reports/P138-verify/pkg/` | 容器内真 Pi 场景、loopback SSE 服务、只读事件/editor 观察器、接收端判据 |
| `docs/team/reports/P138-verify/logs/` | stdout、逐回合事件、模型实际请求、原始 pane 帧、收件箱、outbox、wake、journal 的快照 |

所有 tmux 操作均在一次性 Podman 容器内部；宿主默认 socket 没有挂进去，也没有对它做查询或实验。HOME、Pi 配置与 session 目录都是临时目录；Pi 用 `--no-session`。没有读取用户凭据或其它项目会话。只杀容器里的私有 server 与自己 spawn 并记录 PID 的 SSE 服务。

## 最小复现与原始证据

### 可独立重跑

在本 worktree 运行（只写本报告目录；镜像须已存在）：

```bash
P138_SECOND=1 bash docs/team/reports/P138-verify/pkg/run-case.sh \
  tmux-second-host-dirty 59f5463e 0 host
python3 docs/team/reports/P138-verify/pkg/judge-second.py tmux-second-host-dirty
```

`host` 仅表示只读挂载本机 Pi 包（0.99.1），**不是在宿主跑 tmux**。历史源码通过 `git archive` 导入容器，绝不 checkout/reset 本工作树。证据目录已有内容时请先另存旧证据，或换 case 名；脚本不替用户删除既有证据。

场景的必要步骤：

1. 临时 git 项目 + 真实 `.worktrees/dev`；配置收件人 dev 与私有 session p138。
2. 真 Pi 加载 `team-notify.ts` 与观察器，**不加载 inbox-watch**，以覆盖生产代码明确保留的降级路径。
3. loopback 模型发出真实 `write leftover.txt` 工具调用，然后正常 stop；观察到 `agent_settled`、`idle=true`、`editor=""`，git 是 `?? leftover.txt`。
4. 第一条 `say` 实际进入 Pi 并完成新回合，但确认器把聊天文本算成框内容，错置 `held/draft-raced-left`。
5. 此时 editor 已空、agent 再次 settle。发送第二条 `say`，等待并连续两次 `outbox flush`。

第二条 stdout（`logs/tmux-second-host-dirty/second-say.txt`）：

```text
✓ queued for p138:dev: P138-SECOND-tmux-second-host-dirty（目标输入框里有草稿：没有写任何键；条目已入 state/outbox/，清空后自动投递）
  原因/条目：team outbox list ｜ 投递未确认的兜底：消息已在 docs/team/inbox/dev.md
```

退出码 `second_say_rc=0`。两次 flush 后（`second-outbox.txt`）：

```text
队列 2 条（held 1）
#1 [held]   1790748448358-0001-p138:dev.msg
   held-reason=draft-raced-left residue=in-box
#2 [queued] 1790748454528-0001-p138:dev.msg
```

- `state-after-second/outbox/1790748454528-0001-p138:dev.msg` 仍保存第二条消息。
- `inbox-final/dev.md` 有 durable 副本；不是磁盘层消息丢失。
- 第二条发送前后 `second-before.frame` / `second-after.frame` **逐字节相同**（cmp exit 0）。
- `dev-events.jsonl` 中只有 seed 与第一条追问的两个正常 settle，均 `idle=true, editor=""`；第二条没有接收事件，也没有 backend 请求。
- 把同一原始帧送进现有纯帧判据（cursor=29），结果为：

```text
idle-read=NOT-EMPTY
box_text=[ P138-SAY-tmux-second-host-dirty P138-ACK settled; no commit performed.────────────────…]
```

这条 `box_text` 是**上一条用户消息 + assistant 的聊天回复 + 聊天分隔线**，不是实际 editor 的内容。文件：`logs/second-frame-verdict.txt`。

### 接收端回归判据：红侧与正控

不是修改实现后的翻转；这是**同一当前实现，两条生产通道的差分反证**。

```bash
python3 docs/team/reports/P138-verify/pkg/judge-second.py \
  tmux-second-host-dirty tmux-second-host-repeat-dirty tmux-second-host-clean
# exit 1；三个 case 均 second_received=0, backend=0, settle_editors_empty=1
# FAIL second say stranded despite idle empty editor

python3 docs/team/reports/P138-verify/pkg/judge-second.py watch-second-dirty
# exit 0；second_received=1, backend=1, settled=3, settle_editors_empty=1
# PASS second say delivered
```

Pi 0.86.0 的 `tmux-second-image-dirty` 这一轮第二条送达，不能声称所有版本/所有帧都卡住。0.86.0 与 0.99.1 的普通首条 tmux case 都观察到了“实际收到，但被误记 held”这一前置误判。

默认通道完整正控（`logs/watch-dirty/`）：

```text
✓ said to p138:dev: P138-SAY-watch-dirty（pi 监视通道：已写收件箱 docs/team/inbox/dev.md + 唤醒指针；输入框零按键）
```

journal 的同一个 seq：`read seq=1` → `intent seq=1` → `sent seq=1`；接收端 `message_end` 的 customType 为 `team-inbox`，含该消息；随后实际模型请求包含 wake，assistant stop，再次 settle。前后 `?? leftover.txt` 不变。`watch-tracked-dirty` 则是前后 `M README`，settle 后不额外等 1 秒也送达。

## 归因与可派单发现

### F1 · 主发现：真实空框被聊天区污染，tmux 降级通道卡住后续消息

路径（均相对于 `skills/teamsmith/`，被测 main 的行号）：

1. `scripts/lib/cmd-agents.sh:1079` `team_cmd_say`：没有活 watcher → tmux 路径。
2. `scripts/lib/outbox.sh:1560` `team_send_guarded` → `team_delivery_verdict` / `team_input_box_state`。
3. `_team_box_geometry` 的上边框配对选择最高的等宽候选；`_team_box_rows_of_frame:220` / `_team_box_text_of_frame:335` 把实际聊天内容包含进框。
4. `team_outbox_process_entry:1360` 先 mkdir claim；BUSY 分支保留队列，再释放 claim，并非 claim 卡死。
5. 第一条已送达时，`team_tmux_deliver:672-705` 仍读到假 BUSY、payload + 聊天回复，返回 3；process_entry 放进终态 `draft-raced-left`。
6. 第二条由于假 BUSY不发键、保留 queued；`team_cmd_say:1132` 对 queued 返回 0，并输出“有草稿／清空后自动投递”。实际 editor 已空，所以这个恢复指引不成立。

已有代码注释承认“等宽聊天行扩大框”的保守成本；**本次是无裁切注入的真实 32 行 Pi pane 上的聊天分隔线**，不是仅造一个合成草稿框。是否扩充规格/改变几何策略由 PM 决定，不应直接改成“最近边框优先”，那会破坏已有防粘连约束。

可直接派单标题：**“tmux fallback 在真 Pi settle 后误把 transcript separator 配作输入框上边框：修正空框判断与确认状态，保留非空草稿安全性。”**

建议验收：重跑上述红侧使第二条真实进入会话且恰好一次；第一条不能实际送达后被记成草稿竞态；在真 editor 非空的负侧仍不发键；保留回放帧与 existing 等宽草稿/光标/横幅夹具。不许用 `--now`、删除 held 或放宽 dirty guard 掩盖问题。

**BLOCKED: 实现不在 verify 授权范围。PM 应另开 apply，授权 dev 类席位处理 `outbox.sh`、相应规格与测试；我没有修实现。**

### F2 · notify 的耐久指针与实际落盘收件人不一致（独立发现）

当前 `notify dev --from pm ...` 实际写 `docs/team/inbox/dev.md`，但敲的是 PM；outbox 的 `--inbox-written pm` 声明让 wake 指向 `docs/team/inbox/pm.md`。在 `watch-dirty` 的 `inbox-final/` 中只有 dev.md，PM 的实际 wake 却要求读 pm.md。

路径：`cmd-agents.sh:1208-1220` 的 append 使用收件人 `$agent`，之后调用守卫声明 pm 已写。短消息 preview 确实到达 PM，故不冒称 notify 整条丢失；但**耐久全文指针错误**。`notify dev` 也不能当成“立刻唤醒 dev”的替代命令。

可派单：**“notify 的 durable 收件人、outbox inbox-written 声明与 PM wake 的全文路径保持一致；用实际存在的全文文件验收。”** PM 先定接口契约，再派 owner；本任务不改。

## 历史比较：不能冒认某次改动修好了 <peer-c> 原事故

开始时默认通道不复现，因此做了历史区间端点/中点实跑，而非引用 M24/M30 的交付结论：

| 版本/节点 | Pi | 同一 seed + settle + dirty，首条追问的接收端 |
|---|---|---|
| <peer-c> 改动前 `7adc831a` | 0.99.1 | 收到 1 次 |
| <peer-c> 改动 `40bbad6a` | 0.99.1 | 收到 2 次；sender 最后 exit 1（旧确认器误判后重发） |
| M24 前 `d37ac18b^` / 后 `d37ac18b` | 0.99.1 | 都收到；都可能误记 held |
| M24 前 / 后 | 0.86.0 | 都收到；前 held，后这一轮确认成功 |
| M30 前 `d0f8b9a6^` / 后 `d0f8b9a6` | 0.99.1 | 都收到；后观察到 2 次 wake |
| 区间中点 P67 `baca95ee` | 0.99.1 | 收到 1 次 |
| 后段 P81 `b14157b1` | 0.99.1 | 收到 1 次，有 journal |
| 当前 main | 0.86.0 / 0.99.1 | 默认 watcher 均收到 |

原始证据是 `logs/hist-*` / `logs/pi86-*`，判据汇总 `logs/judge.txt`。P63/P71 是 proposal，不当成实现修复点。没有“首条不送达”的历史红端点，因而**不能完成有意义的 first-fixed 折半定位，也不能把当前绿武断归给 M24/M30/P67/P81 某一个**。M30 确实提供绕开输入框的通道；这解释默认路径为何不受 F1 影响，不等于证明它修复了 <peer-c> 当年的时序缺陷。后来已经在当前降级路径取到明确红侧，故任务的“仍复现 → 给最小现场和派单描述”分支适用。

## Verification evidence

实际运行的主要命令：

```bash
# 首轮：Podman 隔离、挂载当前源码只读与证据目录可写；真实 0.99.1 bundle 只读挂载。
distrobox-host-exec podman run --rm --network=none \
  -e HOME=/tmp -e P138_CONTAINER=1 \
  -e P138_PI_CLI=<home>/.bun/install/global/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js \
  -v "$PWD:/src:ro" -v "$PWD/docs/team/reports/P138-verify:/evidence:rw" \
  -v <home>/.bun/install/global/node_modules:<home>/.bun/install/global/node_modules:ro \
  -w /src localhost/teamsmith-gate:local bash /evidence/pkg/scenario.sh watch-dirty
# 同样跑 watch-clean / tmux-dirty / tmux-clean。

# 历史与版本比较（节点见上表；LONG=1 是较长单行，不是多行逃生门）：
bash docs/team/reports/P138-verify/pkg/run-case.sh hist-pre-m24-dirty 'd37ac18b^' 1 host
bash docs/team/reports/P138-verify/pkg/run-case.sh pi86-m24-dirty d37ac18b 1 image
P138_TRACKED=1 P138_SETTLE_DELAY=0 bash docs/team/reports/P138-verify/pkg/run-case.sh watch-tracked-dirty 59f5463e 0 host

# 二次追问的红侧/正控，以及第二次 dirty 与 clean 复跑：
P138_SECOND=1 bash docs/team/reports/P138-verify/pkg/run-case.sh tmux-second-host-dirty 59f5463e 0 host
P138_SECOND=1 bash docs/team/reports/P138-verify/pkg/run-case.sh watch-second-dirty 59f5463e 0 host
P138_SECOND=1 bash docs/team/reports/P138-verify/pkg/run-case.sh tmux-second-host-repeat-dirty 59f5463e 0 host
P138_SECOND=1 bash docs/team/reports/P138-verify/pkg/run-case.sh tmux-second-host-clean 59f5463e 0 host
```

- `judge.py` 的 `guard_failures=0` **只代表首条追问未丢 + 指定默认通道检查通过**；历史重复及 fallback held 仍逐行显示。不能拿这个值冒称所有投递行为全绿。
- `judge-second.py` 的上述 tmux 三个 case 是明确红侧，watcher 正控绿。
- 宿主 `openspec validate --all --strict` exit 127（CLI 不在 PATH）；随后在隔离镜像 `localhost/teamsmith-gates:p135` 重跑：**13 passed, 0 failed**。两个 stdout 都保留。
- `bash -n pkg/{scenario,run-case}.sh` 与 Python AST：通过，见 `logs/package-syntax.txt`。
- 最终 staged `git diff --check` exit 2：仅原始 smoke stdout 的 3298/3739/3745 行是带 6 空格的空行；为保留原始输出未剥离，见 `logs/staged-diff-check.txt`。报告与脚本范围的 check exit 0。
- 全量 `bash skills/teamsmith/tests/smoke.sh`：在 `localhost/teamsmith-gates:p135` 的独立 git 仓库跑完（`git archive` 导入当时的 `b2cd17f5`；实现与被测 main 相同），**exit 1，✓3795 ✗5，SKIP4，114 段收口**，耗时 1804 秒。完整 stdout：`logs/smoke-full.txt`。没有拿宿主 worktree 的 `.git` 指针充当容器仓库，也没有伪报绿。

### F3 · 全门禁未全绿：PM 接管的非本任务范围项

| 顶层红项 | 实际输出 / 边界 |
|---|---|
| 文档依赖扫描 ×2 | `references/troubleshooting.md:1148` 的 suite image / worktree 挂载说明被判成产品容器依赖，且 harness 豁免自测也红。该文件未被本任务修改。 |
| panel 坏 BOARD ×2 | chmod000 后期待待办块 `—` / `--block pending` 非0，实际可读。额外容器探针证实 **uid=0, chmod000_readable=yes**；本轮夹具没有建立“读不了”的前提。不能拿这两项证明 panel 正常，也不能拿它们归因 F1。 |
| config-cli group ×1 | 内层失败含 `a//b` 应拒绝却返回0、三段 catalogue id 窗口未识别、带后缀的反例回落到基名。最终内层 `✓334 ✗1`；完整原始尾部在 smoke 的 #84 段。没有继续修/调查这一独立范围，不能擅自归因镜像或实现。 |

这些是全量门禁的实际失败，不是 P138 红侧判据。**BLOCKED: PM 应交给对应文档/测试、配置与面板 owner 复核；verify 本任务仅记录，未跨目录修复。**

镜像：`localhost/teamsmith-gate:local` id `a55ccdacb577…`（场景，Pi 0.86.0 可作版本对照）；`localhost/teamsmith-gates:p135` id `4e41a51fa4b1…`（全门禁）。

## 没有测到的边界 / 偏离

- 没测非 Pi adapter、<peer-c> 原现场的 Pi/模型版本、真实远程 provider 延迟、机器负载下的概率、TTL 到期后的人工处置。
- loopback SSE 返回是确定性的测试模型；**Pi TUI、工具执行、生命周期、watcher、tmux 与生产投递代码都是真实运行**。这不能替代用户原 provider 的时序证据。
- 只观察发送、两次 flush 与之后的真实事件，不把“此后永远不会送”当作已证明；消息在 durable inbox / queued 中可人工恢复。
- 不把 `notify dev` 解释为唤醒 worker；它的当前实现敲 PM，实际接收侧也测了 PM。
- 没有为了报绿修改实现、规格、brief、看板、线程或他人目录。historical source 只存在容器内。
- 二选一结论“仍复现”是对**降级通道卡住活投递**而言；默认 Pi 通道和“假报已确认送达”两件事的反证均明确保留。

## Suggested next steps

1. PM 独立重跑 F1 红侧/正控，评估真实 Pi 聊天分隔线这一新几何形状，再开最小 apply；不要当 dirty-git 放行问题修。
2. PM 确定 notify 收件人/敲门/全文路径契约并单独处理 F2。
3. 接管 F3 的全门禁红项，修正文档扫描前提、root 权限夹具与 config-cli group 的未归因失败后独立重跑；本分支不是全门禁绿状态。
4. 若仍要归因 **<peer-c> 原事故**，请 PM 从该反馈渠道取得原始 Pi 版本、命令文本、pane 帧与启动方式，再寻找有实测红端点的历史区间；本记录不提供未经证明的 first-fixed SHA。
