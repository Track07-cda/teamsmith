# V165 · 候选与合并提交的独立短复验均通过

**阶段 A / B：PASS。** 候选 `bf483405aa067d69fce4e03e5b74ed86b11886b5` 的三项修复及单文件分类边界成立；合并提交 `7245bfefa4216b50a89e508bedbec14a7d710933` 的五个源文件与候选逐字节相同，从新检出执行的短显示、分类边界和结构检查也通过。中央 `team review P459` 已绑定合并 SHA，实际执行者 verify、判定 PASS。阶段 A 的显示旧红/恢复、初始化整文件比较与⑮、一次真实 Pi 及退出42、四组重放与污染反例保留，不重复 Pi、安装和完整反例组；不声称原18段重跑全绿或发布通过。

**组合证据可以接受，保留两组原件缺失的警告。** 四组现存 before/after 用原共享函数重放后，只消除了 `current.json` 这一项；另外两组仅有完整输出及未变调用，不能重放。原 `82ea7496` 的 **458/6、SKIP3、rc=1** 保留。下文同时保留阶段 A 与合并后阶段 B 的命令和范围。

agent: verify   status: DELIVERED（stage A PASS；stage B PASS，bounded combined evidence）   time: 2026-11-16T08:21:43Z
branch: `task/V165-release-ci-fixes-verify`   PR/MR: -

## Deliverables 与受验对象

| Path | 内容 |
|---|---|
| `docs/team/reports/V165-verify.md` | 本席位唯一仓内写入，两阶段结论、实测与缺口 |
| `/var/tmp/v165-verify.OFMrOZ/` | 独立短 runner、失败/成功记录、受控 Pi 原件、重放结果；待 PM 接受并收存所需证据后清理 |
| `docs/team/reviews/P459.md`、`P459-verify.log` | 由授权的 `team review` 写入中央记录；未手改 |

候选 `/var/tmp/p459-review-bf483405` 在运行前后 `git status --porcelain --ignored` 均无输出。相对授权基线 `ab52f1ee`，只有作者报告和以下 **5 个源文件，40 insertions / 22 deletions**；与任务书最终续跑授权一致：

- `skills/teamsmith/scripts/lib/cmd-review.sh`：同一替换函数增加左边界判断，去掉无边界的 `root/` 全局替换。
- `skills/teamsmith/tests/install-shape.sh`：参考初始化改成与裸 init 一样安装；首次配置准备仍显式 `--no-skills`。
- `skills/teamsmith/tests/remind-tool-real.mjs`：默认从调用者 PATH 定位 Pi、提前退出报真实状态、现有原件放进调用者证据根。
- `skills/teamsmith/tests/smoke.sh`：原 P440 矩阵增加 CI 布局、§67/68 同一定位规则、§67–69 原件目录交接。
- `skills/teamsmith/tests/lib/main-team-fingerprint.sh`：仅新增精确 `./state/remind-tool/current.json` 分类及一行注释。

已执行 `git diff --exit-code 82ea7496..bf483405 -- <前四个文件>`，rc=0：原三项修复与原长选段受测字节相同，最终只多共享分类的两行。包装器与原 `82ea7496` 逐字节相同。中央记录引用的作者工作树报告也与候选报告 SHA-256 相同，均为 `66ee536ad5c2a8365574b484a90b71137441cef5d94f6859e8bafb8bf4b23bf6`。

## 实际命令与结果

所有实际检查通过自己的仓外 runner 调用候选原函数或原 driver；没有在作者工作树运行，没有另写产品判定。`display.py` 原样提取现有 P440 输入/矩阵，`init.py` 原样提取共享函数与原⑮，`classification.py` 直接 source 原共享判据。

从 verify 工作树执行：

```bash
C=/var/tmp/p459-review-bf483405
E=/var/tmp/v165-verify.OFMrOZ
TEAM_GATES="bash $E/verify-short.sh" TMPDIR=/var/tmp \
  bash "$C/skills/teamsmith/scripts/team" review P459 \
  --dir "$C" --branch "$(git -C "$C" rev-parse HEAD)"
# 首次：后台 v165-candidate-short，rc=1；下述已完成步骤与观察脚本错误均保留。

TEAM_GATES="bash $E/verify-remaining.sh" TMPDIR=/var/tmp \
  bash "$C/skills/teamsmith/scripts/team" review P459 \
  --dir "$C" --branch "$(git -C "$C" rev-parse HEAD)"
# 续跑 v165-candidate-remaining：rc=1，错误程序与证据目录重名，尚未启动错误程序。
# 修正仓外目录名后 v165-candidate-final：rc=0；只补剩余检查，不重跑正常场景。
```

阶段 A 正式最终收据：

```text
时间: 2026-11-16T08:10:46Z · HEAD: bf483405a · 判定: PASS
实际执行者：verify
门禁命令：bash /var/tmp/v165-verify.OFMrOZ/verify-remaining.sh
limit=1800s queued=1s ran=40s
checkout clean；ignored artifacts: 0
V165 combined bounded short review PASS; original 458/6 unchanged;
two deleted snapshot pairs NOT REPLAYED; autonomy NOT RUN
```

| 检查 | 实际结果 / 依据 |
|---|---|
| `bash -n` 四个变动 shell 文件；`node --check` 原 driver | rc=0，`syntax.log` / `node-check.log` |
| 显示矩阵，两 HOME × C/C.UTF-8 | 新实现 4/4；同一私有副本恢复旧实现后 2/4，两个 HOME=/tmp 均红；同副本还原后 4/4，`display.log` |
| 共享 init 比较与原⑮ | 旧参考 rc=1；同形参考 rc=0；原⑮正常 rc=0、真正参数错误 rc=1，`init.log` |
| 原 driver 一个 `--select=adversarial-batch` | rc=0、1/0；真实会话/事件/provider 原件齐，`pi-normal.log`、`pi-normal/adversarial-batch/` |
| 显式 `P442_PI` 短命错误输入 | driver rc=1、done=42、没有 session-start、立即给出原错误，不是 watchdog，`pi-exit42.log` |
| 四组现存快照重放、当前记录/旁文件边界 | 全部通过，`classification.log` |
| `bash skills/teamsmith/tests/isolation-ledger.sh` | `pass=15 fail=0`；其中故意污染 inbox / unknown-state 的子检查各 rejected=1 |
| `openspec --version`；`openspec validate --all` | 1.16.0；20 passed / 0 failed，保留现有 warnings，不称 strict 通过 |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 122 references、49 distinct、retired 0、undeclared 0 |
| `bash skills/teamsmith/tests/section-select.sh --check` | ok13 / bad0 / SKIP1，缺生成目录 `.pi/skills`，不记通过 |

### Flip evidence · 路径显示与初始化反证

旧替换在 HOME=/tmp 的 C 和 C.UTF-8 两组实际输出：

```text
CI 路径：/var<home>/teamsmith-ci-tmp/review-wt /srv<home>/checkout /var<home> /srv<home>
```

候选与同副本恢复后逐字等于原矩阵期望：`/var/tmp/...`、`/srv/tmp/...` 不变；真正 main/home 根与子路径仍显示占位，兄弟前缀及既有中文/句末标点矩阵均成立。原真实 review 的精确路径、未净化红侧与同副本还原绿复用已核读的原 `selected.log:411–432` 和相应 `p440-review-*.log`，未再跑 §10。

初始化原共享检查实际报：

```text
old-reference rc=1：实际 10290 字节 / 期望 9438 字节
same-shape rc=0：整块等于显式渲染，契约字节不变
⑮ 对照 rc=0
⑮ 翻转 rc=1：期望 cfg-session:cfg-pm，实际 f-init-render-red:pm；名册也回到默认
```

没有忽略安装路径或改用部分比较。`same-shape/AGENTS.md` 与参考完整文件相同，SHA-256 `21771ad1ef622c567eed6d4c3c3fe584ac2cc9b38a306b4cf33b2a6c00be0f65`；config 不变判据由原共享函数实际承重。原 §39 内层 203/0 与⑮原输出也已核对，不把外层包含总结行的 204 当断言数。

### 真实 Pi，而非只信总结行

独立运行时私有 HOME 为 `$E/pi-home`，其 `.bun/bin/pi` 前后均不存在；unset P442_PI，PATH 包含调用者实际 Bun bin。实际解析为调用者家目录下 `.bun/bin/pi`，`--version` 实读 **1.5.2**；完整绝对路径留在私有 `pi.log`，这里不刊载账号家目录。

原 driver 正常场景只执行 **一次**，用时 5.10s，仅作参考。原件实读：

- 两份真实 Pi session：`01a1e364-acbd-705a-8d8d-f2d8c52832b7` 与外部替换后的 `01a1e364-bb0d-77bb-9678-62106767f073`；对应 sessionFile 存在且有 session 头。
- 32 条 events、5 条受控 loopback provider 请求、done=0。初始请求后，A+B 到期产生一次请求；场景又主动发送三次错误成员/重复/外部会话重放，故最终含 A+B 的请求共 **4**，不是总共 1。
- 原 driver 在主动重放前的“一次 A+B 请求”断言通过；最终 receipt 只有一次 `remind-observed`，批次成员与冻结 A+B 相同，较新的 Standby generation=2 仍为 on。
- 显式错误输入实际得到 `Pi exited before session_start: rc=42`、`V165 controlled Pi startup failure`，done=42、零 session-start；耗时 0.52s 作参考，没有 `watchdog:`。没有改 watchdog 或用假 HOME 软链。

只使用原 fixture 的 `http://127.0.0.1` provider，没有真实外网模型、外部收件人或真实团队提醒。此证据不证明模型自主创建/重新创建提醒，自主性验证 **NOT RUN**。

### 单文件分类：四组重放与污染反例

独立 `classification.py` 直接 source 旧 `82ea7496` 与候选共享函数，输入均为原 before/after，无合成快照。四组各自输出均为：旧判据仅报 `./state/remind-tool/current.json`，候选无违例；八个文件哈希与作者报告完全一致。

| 原件目录 | before SHA-256 前16位 | after SHA-256 前16位 |
|---|---|---|
| `/var/tmp/teamsmith-remind-cli-pm_skills-deb708fe.VTEY1g` | `03d7d440de5f2cf6` | `f74fe29e21da28dd` |
| `/var/tmp/teamsmith-remind-delivery-pm_skills-deb708fe.icXotV` | `2e63c187bdac08e9` | `1932868b2b68f7a8` |
| `/var/tmp/teamsmith-remind-lifecycle-pm_skills-deb708fe.OTBQO0` | `a53f9394bbed56bb` | `4c85db4926d61c35` |
| `/var/tmp/teamsmith-remind-pulse-pm_skills-deb708fe.vJaij0` | `ed7e9a6b34885c00` | `eeb085ea282bcdbe` |

运行记录可以正常变化的理由不是 PM 口头许可：候选 `extension/team-remind.ts:85,99–106` 每 5000ms refresh/publish，`scripts/remind-capability.mjs:140–143` 每次写入新的 at；分类 diff 仅精确单路径，且仍先拒绝 authority surface。

短反例实际调用原 `main_team_snapshot/main_team_violations`：只改 current.json 时旧判据拒绝、新判据接受；新增再修改以下 **8 个文件**，新判据每次都逐条报出：

```text
./reminder-locator.json  ./reminder-locator.log
./state/reminders/state.json
./state/standby  ./state/standby.log
./state/remind-tool/side.json  ./state/remind-tool/sibling.log
./state/v165-stray.json
```

`.log` 变体证明权威文件仍优先拒绝、同目录旁文件也没有随目录整体放行。没有触碰真实 locator/reminders/Standby。

另外两组仅核读完整 `p444-faults.log` / `p444-real.log`：12/0 和 7/0、唯一违例均为 current.json；两封装与 `82ea7496` 字节相同，仍调用同一共享函数并无条件删除 before/after。它们 **NOT REPLAYED**。未为补原件重跑 12/7 场景。

## 原组合证据与本轮范围

已核读候选报告、5 文件 diff、作者 `classification-check*.log`、原 645 行 `selected.log` 与 Pi 工具/恢复/对抗日志。原固定 `82ea7496` 的 18 段仍为 **458/6、510s、SKIP3、rc=1**；§10=47/0、§10b=72/0、§39内层203/0、真实 Pi工具/恢复/对抗10/3/7通过，六条外层失败均点名 current.json。最后三项日志有原 p442/p443/p444 目录，不把它们当本轮新执行。

接受范围是“原固定字节业务证据 + 本轮独立短验证 + 精确分类变化”；不声称最终 tip 上一次原样 18 段全绿，也不把缺失两组快照的风险消掉。前导三个 skill-load SKIP 和本轮 section-select SKIP 保留。

## 阶段 B · 合并提交短复验

PM 提供固定 `7245bfefa4216b50a89e508bedbec14a7d710933` 和 `/var/tmp/p459-review-merged`。运行前后该检出含 ignored 检查均干净；相对候选仅9个账本文件变化，五个源文件没有变化。`merged.py` 先将新检出的5份文件与 `git show bf483405:<path>` 原字节比较，再从新检出的 smoke 提取原显示矩阵、source 新检出的显示/分类函数；未执行旧 candidate 的硬编码入口。

| 同一文件 | 两阶段共同 SHA-256 前16位 |
|---|---|
| `scripts/lib/cmd-review.sh` | `47512668e9ed2bf8` |
| `tests/smoke.sh` | `3cde9c67851045ef` |
| `tests/install-shape.sh` | `b624e98cd1d0ede8` |
| `tests/remind-tool-real.mjs` | `965c9aa178853aa9` |
| `tests/lib/main-team-fingerprint.sh` | `616f00b84d11260e` |

正式命令从自己的 verify 工作树发起，后台作业 `v165-merged-short` 已收割 rc=0：

```bash
C=/var/tmp/p459-review-merged
E=/var/tmp/v165-verify.OFMrOZ
TEAM_GATES="bash $E/verify-merged.sh" TMPDIR=/var/tmp \
  bash "$C/skills/teamsmith/scripts/team" review P459 --dir "$C" \
  --branch 7245bfefa4216b50a89e508bedbec14a7d710933
```

```text
时间: 2026-11-16T08:21:21Z · HEAD: 7245bfefa · 判定: PASS
实际执行者：verify
门禁命令：bash /var/tmp/v165-verify.OFMrOZ/verify-merged.sh
limit=1800s queued=1s ran=22s；checkout clean；ignored artifacts: 0
IDENTICAL：5个源文件
MERGED display rc=0：原两HOME × C/C.UTF-8矩阵4/4
MERGED current.json-only change ALLOW
MERGED sibling / reminders / Standby / locator / unregistered additions REJECT
MERGED same five modifications REJECT
OpenSpec 1.16.0 validate --all：20 passed / 0 failed，既有warnings保留
spec-refs：122 references / 49 distinct / undeclared 0
section-select：ok13 / bad0 / SKIP1（.pi/skills未生成）
bash -n四个shell文件与node --check原driver：rc=0
```

分类五个短输入为 `state/remind-tool/side.json`、`state/reminders/state.json`、`state/standby.log`、`reminder-locator.log`、`state/v165-merged-stray.json`：新增和修改均逐条拒绝，仍证明权威状态优先、不排除整个目录。所有样本仅在自己的临时根。阶段 A 的真实 Pi、初始化、旧实现红/恢复、四组原件重放均按同一源字节复用，没有再执行。

中央记录与完整日志已复制到 `$E/review-merged-pass.md/.log`；log SHA-256 为 `45b32366e5fc41f0972e9b7436bf9dee0572465b6a671c0049589188e1037121`。阶段 A 的成功与两次验证脚本失败记录仍在原路径。合并后的 diffstat 为无变化，是与当前受保护分支相同，不是缺少五文件同一性验证。

## OpenSpec assessment

`change: -`，不新增/修改规范；按 `verification#The record states what was verified` 审查。检出没有生成的 openspec-verify-change skill，采用等价人工审查：逐项对照授权、冻结字节、原始收据、命令/执行者/版本绑定和未跑范围，不把 shell 通过替代本节。

| Dimension | Assessment | Evidence |
|---|---|---|
| Completeness | 两阶段限定范围完成 | 候选三修复/分类实测；固定merged五文件同一性、短显示/分类及结构检查通过 |
| Correctness | 在所列组合证据范围 PASS | 路径旧红/新绿/恢复、init旧参考红及⑮真参数红、真实Pi与42、四组重放和8文件反例 |
| Coherence | 符合原功能和证据边界 | 中央记录先后绑定verify/bf483405a与verify/7245bfefa/实际命令/PASS；原458/6及两组原件缺口未改写，无新产品或守卫框架 |

## CRITICAL

None。没有找到本轮冻结输入的可证行为反例；两次中央 FAIL 均来自下述仓外验证脚本，而非产品失败。

## WARNING

1. **两个隔离快照对缺失。** 只能独立核其完整12/0、7/0输出及未变调用，不能对这两组做原件重放；接受组合证据不扩展成六组原件齐全。
2. **已披露检查前提未满足。** 原 skill-load 三项和本轮 section-select 生成目录一项 SKIP；OpenSpec 1.16 非 strict 为20/0但保留长 requirement、既有 Purpose 占位等 warnings。未跑 strict，不据此声称全项目严格校验通过。

## SUGGESTION

None。本轮不追加收集器、长期选择器或其它机制。

## Final assessment

- Counts：CRITICAL 0 · WARNING 2 · SUGGESTION 0。
- 两阶段在任务书限定范围可交付：候选组合证据及合并后的短复验均通过；不是一次最终提交全量全绿，也不是发布结论。
- 阶段 B 已由同一 verify 会话执行，固定SHA/干净检出、五文件同一性及短检查证据齐；PM可接受并办理P459收尾，本席位不合并或关单。
- 本轮未跑全量/FAST全量、61b/meta/夜间/性能/三路线安装；未重跑§10/10b/39/67–69整段、20/7场景整组。原未执行的123个键列表仍在 `selected.log`，本报告只引用其实际执行范围。
- 未做远端CI、push、PR/MR、merge、tag、npm、依赖安装、模型/SID切换或共享状态调整。主检出写入仅为授权工具的 P459 两个中央文件及既有运行账目。

## Decisions and deviations

- 两次验证侧错误均保留，不改候选：首轮把完成重放后的 A+B 请求总数误当作重放前请求数；原 driver 已1/0，原件显示5次请求含3次主动重放。第二轮因测试程序 `$E/pi-exit42` 与证据目录同名，Node 在启动测试程序前 EEXIST。仅修仓外观察/目录名，正常 Pi、显示、init均没有重跑。
- 首轮/第二轮中央记录覆盖前已分别保存 `review-first.md` / `review-first-gates.log`、`review-second.md` / `review-second-gates.log`，最终成功记录另存 `review-candidate-pass.md/.log`。三份 gate log SHA-256依次为 `ffe0f5ca4a72a40bdba5d4b39706a8d39b6e3efe762058b0a96d67a7c2047e4b`、`53b03cc239ae8ded9223a919fdac94a86c686c770bbc0c89362afa3a3430c3a8`、`62f5fc9165d2118c34df0916d3c886dc7fbaf3168d6636910bd31bb1c590e344`。
- PM 07:55暂时暂停时尚未启动验证；解除后从三份原草稿继续。.cortexkit未被修改或清理；没有把网络中断当测试红或额度耗尽。

## 收尾检查

本报告暂存后在自己的工作树/任务分支实际运行：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2743 hits=0 names=ok user=resolved
ledger-ban-rc=0
$ git diff --check && git diff --cached --check
diff-check-rc=0
```

阶段 A 的上述收据保留。阶段 B 报告暂存后在同一分支再次实际运行：

```text
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2743 hits=0 names=ok user=resolved
ledger-ban-rc=0
diff-check-rc=0
```

本报告只提交在本地任务分支，无远端操作；供 PM 接受两阶段证据并办理收尾，不自行合并或关闭 P459。
