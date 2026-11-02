# P393 · 实现 watch-first、默认立即尝试的 `team say`

## 结论

已交付实现。默认 `team say` 现在的顺序是：**可信活 watcher 优先（durable inbox + spool，零按键，草稿不动）；没有可用 watcher 时，在用原有收件人/窗口/死 pane/空 shell 检查确认目标可投之后，复用同一条 forced 动作做一次立即尝试**（即使输入框里有草稿），回执写明「已尝试立即发送；未确认模型接收」。公开 `say --now` 已退休：两个位置都走既有 unknown-flag 路径、exit 2、投递面逐字节不变；`--any`、`--no-verify`、`outbox flush --now`、`draft send --now` 保留。其他发送方（notify/唤醒/meeting/Pulse/draft/普通排水）的草稿守卫与显式 override 不变。

实现提交（Base `eb8250a2`，本地模式，未 push、未合并、未归档）：

| 提交 | 内容 |
|---|---|
| `bf8e5ec0` | 产品接缝：退休 parser 旗标、`team_say_prepare_direct`、fresh `kind=say` 复用唯一 forced 动作、`--watch-only` 私有处理模式、初次入队失败为非零持久化错误、尝试回执 |
| `d66fdf4b` | smoke 迁移与新增（12b-c 默认直投/`--no-verify`/记录型 payload 失败；12b-pi 监视优先、陈旧/外来注册、spool 失败、路由丢失、初次入队失败、三条 scratch 变异） |
| `51b306e0` | delivery-truth 受保护发送方迁移 + 静默报告变异改指 `cmd-draft.sh`；help-surface 探针/旗标基线/两位置拒绝 + 五面指纹；真实 Pi A/B 配方 |
| `70a4dc22` | 配方 scratch/HOME 落 bind mount、草稿字节/光标/发送前帧单独存放 |
| `0b14cd3f` | A/B 判据区分基线 `--now` 措辞 |
| `469ed8db` | `section-paths.tsv` 声明 12b-pi 新读的 4 条路径（`section-select --check` 要求） |
| `de01d811` | 12b-h 两个 held 用例的 durable 断言落回受保护通道（held 条目 + 草稿文件原样），闭包唯一的两条红就此修复 |

改动文件（相对接受基点 `eb8250a2`，全部在任务书写集内）：`scripts/lib/{cmd-agents,outbox}.sh`；`scripts/strings/{commands,help.en,help.zh}.tsv`；`SKILL.md`、`references/{config,troubleshooting,agent-adapters}.md`；`tests/{smoke,delivery-truth,help-surface}.sh`、`tests/section-paths.tsv`、`tests/fixtures/delivery-truth-real/{README.md,run-case.sh,scenario.sh,judge-dirty-ab.py}`；`openspec/changes/say-immediate-default/tasks.md` 与本报告。未改 canonical specs、其他任务/评审/看板、AGENTS/PM/worker 启动提示、P391/P388 文件、发布/CI 或活团队状态。

## 行为与接缝（实现后的事实）

- **路由只在一个地方决定**：`team_send_guarded` 里 fresh 的 `kind=say`（且没有显式 override）先用现有 watcher 谓词选一次路由：选到就在本次即时处理里走 `--watch-only`；没选到才进入 forced 动作。生产代码里没有 `default_direct` 旗标、没有按 kind 强制的队列处理器分支、没有新配置/队列/daemon。
- **目标检查移到了直投前一刻**：`team_say_prepare_direct <agent> <target> <msg>`（`cmd-agents.sh`）原样搬来窗口不存在、死 pane、空提示符三项，返回 `2` 表示「已离线处理完」；调用方有独立的 `offline-handled` 分支，绝不重复追加收件箱兜底。旧的 caller 侧 watch 探测与其条件检查块已删除，所以已选中的监视通道不需要看 pane，被拒绝的注册也不可能绕过检查。
- **已选中的监视通道不会换道**：`team_outbox_process_entry` 新增私有 `--watch-only`；路由在写入那一刻消失或收件箱/spool 写不进去 → 条目留在活动队列、零按键、零 forced、返回既有 `queued` 结果（本地原因 `watch-pending`，措辞不再假称「目标有草稿」、不再承诺「清空草稿就送达」）。enqueue 之后仍无条目 → 新分支 `persist-failed`：点名写不进 `state/outbox/`、非零退出、不声称排队或离线成功。
- **一次尝试一条审计**：默认直投只在 forced 动作里记一行，格式与字段顺序不变（`<ts> kind=say from=pm target=<target> entry=none`）；watched/offline/rejected 一条都没有。
- **回执诚实**：forced 结果输出 `attempted immediate send to <target>: <msg>（已尝试立即发送；未确认模型接收；跳过草稿守卫已记入 state/outbox/forced.log）`，不再出现 `已确认送达`，也不承诺失败会自动入队。旧的 tmux best-effort（返回码、快照等待、可能的第二次 Enter）原样保留，未做恢复重写。

## 验证（全部在最终树上实跑）

环境（login bash，显式解析 PATH，未改任何 shell 配置）：

```bash
bash -lc 'export PATH="$HOME/.bun/bin:$PATH"; command -v openspec; openspec --version; command -v pi; pi --version'
openspec=$HOME/.bun/bin/openspec → 1.8.0
pi=$HOME/.bun/bin/pi → 1.4.0
（实输路径按账本禁令脱敏成 $HOME；同一 PATH 下所有命令退出码 0）
```

**真实变更路径闭包**（`section-select.sh --paths`，16 条改动路径全部输入）：

```text
decision=RUN   sections=135   keys=85
0,0b,0c,0d,0e,0f,0h,0i,2,4,4b,5,3b,6,6b,6e,6f,6g,6h,6i,6j,7,7b,9,10,11,11b,11b3,11c,11f,11g,11h,
14b,15b,15c,13c,12b,12b-h0,12b-h0b,12b-h0d,12b-h0c,12b-pi,12b-pi2,12b-pi3,14,14c,17,18,18b,19,25,
26,27,28,29,31,31c,32,33,12g,12h,12i,12k,34b,34c,34d,36,40,42,43,44,45,46,47,49,51,51c,54,55,56,
57,59,61,64,14d
```

闭包非 FAST 实跑（`env -u TEAM_SMOKE_FAST bash skills/teamsmith/tests/smoke.sh --select <上面的 85 键>`，后台 3935 s，日志 `/var/tmp/p393-smoke-closure.log`）：`== 选段结果 == ✓ 4013 ✗ 2`。两条红都出自**我自己**的迁移（12b-h 静态页脚 / 吞 Enter 两个用例改成 `draft send` 后仍在断言 pi 通道的收件箱行），在 `de01d811` 落回受保护通道的 durable 断言（held 条目里有全文 + 人的草稿文件原样未动），随即在最终树重跑该族：`env -u TEAM_SMOKE_FAST … --select 12b,12b-h0,12b-h0b,12b-h0c,12b-h0d` → `SMOKE_RC=0`，`== 选段结果 == ✓ 402 ✗ 0`（12b ✓102、h0 ✓5、h0b ✓20、h0c ✓126、h0d ✓83）。**边界**：闭包本体跑在 `469ed8db`，最终树相对它只多了 `de01d811` 的 12b 断言改动，其余段的产品/测试代码逐字节相同。

**最低相关闭包**（任务 6.2 的 17 键）全部包含在上面 85 键里，且在闭包里非 FAST 真跑过；12b 全族另在最终树上重跑过，故不再单独重跑一套（FAST 一次都没用过）。

`env -u TEAM_SMOKE_FAST bash skills/teamsmith/tests/delivery-truth.sh --section all --mutations`（最终树，36 s）：`== 总计 == ✓ 125 ✗ 0`，八段全绿（frames 25 / drafts 35 / foreign 51 / queue 76 / receipts 88 / notify 103 / panel 113 / judge 125）。

`openspec validate say-immediate-default --strict` → `Change 'say-immediate-default' is valid`；`openspec validate --all --strict` → `Totals: 20 passed, 0 failed (20 items)`；`spec-refs.sh --check` → `retired 1; undeclared 0`（被退休的正是本 change 声明的 P143 历史引用）；`section-select.sh --check` → `ok 12 bad 0`（补声明后）；`ledger-ban.sh` → `files=2250 hits=0 names=ok`；`git diff --check` 无输出。

### 解析与帮助面（两位置拒绝、零副作用）

`help-surface.sh` 的 say 段（`TEAM_HELP_SURFACE_ONLY=say`，同样出现在闭包的 51 段全量跑里）：

```text
✓ say --now（收件人之前）→ exit 2 并点名 --now
✓ say dev … --now（消息之后）→ exit 2 并点名 --now
✓ 两次拒绝后 keys/inbox/spool/forced/queue 指纹逐字节不变
✓ 对照：一次普通 say 改变了指纹（所以「拒绝臂不变」不是瞎的）
```

指纹分五面：记录型 tmux 的 `send-keys` 行数、`docs/team/inbox`、`state/inbox-watch`（spool）、`forced.log` 哈希、活动+held 队列 `{名字,大小}` 集合哈希。Bilingual：`commands.tsv` 的 say 行删掉 `--now`（用法串与旗标列），`help.{en,zh}.tsv` 只删 `cmd.say.arg.--now` 并改写 `cmd.say.what`；`draft`/`outbox` 的 `--now` 仍在清单与页面上。

### 默认直投 / 审计 / 队列（smoke 12b-c，闭包与最终树各一次全绿）

```text
✓ 脏输入框：draft send 退出码 0            ✓ 受保护发送输出含 queued
✓ 排队时绝不说「已确认送达」                ✓ 队列里恰好一条 dev 条目
✓ 受保护发送一个键都没发                    ✓ payload 逐字节在条目里
✓ 脏框默认 say：退出码 0                    ✓ 脏框默认 say 报的是立即尝试
✓ 脏框默认 say 不确认模型接收               ✓ 脏框默认 say 真的把消息打进框里
✓ 脏框默认 say：forced.log 恰好一行         ✓ 审计行保持既有格式（kind/from/target/entry）
✓ 脏框默认 say：零活动条目、零 held（不需要 flush）
✓ 空框默认 say 也直投 / 一条审计、零条目 / 也不确认送达
✓ --no-verify：仍然打字并留一条审计、不入队 / 真的省掉了快照读取
✓ 直投失败：仍然 rc=0（尝试已发生）/ 措辞仍是尝试 / 不假装回执 / 不承诺自动入队 / 仍只有一条审计、零条目
```

### 监视通道（零按键、路由丢失、持久化失败）

smoke 12b-pi（同上闭包内）证据摘录：

```text
✓ 12b-pi 脏框监视投递：forced.log 一行都没有（watch 不吃直投）
✓ 12b-pi 脏框监视投递：草稿一个字节都没动（tmux 零调用即零按键）
✓ 12b-pi 无注册（非 pi / 未装扩展）→ 默认直投（尝试）/ 不冒充回执 / 真的打字 / 留一条既有格式审计
✓ 12b-pi 默认 say + 活监视器：走监视通道 / 零按键、零 forced
✓ 12b-pi ⑨ spool 写不进去 → 报 queued（不是 watched 成功）/ 不许报监视通道成功
      / 不假称「目标有草稿」/ 不承诺清空草稿就送达 / 零按键 / 零 forced / 条目留下可重试
      / durable 收件箱行先落盘（部分持久化边界，如实存在）
✓ 12b-pi ⑨b 路由选中后消失 → queued（不是 watched）/ 不报监视成功 / 零按键、零 forced、条目留下
✓ 12b-pi ⑨c 初次入队失败：非零退出 / 不声称已排队 / 不冒充离线收件箱成功 / 点名写不进 / 零按键零 forced 零条目
```

离线/缺窗口/死 pane/空 shell/未知收件人/`--any`/跨会话/dispatch 死 pane 与「其他发送方草稿保护 + 显式 Outbox override + 终态不重贴」都跑在闭包里原有的段（7、11g、12b、12b-h0*、42、43、44、45、46、47、57 等）并全绿；delivery-truth 的 drafts/queue/receipts/notify/panel/judge 八段用受保护条目继续钉住几何、竞态、held、终态和恢复。

### 变异（红/复原绿，逐条证明变异真的落地）

在 scratch 副本里（产品树不改写），smoke 12b-pi ⑩：

```text
✓ 变异 A 真的落地（default_direct=0 在副本里）
✓ 变异 A → 红：脏框默认 say 退回排队（默认直投消失）        [实际 queued]
✓ 变异 A 复原 → 绿：同一夹具直投                            [实际 direct]
✓ 变异 B 真的落地（直投判断不再看 watch_route）
✓ 变异 B → 红：活 watcher 也被强制直投（force 抢到 watch 前面）[实际 forced]
✓ 变异 B 复原 → 绿：watch 优先、零按键                        [实际 watched]
✓ 变异 C 真的落地（--now 回到 say parser）
✓ 变异 C → 红：退休的 --now 又被接受（两个位置）              [实际 accepted(0/0)]
✓ 变异 C 复原 → 绿：两个位置都以 2 拒绝                       [实际 rejected]
```

`delivery-truth --mutations` 的静默报告变异仍在并已改指受保护发送方：`红侧（静默排队）：可见报告 → 红（判据钉住的正是这个决策点）`，同时 `红侧对照：静默变异下仍零按键 / 消息仍在队列`、`生产 cmd-draft.sh 的 sha 不变` 全绿。旧几何/竞态/终态变异保留在各自段里并全绿。

### 真实 Pi / 模型 / tmux（版本分离，单次运行证据）

判据版本 `0.99.2`（从 `dev3/P380-dev3/.runtime/0.99.2` 只读复制，容器 `--network=none`、回环 mock provider、私有 tmux、无凭据挂载）。候选冻结在 `70a4dc22`；其后提交只动测试/判据/映射表/报告，产品代码未再变。证据目录 `~/.cache/p393-evidence`，每次运行都由 `run-case.sh` 重置现场并写 `run.json` 单次运行戳。

```text
tmux-p163-base-default-dirty:      requests_matching_draft_and_correction=0 queued=1 held=0 forced=0
  PASS dirty A/B …: queued (no model request)
tmux-p163-base-now-dirty:          requests_matching_draft_and_correction=1 queued=0 held=0 forced=1
  PASS dirty A/B …: direct (draft+correction in one request)
tmux-p163-candidate-default-dirty: requests_matching_draft_and_correction=1 queued=0 held=0 forced=1
  PASS dirty A/B …: direct (draft+correction in one request)
```

三条现场的真实请求正文（同一条 mock 请求里的 user 内容，基线 `--now` 与候选默认逐字相同）：

```text
base-now:      "P163-HUMAN-DRAFTP138-SAY-tmux-p163-base-now-dirty"
candidate:     "P163-HUMAN-DRAFTP138-SAY-tmux-p163-candidate-default-dirty"
```

草稿证据：三例 `draft_before_send_sha=672042e21d0f7958634d53af25ebb72db50b173b30af6504a34cca4668762961`、`draft_text=[P163-HUMAN-DRAFT]`、`draft_cursor_row=28`，`draft-typed-before.frame` 里能看到这行草稿；forced 审计一律一行 `… kind=say from=pm target=p138:dev entry=none`。基线的 `say.txt` 是旧的 `--now` 措辞，候选是 `attempted immediate send …（已尝试立即发送；未确认模型接收…）`，两者都不出现「已确认送达」。

第二封修正（0.99.2，`P138_SECOND=1`）：`judge-second.py` → `second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1` / `PASS second say delivered`；后续 flush 没有让任何一次直投重复。

当前宿主 Pi `1.4.0` 只作观察（`run.json.mode=observation`）：同一脏框模式下真实请求同样是 `"P163-HUMAN-DRAFTP138-SAY-tmux-p163-host-observ-dirty"`，`pi-version.txt=1.4.0`，审计一行；`judge-dirty-ab.py` 与 `judge-second.py` **都拒绝**出判据：

```text
judge:dirty-ab:host(expected-2)=2
judge-second: 拒绝出判据（…host-observ-dirty）：run.json.mode='observation' 是人工观察（host 路线），不作为判据
```

watcher 的真实运行（0.99.2，clean 与真草稿两例）：`say.txt` 是 `✓ outbox：已投递（pi 监视通道）…（输入框零按键）`，`forced_lines=0`、`wake_lines=1`、收件箱 `dev.md` 恰好 1 行、最终模型请求里出现 payload 各 1 次；脏例的草稿在 `dev-after-say.frame` 里仍然在（1 处）。

## 边界与未做

- **没有跑全量门禁**：跑的是实际变更路径闭包（85 键，正片 65 分钟）+ 最低相关闭包去重 + delivery-truth。全量套件与合并门禁仍是 PM 的（本任务不替代）。
- **证据目录不是 `/var/tmp`**：宿主机 `podman` 看不到 distrobox 的 `/var/tmp`（实测 `statfs /var/tmp/…: no such file or directory`），所以证据放宿主机可见的 `~/.cache/p393-evidence`；容器 scratch/HOME/history 已按设计改到 bind mount 的 `/evidence/tmp`（磁盘、跑完宿主机可读），不再只活在容器内 `/tmp`。
- **闭包时点**：闭包跑在 `469ed8db`，最终树只多 `de01d811` 的 12b 断言改动，该族已在最终树重跑绿；其余段无改动。
- **直投传输失败仍是 best-effort**：payload/Enter 失败只保证措辞诚实（尝试、不假装回执、不承诺自动入队），不新增重试/恢复框架；快照等待与可能的第二次 Enter 原样保留。
- **监视通道的部分持久化没有 exactly-once 承诺**：收件箱行可能先落盘再遇 spool 写失败（smoke ⑨ 明确断言这一现象），本次只做到「留条目、零按键、措辞不越界」。
- **`--watch-only` 是私有的单次参数**，不写队列头、不新增持久化意图；普通后续排水（含 `flush --now`）行为不变。
- P391 排序：`SKILL.md` 只改了三处短句（Collaborate 行、Draft/deferred delivery 行、review-fail 一行的括号），没有新增长指令；P391 重写 `SKILL.md` 时按 PM 的串行安排把这句规则合并进瘦身后的版本，详细解释留在 `references/`。
- 本仓为 local 模式：**未 push、未合并、未归档、未发活团队消息**，分支 `task/P393-team-say` 留在本地等 PM 独立复验。

## 任务勾选

`tasks.md` 1.1–6.4 全部勾选，逐条证据见上（6.4 即本报告）。独立验证与真实归档未做、也未声称完成，留给非作者的 verifier 与 PM。

## V116-R1 · 真实 `set -e` 入口的持久化诊断（2026-10-29）

### 结论与候选

R1 已修复，等待另一位 verifier 定点关闭。**产品/测试候选 tip `5e0d4186f2425986aaec8e1d543f2230ac91ad0e`**，基于原交付 `e67246871e0d`；本节随后的提交只更新本报告，不改被测源码。V116（报告 `6203ecf41514`）对原行为矩阵的 PASS 仍是未改行为的独立证据，本节不是自签独立 Verify。

本轮只改两个文件（7 insertions、2 deletions）：

- `scripts/lib/cmd-agents.sh`：显式捕获 `team_send_guarded` 的状态。只有 `persist-failed` 的非零结果继续到已有专用报告分支；其余非零结果原码返回，不能落进离线成功兜底。没有改 sender/outbox 的投递、重试、路由、审计或队列实现。
- `tests/smoke.sh`：⑨c 的 shell 从 `set -u` 改为真实入口使用的 `set -euo pipefail`。复用同一持久化断言，没有增加 smoke 段或 guard 框架。

### 基线反例、真实 CLI 与返回值边界

完整证据放在宿主磁盘 `$HOME/.cache/P393-R1/`（下称 `E`）。`probe.sh`、`run-focused.sh`、各臂源码/fixture/日志、变异 diff 与 SHA 均在该目录；容器 `--network=none`，不挂凭据，使用隔离项目、测试名册、私有 HOME 与 tmux 记录器，不对活团队发 say。

首先对原 `e6724687` 的 scripts 只读副本运行 `probe.sh baseline`，随后同一脚本运行 fixed/mutant/restored：

```bash
distrobox-host-exec podman run --rm --network=none --userns=keep-id \
  -e HOME=/evidence/home -e TMPDIR=/evidence/tmp \
  -v "$E:/evidence:rw" -w /evidence localhost/teamsmith-gate:local \
  bash -lc 'bash /evidence/probe.sh baseline /evidence/baseline/skills/teamsmith'
# 后三臂在同样容器中依次执行：
bash /evidence/probe.sh fixed /evidence/fixed/skills/teamsmith
bash /evidence/probe.sh mutant /evidence/mutant/skills/teamsmith
bash /evidence/probe.sh restored /evidence/restored/skills/teamsmith
```

`probe.sh` 的空 enqueue 影子仅覆盖 `team_outbox_enqueue() { return 0; }`，子 bash 先设置 `set -euo pipefail` 后调用真实 `team_cmd_say`；真实 CLI 臂**不覆盖产品函数**，只把隔离项目的 `.pi/team/state/outbox` 建成普通文件，注册有效 watcher，再运行 `bash "$skill/scripts/team" say dev P393-R1-REAL`。

| 臂 | 脚本 rc | 空 enqueue 影子 | 真实 CLI |
|---|---:|---|---|
| baseline | 1（预期红） | rc=1、输出 0 bytes；缺少「写不进」 | rc=1；点名 outbox 锁失败，未输出 say 级诊断 |
| fixed | 0 | rc=1；出现「写不进」及修复提示 | rc=1；保留原锁失败，并新增 say 级诊断 |
| mutant（恢复裸调用） | 1（预期红） | rc=1、输出 0 bytes；同一诊断断言红 | rc=1；仍有底层锁失败 |
| restored | 0 | rc=1；诊断复绿 | rc=1；两级诊断均在 |

fixed 的真实 CLI 原始输出（路径使用容器内的测试根）：

```text
mkdir: cannot create directory ‘/evidence/fixed/fixture/.pi/team/state/outbox’: File exists
mkdir: cannot create directory ‘/evidence/fixed/fixture/.pi/team/state/outbox’: File exists
✗ outbox enqueue：拿不到队列锁（/evidence/fixed/fixture/.pi/team/state/outbox/.lock）
✗ say: 写不进 state/outbox/ 的队列条目（目标 p393-r1-isolated:dev）—— 没有按任何键，也没有离线/排队兜底
  检查 /evidence/fixed/fixture/.pi/team/state/outbox 的权限与磁盘后重发；已选中的监视通道不会退回直投
```

所有臂均断言：真实 CLI 非零、点名底层锁错误及实际 outbox 路径、无 queued/offline/确认送达声明、tmux 调用记录为空、无 durable inbox/spool/forced/队列条目；普通 outbox 文件前后 SHA 相同。`fixed.log` 与 `restored.log` 另外覆盖 `held`、`unknown-failed`、`offline`、未识别结果以及 `forced/watched/queued/offline-handled` 的非零影子：每种都注入 rc=23，实际仍 rc=23、无新增成功/离线输出，证明只放行 persistence reporter，未把其他失败改成成功。

### 实际 smoke 的变异红与还原绿

在冻结候选的独立本地克隆 `E/candidate` 运行；所有日志完整写入宿主 `E/*.log`，不是只留 tail。`E/scratch` bind mount 为容器 `/var/tmp`，`HOME=/var/tmp/home`、`TMPDIR=/var/tmp/tmp`，test scratch/history 与 `--keep` 现场都可从宿主读取。

```bash
bash "$HOME/.cache/P393-R1/run-focused.sh"
# 脚本通过以下隔离入口运行；完整命令与顺序保存在该脚本：
distrobox-host-exec podman run --rm --network=none --userns=keep-id \
  -e HOME=/var/tmp/home -e TMPDIR=/var/tmp/tmp \
  -v "$E:/evidence:rw" -v "$E/scratch:/var/tmp:rw" \
  -v "$E/candidate:/work:rw" -w /work localhost/teamsmith-gate:local bash -lc '…'
# mutation（只在 scratch 克隆恢复 sender 裸调用）
env -u TEAM_SMOKE_FAST bash skills/teamsmith/tests/smoke.sh --keep --select 12b-pi
# 上一运行退出后恢复文件，git diff --exit-code 无输出，再运行候选：
env -u TEAM_SMOKE_FAST bash skills/teamsmith/tests/smoke.sh --keep --select 12b,12b-pi,12b-pi2,12b-pi3
```

实际结果：

```text
mutation landed: exact bare team_send_guarded call, captured-return block removed
smoke-mutant rc=1
12b-pi ⑨c 初次入队失败：点名持久化失败（[] 里找不到 [写不进]） → 唯一红
== 选段结果 == ✓ 520 ✗ 1
smoke-restored rc=0
12b-pi ⑨c 非零退出 / 不声称已排队 / 不冒充离线收件箱成功 / 点名持久化失败 / 零按键零 forced 零条目 → 全绿
== 选段结果 == ✓ 603 ✗ 0
```

变异已落地的证据是 `smoke-mutation.diff`（删除返回值捕获块、恢复准确的旧裸调用）与 `smoke-mutation-sha.txt`；还原后的 `git diff --exit-code` 为空，SHA 见 `smoke-restored-sha.txt`。两个 fingerprint 都是 `verdict: same`：变异运行 dirty=1 始终不变；还原运行 HEAD=`5e0d4186`、dirty=0 始终不变，没有运行中写树/提交。

实际运行 14/135 键，非 FAST、无段级跳过：`0,0b,0c,0d,2,4,5,3b,6,6i,12b,12b-pi,12b-pi2,12b-pi3`。其中 `12b` 102、`12b-pi` 149、`12b-pi2` 28、`12b-pi3` 54 条全绿。未跑的 121 键原样记录于 `smoke-restored.log` 首尾（含 `12b-h0*`、其他 sender 全族、help、delivery-truth 和全量门禁），不是本轮新跑的证据。本轮按 R1 明示范围只跑定点族，不重跑原 85 键闭包、真实 Pi A/B、全套或 archive；这些边界仍以前文及 V116 独立证据为准。

### 静态、环境与交接

同一容器 login bash 的实测解析：`openspec=/usr/local/bin/openspec` 1.8.0、`pi=/usr/local/bin/pi` 0.86.0、Node v24.22.1。这里 Pi 只供已有 smoke 解析/夹具使用，**不是**新一轮 0.99.2/1.4.0 真实模型请求判据；未混用或重记此前 A/B 成绩。

冻结候选上的精确命令与输出（全部 rc=0，完整输出分别保存在 E 对应日志）：

```text
openspec validate say-immediate-default --strict
  Change 'say-immediate-default' is valid
openspec validate --all --strict
  Totals: 20 passed, 0 failed (20 items)
bash skills/teamsmith/tests/spec-refs.sh --check
  retired 1; undeclared 0
bash skills/teamsmith/tests/section-select.sh --check
  ok 12 bad 0 SKIP 1
  （唯一跳过：internal 检出无机器生成面 .pi/skills；没有算成已检查）
bash skills/teamsmith/tests/ledger-ban.sh --names-file /evidence/project-names.txt
  files=2251 hits=0 names=ok
bash -n skills/teamsmith/scripts/lib/cmd-agents.sh skills/teamsmith/tests/smoke.sh
  无输出
git diff --check e67246871e0d HEAD
  无输出
git status --porcelain
  无输出
```

`project-names.txt` 是任务要求的 `$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt` 原样副本，运行前 `cmp` 与 SHA 证明相同（`freeze-receipt.txt`）；名单内容未打印。后台作业 `p393-r1-focused` exit=0，已收割。补齐本节后，在作者 worktree 的 login bash 再跑上述两个 OpenSpec validate、spec-refs、section-select、原路径名单的 ledger-ban 与 `git diff --check`，日志为 `author-final-static.log`。P391 排序不变，本轮没有碰 SKILL.md、spec/tasks、其他任务或团队 live state；没有 push、merge、归档、发布，也没有运行活团队 say。下一步由 PM 指派非作者对 `5e0d4186` 的 R1 诊断路径做聚焦终验，之后才可决定合并。
