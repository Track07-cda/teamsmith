# P472 · 两项失败的只读归因

agent: verify   status: DELIVERED — read-only attribution, runtime causes not fully determined   time: 2026-11-17T03:52:18Z
branch: `task/P472-full-timing-failures-diagnosis`   PR/MR: -

## 结论

两项失败均有检查前提或观察顺序上的证据缺口，**现有材料不足以把任何一项定性为已证实产品缺陷，也不足以宣布是假失败**。V174 的两失败及整体 FAIL 不改。

- **F1：不是缺字。** 检查在含有标签和徽章文字的行上，因两者处于同一个 SGR 文本区间而失败，尚未比较颜色。CI 下未输出颜色是有源码支持的候选解释；原始彩色帧和进程环境已失，不能判定具体原因。旧 badge 表现检查交由 P470 一并处理，保留设置读值、修改结果及限制的必要行为，不另开并行 UI 修补。
- **F2：不是已证实“消息没有开始”。** 该场景已经等到批次为 `observed`，随后立即读取另一文件时没看到 `custom_start`。固定源存在“先写 observed、后由下游处理器写事件”的窗口；但实际事件文件已失，只能确认检查没有等自己的事件观察，不能确定这次是否仅为该窗口。失败后面的 G2 保护断言没有执行，不能顺带宣称它们通过。

下一步由 PM 裁定是否需要文中两条单场景观察；本单没有修代码、改断言、加时间、启动 Pi 或复跑。

## 输入与证据定位

- 固定源码根 `SRC=/var/tmp/v174-review-532c8b47.RgzJCh`，HEAD 为 `532c8b474f9aa3ec9d9094b28ae88463cd9d88e5`；只读 `git status --porcelain=v1` 无输出。下文产品及测试路径、行号均以这个根为准，不以本任务分支之后的实现为准。
- 原始日志 `RAW=/var/tmp/v174-verify.aScB4e/V174-verify.log`，SHA-256 为 `aab6cfd6cee9cde575074bc4ebbf7c7d397d772d861d38823b9b57857544c833`，与 V174 接受记录一致。已读 `docs/team/reports/V174-verify.md` 及主根 `docs/team/reviews/V174-acceptance.md`。
- 原 smoke 根 `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.cJomJ8`、snapshot `/var/tmp/teamsmith-snapshot.7rSXv7` 本次 `test -e` 均为 absent。13 份已有材料不含子场景帧、`events.jsonl` 或 Pi 会话记录；本轮没有补造或重新获取这些材料。

## F1 · 颜色检查没有取得可区分的文字样式

### 已证实

原始日志 4769–4775：

```text
38-f panel-p21.sh groups/settings/wheel 有失败
apply 徽章 = 普通文本 tone：run 结构不对（label=0 badge=0）
restart 徽章 = warn tone：run 结构不对（label=0 badge=0）
refuse 徽章 = dim tone：run 结构不对（label=0 badge=0）
== 结果 == ✓ 94 ✗ 3
```

`label=0 badge=0` 是 **SGR 区间的零基索引**，不是找到的文字数量。`tests/panel-p21.sh:1918–1925` 先选出同时包含完整 label 和 badge 的行，再分别查两者所在区间；文字不存在时会输出另一个错误“找不到同时含…的行”，未落入完整区间时索引会是 `None`。因此这三条失败已经证明所选行含有目标文字、两者同处区间 0，并且尚未执行 `1926–1934` 的值色、调色板及徽章颜色比较。它们不能证明 badge 未显示或颜色错误。

产生输入到断言的调用链：

| 环节 | 固定源位置 | 实际约定与结论影响 |
|---|---|---|
| 外层入口与失败摘要 | `tests/smoke.sh:20788–20804,20927–20939` | 原样跑 `panel-p21.sh groups settings wheel`；失败只摘取子日志的 `✗` 行和末尾统计，没有复制帧。外层 1 失败对应内层这 3 失败。 |
| 独立项目、真实数据与 bundle | `tests/panel-p21.sh:122–166,1960–1976` | groups 初始化真实项目及策略、设置 zh/auto，启动已提交 `scripts/panel/panel.js`；用同一 bundle 的 `--palette` 输出颜色表。 |
| 按实际数据等到目标行 | `tests/panel-p21.sh:199–207,315–329,2001–2019` | 依次过滤 `TEAM_MODEL_LIMITS`、`TEAM_PULSE_INTERVAL`、`TEAM_PROJECT`，等待稳定普通帧出现标签和相应状态词，再保存普通文字匹配结果。三处分别要求“模型并发上限…立即生效”“巡检周期…需重启”“项目名 root · 不可改”。 |
| 颜色取样 | `tests/panel-p21.sh:1885–1887,2005,2011,2017` | 另发一次 `capture-pane -p -e`，只取当前屏幕，不复用带滚动历史的普通等待帧；这个彩色文件没有单独做稳定性确认。 |
| 解析与判定 | `tests/panel-p21.sh:1896–1938` | 按 SGR 分段，要求 badge 所在区间严格晚于 label；当前三次都在这一步失败，未进入颜色比较。 |

产品源码确实声明了要画的内容：`scripts/panel/src/layout.ts:1614–1618,1638–1642,1753–1778` 把标签、普通文字值、徽章组成一行，标签用 heading/selected，徽章 apply/restart/refuse 分别用 text/warn/dim；`scripts/panel/src/App.tsx:222–233` 把每段交给带颜色的 Ink `Text`。这证明源代码约定，不证明丢失的实际屏幕具有相同颜色。

### 推断与尚不能证实

**无彩色输出是与三条错误一致的候选原因，不是已证实根因。** V174 原报告命令段显式 `export CI=1`；p21 的环境清理只去掉 `TEAM_*`（`panel-p21.sh:54–57`），启动 panel 的命令也没有固定颜色能力。已提交 bundle `scripts/panel/panel.js:312` 的颜色能力判断在一般 `CI` 环境下返回默认级别 0，已识别的 CI 平台或 `FORCE_COLOR` 才可能覆盖；`src/main.tsx:1012–1023` 只按 TTY 强制交互绘制，并未强制 truecolor。这条源路径能解释“有字但全在同一无颜色区间”，不能代替当时 pane 的环境与彩色帧。

缺失的是 `tone-{apply,restart,refuse}-e.txt` 的原始字节、同次普通帧，以及该 panel 进程的颜色相关环境。不能排除当时捕获了别的含相同文字的行、样式未输出或样式被终端合并；不能从 `0/0` 唯一认定 CI、错误行选择或产品配色缺陷。普通帧与彩色帧是两次采样，也不能补称它们来自同一次稳定屏幕。

### 最小下一步及 P470 边界

不为即将取消的逐行徽章另开修复或重跑 §38。若 PM 仍要求区分历史候选，最小只观察原 groups 的一个 restart 过滤点，保留同屏普通/彩色行及颜色相关环境：若目标行有词但无 SGR，是颜色前提未取得；若有有效样式却取错行/段，是解析错误；若有效目标行的颜色违反调色板，才有产品配色缺陷证据。本轮未执行该观察，也不据此把旧 FAIL 改绿。

带进 P470 的应是**设置值及其修改结果/限制**，不是旧徽章的词、颜色或区间数量：当前布局的值列明确是普通文字；现有检查分别覆盖不可改项不写配置（`panel-p21.sh:621–631`）、修改后显示新值（`860–882`）、重启类的写入回执说明生效时机（`928–930`）。这些行为不能随着 badge 断言一起删除。新界面可以按已批准方案取消逐行状态词，不要求继续画三种 badge，也不将本次诊断扩成新增功能或检查。

## F2 · 批次状态先被观察到，事件记录尚未被该断言看到

### 已证实

原始日志 5856–5873 唯一失败落在 `tests/remind-tool-real.mjs:557`：

```text
FAIL real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary:
  assert(events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'))
  at .../tests/remind-tool-real.mjs:557:9
remind-tool-real: passed=6 failed=1
```

这不是 `until` 的 `watchdog:` 异常。该次实际执行位置和固定源 `536–563` 可界定已经执行与未执行的部分：

| 顺序 | 固定源行 | 本次能证明的观察 |
|---|---|---|
| 初始响应结束，再制造忙碌轮次 | `540–546` | 等到 `agent_settled`，把本地受控 HTTP 响应挂起，再等到该请求已记录。场景使用本地 loopback provider，不是外部模型网络请求（`60–69,90–98`）。 |
| 提醒到期及调用返回 | `547–552` | 最后一批达到 `intent`，`inbox-watch.log` 已含 `intent-sent`，此刻事件文件无目标 `custom_start`，批次仍为 `intent`。这里只证明本例所查条件，不能把发送调用返回当成消息已实际开始。 |
| 人工 off/on 后释放响应 | `553–555` | 两个命令返回码断言均过，然后释放忙碌响应。G1 的 `team(...on...)` 在 `547` 没检查返回码，本例也没在冻结时断言 `batch.generation===1`。 |
| 等到产品状态，再查事件 | `556–557` | `lastBatch(info)?.phase==='observed'` 的轮询已返回，紧接着的独立 `events.jsonl` 读取没有匹配项。这是已观测到的两种文件状态，不是两者永远不同步的证明。 |
| 未执行的业务断言及回执 | `558–562` | `outcome.standby==='generation-ambiguous'`、`standby.on===true`、`generation===2` 及 `receipt.json` 写入都在失败之后，不能算通过或声称已有最终回执。 |

等待函数为 90 秒观察上界、50ms 轮询（`remind-tool-real.mjs:38–47`）；本次已经越过该等待而失败于随后的普通 `assert`，没有证据说是上界太短，更没有负载数据支持“机器忙”。

### 原产品接口及 SDK 形状

- 到期项由 ticker 执行 `remind-tick.mjs`，产品 watcher 从 queued 冻结为 intent，再调用 `pi.sendMessage(...,{triggerTurn:true,deliverAs:'followUp'})`，返回才记 `intent-sent`（`remind-tool-real.mjs:149–157`；`extension/team-inbox-watch.ts:1351–1376`）。`scripts/remind-store.mjs:259–280` 在调用前把当时待命代次及 session 固定到批次；发送返回不写 `observed`。
- 真正观察入口是 watcher 的 `message_start`：要求 `event.message.role==='custom'`、`customType==='team-reminder'` 和 batchId，再提交 `remind-observe`；authority 对 nonce/session/完整 members 再核对，才原子写 `observed` 和一次性结果（`team-inbox-watch.ts:1418–1444`；`scripts/remind-store.mjs:303–363`）。其中 `339–345` 只有同代才自动退待命，不同代保留并记 `generation-ambiguous`。这是固定实现的规则，不是本次 G2 实际结果的补证。
- 测试的 `custom_start` **不是 Pi 原始事件名称**：`tests/fixtures/remind-tool-provider.ts:8,51–54` 把同一 `message_start` 的 custom 消息追加到 `events.jsonl` 时改用这个记录名，字段从 `event.message.customType` 取得。
- 只读对照当前安装包 `@earendil-works/pi-coding-agent` 1.5.2 的公开 `docs/extensions.md:752–763,1580,1627–1649`、`dist/core/extensions/types.d.ts:856–860` 及 `dist/core/messages.d.ts:31–42`：公开事件携带 `message`，custom 消息为 `role:'custom'/customType/details`，followUp 等当前工作完成，事件处理器按扩展装载顺序执行。未发现本例字段使用与此公开形状矛盾；原始日志只记 Pi 路径，没有版本回执，所以此处不冒称 1.5.2 就是那次运行的已证明版本。

### 已确认的观察缺口，及尚未证实的运行时原因

**源码确认：状态文件成立，不保证稍后装载的测试记录器已经执行。** PM 的命令先添加 production watcher，再追加测试 provider 扩展（`scripts/lib/common.sh:3369–3393`；`remind-tool-real.mjs:90–98,113–122`）；event-after 没有 event-first 的提前暂停处理器。产品回调 await authority，而 authority 在 helper 内先 `writeAtomic` 发布状态，父进程等 helper close 才返回（`scripts/state-authority.mjs:145–157,449–461,464–494`）。测试驱动是另一个进程，直接同步读状态和事件文件（`remind-tool-real.mjs:31–35`）。按公开装载顺序，允许出现下列先后：

```text
Pi message_start → production watcher → 发布 observed
                                   ↘ 测试驱动读到 observed → 立即读 events 尚无 custom_start
                 → authority 返回 → 下游测试记录器追加 custom_start
```

`556` 没有等待 recorder，`557` 也没按 batchId/session 对齐该记录。因此检查把“产品状态已写好”和“另一个处理器已写好观察文件”当成了同一步，源码不保证这一点。这条发现改变的是后续观察的同步点，不等于已经证明本次运行正好落在此窗口。

**不能确定本次是晚写、未写还是记录器出错。** 原始 `adversarial-event-after/events.jsonl`、`requests.jsonl`、`inbox-watch.log`、`launch-stderr.txt`、G1/G2 命令回执、冻结和最终状态均随 smoke 根消失。日志没有失败后事件有没有补写的内容；也没有本例 frozen generation 或最终 `generation-ambiguous` 结果。不能仅凭 `observed` 的源码入口代替实际 message_start 记录，不能说消息丢失，也不能说 G2 被误清或被正确保留。

### 最小下一步

交 PM 决定是否只观察 **event-after 这一个已有场景**，不跑其余 adversarial/death、§69 或完整套件。最小区别性证据是：保留在读到 `observed` 的当刻、以及该 Pi 轮次处理完成后的同一 session/batch 的 `events.jsonl` 与状态，并保留已有 stderr/请求记录和 G1/G2 命令回执。若目标事件后来出现，就能证实即时断言早于记录；若轮次完成后仍无记录，就转查记录器装载/异常与事件分发，不能先补大超时或取消产品观察。读取 frozen generation 和最终待命状态，可同时确认该例确实覆盖 G1→G2，而不是只覆盖“发送后没有立即看到记录”。这是一条待裁定观察，本轮没有执行。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P472-verify.md` | 唯一写入文件；两失败的原始证据、固定源调用链、推断边界及最小下一步 |

## OpenSpec assessment

N/A — `change: -`，本单为只读归因，不是 change 验收。只读核对任务锚点 `verification#A gate that cannot judge says so`，不改规格，不执行 OpenSpec 校验。规格的“实际失败仍失败、证据不具备的判断不得报满足”与本报告保留 FAIL 的结论一致。

## CRITICAL

2 项原生未解决失败：F1/38-f、F2/69。这里计的是 V174 的失败，不把它们改称两项已经证明的产品缺陷，不给产品或发布放行。

## WARNING

2 项运行时归因边界：F1 缺同次彩色帧及颜色能力，F2 缺实际事件轨迹及最终 G2 状态。其具体缺件与最小区别性观察已分别列明；不靠当前源码补称历史现场。

## SUGGESTION

None — 未新增检查、保护分支、复现框架或性能限制。

## Final assessment

- Counts: CRITICAL 2（原失败保留）· WARNING 2（现场缺证）· SUGGESTION 0。
- Readiness: P472 只读归因已交付；V174 仍 FAIL。根因不全确定是本单允许的结论，不是等待自行扩大执行的理由。
- Unverified applicable checks and reasons: 未执行 Pi、业务样本、正常/变异用例、smoke/meta/完整套件、构建或 change 校验；brief 明确排除。未取回已清理的帧、SDK 事件、Pi journal，未查看 auth/models 或凭据。两条最小观察均未执行。

## Verification evidence

本次只有源/材料读取与本人报告的短检查，没有任何行为测试通过声明。只读身份及原件回执：

```text
$ git -C /var/tmp/v174-review-532c8b47.RgzJCh rev-parse HEAD
532c8b474f9aa3ec9d9094b28ae88463cd9d88e5
$ git -C /var/tmp/v174-review-532c8b47.RgzJCh status --porcelain=v1
（无输出）
$ sha256sum /var/tmp/v174-verify.aScB4e/V174-verify.log
aab6cfd6cee9cde575074bc4ebbf7c7d397d772d861d38823b9b57857544c833  /var/tmp/v174-verify.aScB4e/V174-verify.log
$ for p in /var/tmp/teamsmith-smoke-pm_skills-deb708fe.cJomJ8 /var/tmp/teamsmith-snapshot.7rSXv7; do if test -e "$p"; then printf 'exists %s\n' "$p"; else printf 'absent %s\n' "$p"; fi; done
absent /var/tmp/teamsmith-smoke-pm_skills-deb708fe.cJomJ8
absent /var/tmp/teamsmith-snapshot.7rSXv7
```

在本人工作树、本人任务分支暂存本报告后执行；标准 ledger 扫描的范围是本分支公开账本，diff 只检查本报告。实际回执：

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2852 hits=0 names=ok user=resolved
ledger_rc=0
$ git diff --cached --check -- docs/team/reports/P472-verify.md
（无输出）
diff_check_rc=0
```

F1 小步提交及本次完整报告短检查均为以上 `files=2852 hits=0`、rc=0；没有调用 `team review` 默认命令。

## Flip evidence

N/A — 本单未修缺陷，也未修改产品或测试；没有红绿翻转，不把源码推导写成实验。

## Decisions and deviations

- 无范围偏离。固定源只读；唯一写集为本报告，F1 先以 `9dc9fe5c` 小步提交，再补同一报告的 F2 与交付回执。
- 原始文件和 PM 固定 checkout 未修改或清理；没有触碰 P470 实现，不推送、合并、归档或发布。

## Suggested next steps

PM 按 F1/P470 的已批准边界保留必要设置行为，决定是否还需单行颜色观察；F2 若继续，先取单场景的前后事件/状态，而非修改产品、延长时间或整套重跑。本席位本单结束，不主动启动这些观察。
