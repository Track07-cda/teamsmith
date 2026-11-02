# P396 · PM 标记式关键回复实施

**结论**：任务 1.2–2.3 已实现并自测通过（parser 114 项、私有真 Pi 23 个用例、原 writer 与既有 reader 选段各 85/86 项全绿，具名产品变异 11 条红侧 + 还原绿）。任务 3.1–3.3（三处指引面迁移与旧 guide 双写断言替换）**未做**，因为硬依赖 P393 的产品提交尚未进 main——本分支 `git merge-base --is-ancestor bf8e5ec0 main` 返回 1，main 上只有 `795c91bb` 这条 ACCEPT 账本，`main:skills/teamsmith/SKILL.md` 仍是 P393 之前的一行 say 文本。按要求 STOP 在 `BLOCKED:` 上，不重建也不夹带 P393 的 say diff。独立验证、真实采用（重启/reload）与归档均未做。

## 提交

| commit | 内容 |
|---|---|
| `546cab59` | 窄 parser 与原 offset 清理（`scripts/reply-capture.mjs`），`scripts/replies.mjs` 只多导出纯校验 |
| `faf6f239` | 来源事务：end→turn_end 绑定→settled 资格→attempting CAS→原 `team reply post` |
| `7e9a9861` | PM 定向注入、真实身份/运行证据、依赖指纹与 doctor |
| 本次提交 | tasks.md 1.4–2.3 勾选 + 本报告 |

改动面 `git diff --stat 0e557f47..HEAD`：13 个文件、+1859/−13，全部在 brief 的 write set 内（product 4 个、tests 5 个、tasks/report）。

## 已实现行为

- **parser**：只删识别的**完整**控制行及其自身换行；围栏（≤3 空格、≥3 同种 tick、closer 不短于 opener、backtick opener 的 info string 不含 backtick）与**精确等长**配对 inline span 先保护，跨行/跨 text block 成立；未配对 opener 不外溢；块外反斜线奇偶只转义紧随的第一个 tick，未转义后缀仍可开启 span；块内反斜线是普通内容。删除投回原 offset，保留 CRLF、尾随空行、空 block、非 text 字段与字节顺序。标题省略时跳过 Magic Context `§N§` 且安全截 160 码点，正文不受影响。
- **来源状态机**：message_end 只做 staging（unbound），`turn_end` 拿到真实 `messageEntryId` 且与 branch/entry message 三方一致才 pending，`agent_settled` 未中止且最新成功 assistant 才 eligible；source tuple 固定为 `(root, state, sessionId, sessionFile, entryId)`，不含 body hash/leaf/时间。attempting 在 spawn 前耐久落盘（CAS），因此崩溃点右移也不会二次执行；saved 保留真编号、unconfirmed 只留 candidate_no，busy/input/坏回执/信号/结果落盘失败一律不自动重发；超出最新页的旧 saved 仍是屏障。
- **PM 定向加载与证据**：内置 PM 启动只多一个 `-e extension/team-reply.ts`（bg/inbox-watch/模型/continuity 不变），并把本次已解析的 `TEAM_STATE_DIR/TEAM_CONFIG_FILE/TEAM_PM_WINDOW` 固定进进程前缀；扩展核主检出、canonical config/state、真实 tmux socket/server/pane/session/window/cwd、PID+starttime、spawn 或 final proof，任何一项不成立就只报本地诊断、不动答复也不注册 ready。依赖（`reply-capture.mjs`/`replies.mjs`）每次装载都重新求值，fingerprint 记的是**实际执行的字节**；doctor 分三行显示磁盘源码、启动注入、live 运行（disk/loaded/generation），只读不修。`team_skill_hash` 已覆盖这两个已加载依赖。

## 证据（本席位实跑，日志在 `$HOME/.cache/P396/author-slice2/`）

```text
$ bash skills/teamsmith/tests/key-replies.sh --select capture
PASS mutation inline-protection: named assertion red (paired inline spans)
PASS mutation source-cas: named assertion red (CAS stale discoveries)
PASS mutation durable-attempt: named assertion red (external process death after-attempting)
PASS mutation current-branch: named assertion red (new activity prevents recovery)
PASS mutation restoration: parser green / source green
reply-capture: passed=114 failed=0
PASS real Pi {print,tui,length,error,aborted,partial,queued,continued,tool,retry,overallabort}
PASS real Pi staging journal fault preserves real Pi stdout/transcript
PASS real Pi owner mutation named red and restoration green in private Pi
PASS real Pi loaded dependency reload evaluates new code; tree/fork/new/switch do not import
PASS real Pi reload cannot invent a never-injected entry
PASS real Pi {foreign,worker,ordinary,custom,inherited,config-link} context cannot clean/publish/register
PASS real Pi two loaded paths share one owner and generation
PASS real Pi live registration distinct from disk, dead/reused process and readonly doctor
  ✓ capture：parser/source 具名行为与红绿变异
  ✓ capture：私有真 Pi 终稿、来源、定向身份与依赖 reload
== P234 key-replies 结果 == ✓3 ✗0 SKIP0
```

23 个真 Pi 用例里凡有资格的都核了同一批事实：最终 transcript 无完整控制行、`print` stdout 与该消息逐字节相等、下一次 provider 请求里的 assistant 历史同样干净、store 正文与原 offset 结果一致；interactive 用例的 raw PTY **确实出现**了本例标记（阳性），最终画面已清理——只说明这一例如此，不声称零闪现、固定时限或真实模型遵从。

依赖 reload 的关键数：装载时 fingerprint `cc36d5044c92`（generation `947d3706`），只改 `reply-capture.mjs` 后 doctor/`inspectRuntime` 判 `stale` 但 loaded 仍是旧值；`/reload` 后 generation `520e0c7a`、fingerprint `ea42684f0946`，且下一条答案的标题来自**替换后的代码**（`dependency-loaded-v2`），`team_skill_hash` 也从 `93c95dd72726` 变到 `d36603538efc`。tree/fork/new/switch 后已落盘来源不重发，fork 复制来的 entry 不导入。

写在其前一轮的两段（同一 worktree、同一分支）：

```text
$ bash skills/teamsmith/tests/key-replies.sh --select input,original,concurrency,receipts,interrupt
== P234 key-replies 结果 == ✓85 ✗0 SKIP0
$ bash skills/teamsmith/tests/key-replies.sh --select workflow,guide,paths,readonly,paging
== P234 key-replies 结果 == ✓86 ✗0 SKIP0
```

失败与修正（都记在这里，免得复验者重踩）：真 Pi 生命周期用例第一次红是**夹具**问题——交互用例把终端重定向进了文件，自定义模板又重复写了 `exec`；第二次红是夹具在 writer 已 commit、回执尚未写回 journal 的窗口里读 store 计数，改成等真实 `saved` 记录后通过，产品未为此加任何等待或测试开关。retry 用例最初断言 `agent_end.willRetry`，但 Pi 的事件里该字段为 undefined，改判「确有 error 终态 message 且随后有第三次真实请求」；owner 变异用例最初只读 stdout，而 FAIL 行走 stderr，改合并输出后才真正红/绿。

## 交付门禁

```text
$ ~/.bun/bin/openspec validate pi-marker-key-replies --strict
Change 'pi-marker-key-replies' is valid
$ ~/.bun/bin/openspec validate --all --strict
Totals: 20 passed, 0 failed (20 items)
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 121 reference(s) (49 distinct) ... retired 0; undeclared 0            (rc=0)
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1        # SKIP：行 19 的 `.pi/skills` 字面模式在 internal 形状检出里不存在
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file .../forbidden-names.txt
ledger-ban: ... files=2258 hits=0 names=ok user=resolved
$ git diff --check
# 无输出，rc=0
```

`openspec` 不在非登录 shell 的 PATH 上，上面的命令用绝对路径 `~/.bun/bin/openspec` 跑（登录 shell 里同样不在 PATH，所以这里不给裸名字）。

完整 `bash skills/teamsmith/tests/smoke.sh` 已在冻结树上跑过，但整轮在 06:52:43Z 被 PM 以 TERM 停止、未产出结果，因此**本报告不提供全量门禁绿**；现场与失败/事故身份见下文「全量门禁」与「06:51:08Z 主检出被改写」两节。

## 边界与未做

- **3.1–3.3 已解除并完成**（原 BLOCKED 记录保留在下方历史里）：P393 产品提交已进 main 并合入本分支（`25c934a0`），指令迁移与门禁替换见文末「指令迁移补充（2026-11-02）」；P391 仍是后续集成任务。
- 未做：独立验证（4.1，必须是另一个 agent）、真实团队 restart/reload（4.2）、归档与 canonical Purpose 编辑（4.3）、任何 push/merge/CI 重试/发布。
- 已知限制：身份证据是同 UID 本地证据，不是抵抗同 UID 伪造者的认证；`runtime.json` 只在生命周期节点更新，没有 heartbeat，所以「上次 ready、进程已死」由 doctor 现场核 PID/starttime/pane 判 stale，而不是靠心跳超时。
- 自定义 PM 模板（`TEAM_PM_CMD`）不注入捕获，首版不承诺兼容——这是为阻止测试放宽产品身份而保留的边界，不是缺陷。
- `key-replies.sh` 新增的 `capture` 组会在缺 node/tmux/pi 时**可见 SKIP 点名缺什么**，其余组照跑；不静默当通过。

## 整轮门禁：被打断，没有全量 PASS（已完成的段落仍可核验）

冻结树（HEAD `338a9f85`）上跑过一次完整 `bash skills/teamsmith/tests/smoke.sh`，日志 `$HOME/.cache/P396/full-gate/smoke.log`（去色副本 `/var/tmp/p396-smoke-clean.log`）。它在 **2026-10-30T06:52:43Z 被 PM 以 TERM 停止**（`team bg list`：`P396-full-smoke pid=4140082 identity=gone`；`.pi/team/state/bg.log:5855`：`stop ... signal=TERM ... by=552734`），停止时正跑段 `#129 62`，因此**没有全量 PASS，也不能当成本候选的最终全量验收**；按 PM 指示不再重跑。

**已完成的段落（#1–#128，含 61）依然是可核验的观察**，不是一律作废：日志里累计 `✓ 5057`、`✗ 2`、`SKIP 16`（SKIP 都是既有的条件不满足型）。段 `#128 61b · 任务类别模型路由：翻转变异自检` 正常跑完，收尾行是 `✓ 61b 路由翻转变异：31 条臂按名变红并还原（RESULT pass=203 fail=0 selected=flip）`，该段用时 `5724s`（≈95.4 min，取段尾 `参考 用时 5724s · ✓1 ✗0`）；中途 messenger 里出现过的 ~74 min 只是**运行中的一次采样**，不是完成耗时。这个 95.4 min 可给 P397 做成本参考，**不是**本候选的验收结论。

**那 2 个红项的身份与去向**：

1. `#28 6i` 的 `✗ M8.1 默认渲染与历史逐字节一致` —— **由 P396 自己的注入引起**：夹具里那条“历史默认渲染”是字面写死的参考串，本改动新增了 `-e <skill>/extension/team-reply.ts` 与 `export TEAM_STATE_DIR=… TEAM_CONFIG_FILE=… TEAM_PM_WINDOW=pm;` 前缀，参考串没跟上。已在本分支修正（`tests/smoke.sh`：注释说明 P396 段、新增 `P396_REF_PREFIX`、参考串补 `-e team-reply.ts`、加一条 `assert_has_echo … extension/team-reply.ts`），并只重跑了这一段：`bash skills/teamsmith/tests/smoke.sh --select 6i` → `#10 6i … ✓126 ✗0`，跑前后 `git status` 逐字节相同（`$HOME/.cache/P396/section-6i/smoke2.log`）。
2. `#102 38` 的 `✗ 38-i panel-b3.sh 收前后窗口数不变（一个后端、一个窗口）（期望 [3]，实际 [2]）` —— **与 P396 无关，main 上已有**：这台机器上单跑 `bash skills/teamsmith/tests/panel-b3.sh` 复现（`✓230 ✗1`，`$HOME/.cache/P396/panel-b3.log`），在 main（`4dfcceb3`）的干净克隆里跑同一脚本也复现（`✓230 ✗1`，`$HOME/.cache/P396/panel-b3-main.log`）。机制就写在夹具自己的注释里：`wins_before` 必须在 `pulse up` 的 `cmd` 辅助窗口（命令末尾带 `sleep 1`）退掉之后才采，负载下控制台先到、`cmd` 还活着 → 采到 3，随后变 2。本席位没有改 panel 夹具与 panel 代码（`git diff main -- scripts/panel tests/panel-b3.sh` 为空），怎么处置（调时序还是删这条）留给 PM。

独立的选段运行不受影响，见上文：capture 组 3/3（parser 114、真 Pi 23）、原 writer 85、既有 reader 86。**最终全量验收仍未完成**，由后续独立复验或合入批次承担。

## 06:51:08Z 主检出被改写：来源已确认，不再归因

**结论**：来源已由用户确认——**用户本人手动执行了一次 `team init`**。归因调查到此为止，本报告不再保留此前的推断链；该次 init 的结果**不回滚**（现场保持原样），本席位也未做任何恢复动作。

**影响面（当时实测，留档用）**：06:51:08.877–.973 的 100 ms 内 17 个条目——`AGENTS.md`（teamsmith managed 段被模板重渲染）、`.gitignore`（`+.pi/extensions/`、`+<home>/.gitlab-pa-token`）、`docs/team/PROTOCOL.md`、`docs/team/{reports/.gitkeep,inbox/.gitignore,reviews/.gitignore,reviews/.gitkeep}`、`.pi/skills/{teamsmith,teamsmith-init,handover}`（0.3.4 副本，不含 P396 内容）、`.pi/extensions/team.ts`。未触及 `.pi/team/config.sh`、`.pi/team/state/**`、各 `.worktrees/`、编号回复存储、tmux 会话环境、`docs/team/BOARD.md`。原始 `find`/`git status` 输出在 `$HOME/.cache/P396/incident-0651/probe29.txt`。

**两条留档观察**（按 PM 裁定记录，不展开成改造建议）：`.gitignore:39` 落了绝对路径 `<home>/.gitlab-pa-token`（`cmd-project.sh:290` 把配置过的 `TEAM_GITLAB_TOKEN_FILE` 原样当条目；默认值 `.gitlab-pat` 不受影响）；managed 段整体替换是现有契约 / P389 已知迁移风险，不计为本轮新增缺陷。

**与本任务的关系**：这次 init 与 P396 的实现无关，也不是夹具逃逸；它发生在本席位整轮门禁运行期间，而那轮已在 06:52:43Z 被 PM 用 TERM 停止、未产出结果，故本轮仍按“无效”处理。`.pi/skills` 与 `.pi/extensions` 里的 0.3.4 副本现留在 main，处置由 PM/用户决定。

**保全**：未还原、未清理、未重启、未再跑全量。`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.{kPacjX,YhbH3y}`、`$HOME/.cache/P396/full-gate/`、`$HOME/.cache/P396/incident-0651/`（含 `state.txt` 与 `probe1..28.txt` 逐条原始输出）原样保留。

## 指令迁移补充（2026-11-02，P393 落地后的追加切片）

**结论**：三处指令面（注入的 PM 提示词模板、`references/protocol.md` §4b、`SKILL.md` 命令表与非协商规则）已从"先 `team reply post`、再在会话重复同一正文"换成**正常回答 + 末尾 `[[team-reply]]` 控制行、由定向 PM 扩展发布**；`team reply post --from … --stdin` 在三处都只写成 manual/backfill/recovery 入口。门禁的旧 guide 双写判据被替换为标记行为判据：旧默认回插会红并点名那个面，标记示例被改坏会被产品 parser 以 `invalid-title` 拒认，三面带标记约定时绿。P393 的 say 指令未被覆盖。

### 提交与改动面

| commit | 内容 |
|---|---|
| `a40452cc` | 三处指令面：默认标记式回答、读者判据保留、CLI 只作人工入口 |
| `5b588be9` | `key-replies.sh` guide 组换成标记行为 + 旧默认红侧；`reply-capture.mjs` 新增 `example` 组（产品 parser + 真 writer） |
| 本次提交 | tasks.md 3.1–3.3 勾选 + 本补充节 |

`git diff --stat 25c934a0..HEAD` 只有 5 个文件：3 个指令面、2 个测试文件（+ 本报告与 tasks.md），无产品代码改动。

### 三处表面改了什么

- **模板**：`Key conclusions` 段改为"把完整回答写成普通答复，最后一行是捕获标记"，示例如下（受 fenced 代码保护，因此不会被当成控制行）：

  ```text
  The migration is merged; the two follow-ups are listed below.
  [[team-reply]]
  ```

  同段保留读者判据（`written for the user`）、"一批用户回复可合成一条"、失败不挡答复、`team reply post` 只作 manual/backfill/recovery；不再出现临时文件/heredoc 或"post 后重复正文"。
- **协议 §4b**：标题从"publish the body before you answer"改为"mark the answer and the extension publishes it"；补齐标记语法（裸标记/显式标题、大小写、列零、末行、代码保护、多行 ambiguous/非末行 misplaced）、净化正文=原回答减去控制行、流式可见性边界、至多一次自动尝试、CLI 人工入口、receipt 与存储语义，以及诚实上限（门禁只判"义务已装载 + 示例可发布"，不判真模型遵从）。
- **SKILL.md**：`| Key replies |` 行与"Non-negotiable rules"里的对应条目同步改为标记式；`say`/`notify` 的措辞（P393）逐字未动（`git diff main -- SKILL.md | grep say/notify` 只命中被改的 Key replies 行本身）。

### 门禁：能变红、也能变绿（本席位实跑，日志 `/var/tmp/p396-instr/`）

`guide` 组现在断言三件事，并各自有红侧：

```text
== guide · 三处表面的标记纪律 + 旧默认红侧 + 示例对拍 + 变异（change: pi-marker-key-replies · P396） ==
  ✓ guide-surfaces：prompt template 带着全部语义锚点（…written for the user、[[team-reply]]、[[team-reply:、team reply post、--stdin、manual…）
  ✓ guide-surfaces：protocol reference 带着全部语义锚点（…同上 + No tool can verify…）
  ✓ guide-surfaces：command table 带着全部语义锚点（…row:[[team-reply]]、row:team reply post、row:--stdin、row:manual…）
  ✓ guide-default：三面都没有恢复「先 post 再重复正文」的旧默认（CLI 只作 manual/backfill/recovery）
  ✓ guide-marker：印出来的标记示例被产品 parser 认成候选并由真 writer 保存一次（PASS shipped marker example: product parser candidate, one real writer save, raw body equals the answer minus the control line）
  ✓ guide-example：example command 被真解析器接受（rc=0，team reply post --from pm --title '<short title>' --stdin）／回执 saved／槽位 0 → 1
  ✓ guide-example：控制臂（同一 argv + 未知旗标）被真解析器拒绝（rc=2，未知参数）/ 没有新槽位
== P234 key-replies 结果 == ✓34 ✗0 SKIP0
```

七条变异逐条红并点名被改的面，重新从真树复制后绿（节选首行；完整行见日志）：

```text
✓ guide-flip/①：✗ guide-surfaces：prompt template 丢了纪律判据： [ruling] [ask the user] [written for the user] [[[team-reply]]] [team reply post] [--stdin] [manual]
✓ guide-flip/②：✗ guide-surfaces：protocol reference 丢了纪律判据： [ruling] [ask the user] [written for the user]
✓ guide-flip/③：✗ guide-surfaces：command table 丢了纪律判据： [conclusion]（Key replies 行内）… [row:[[team-reply]]]…
✓ guide-flip/④：✗ guide-default：prompt template 又出现了「先 post 再回复」的旧默认（[then send that same body]）
✓ guide-flip/⑤：✗ guide-marker：… FAIL example: … not a publishable candidate (invalid-title)
✓ guide-flip/⑥：✗ guide-surfaces：prompt template 丢了纪律判据： [[[team-reply]]] [[[team-reply:]
✓ guide-flip/⑦：✗ guide-example：example command 被真解析器拒绝（rc=2，输出 [reply: 未知参数 --stdinX]）
```

被替换的旧断言与保留覆盖：旧 `guide-flip` 五条（锚点删除/命令表替换/`--stdinX`）保留语义重写为 ①②③⑦；新增 ④（旧默认回插）、⑤（标记示例改坏）、⑥（模板标记约定抹除）；旧 `guide-example` 对"模板唯一 `team reply post` + 真解析器 + unknown-flag 控制臂"的检查保留，只去掉"印刷示例必须带 `< <file>`"这一条（临时文件重定向已不是默认工作流，测试侧仍用 stdin 喂正文）。`input` 组"手工相同输入发布两条"与 `capture` 组的真 Pi/parser 入口未动。

### 既有 reply 入口触及组（3.3）

```text
bash skills/teamsmith/tests/key-replies.sh --all                            → ✓215 ✗0 SKIP0（804.8s，section 62 用的同一入口；起跑树 5feae965、收尾 96981178，两树只差本报告一段）
bash skills/teamsmith/tests/key-replies.sh --select workflow,guide          → ✓44 ✗0 SKIP0
bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots → ✓72 ✗0 SKIP0
bash skills/teamsmith/tests/key-replies-pty.sh --all                        → ✓88 ✗0 SKIP0
node skills/teamsmith/tests/reply-capture.mjs --all                         → passed=114 failed=0
```

workflow 组里的无副作用断言仍成立：`✓ workflow：saved 不动 BOARD/outbox/inbox/pending/config（BOARD.md sha256 前后相同）`、`✓ workflow：五种结果后账本仍不变`、`✓ workflow：published 总数=2（saved+unconfirmed）`；pty 组末行 `✓ 隔离守卫：真实仓库 …/.worktrees/dev 的 inbox/state 前后逐字节不变`。真树在四个组跑前后只有本报告/tasks.md 的预期改动（`git status --short` 只列 `M openspec/changes/pi-marker-key-replies/tasks.md`，报告写入后同）。

### 收口门禁

```text
$ node /var/tmp/p396-openspec/node_modules/@fission-ai/openspec/bin/openspec.js --version
1.8.0
$ … validate pi-marker-key-replies --strict   →  Change 'pi-marker-key-replies' is valid（rc=0）
$ … validate --all --strict                   →  Totals: 21 passed, 0 failed (21 items)（rc=0）
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) … retired 1; undeclared 0  (rc=0)
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1        # 修复前：bad 1 —— 段 6i 读了未声明的 skills/teamsmith/extension/team-reply.ts
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … files=2284 hits=0 names=ok user=resolved   (rc=0)   # 修复前 hits=2（本报告留档段的家目录绝对路径），已换成 <home> 占位
$ git diff --check                            →  无输出，rc=0
```

`openspec` 用的是 CI 钉住的 **1.8.0**（`ci/Containerfile:116`、`.github/workflows/gates.yml` 同版本），安装在 `/var/tmp/p396-openspec`，因为本机全局 `openspec` 今天 09:59 被升级到 **1.16.0**：该版本把"requirement 超过 500 字符"等 warning 在 `--strict` 下当失败，于是 `--all --strict` 对**所有** canonical spec 都红（本树 `Totals: 1 passed, 20 failed (21 items)`）。在 main 的干净归档副本（`git archive main` → `/var/tmp/p396-main-check`）上用同一 1.16.0 跑，同样是 `19 failed (20 items)`、没有一条是本改动造成的；本改动在 1.8.0 下全绿。这是本机工具版本漂移，不是本候选的缺陷，处置留给 PM/用户。

### 边界（本切片未做）

- **未改产品代码**：解析器/捕获/注入/doctor 仍是先前已验收的实现，本轮只改指令与测试。
- 未做独立验证（4.1 属另一 agent）、真实团队 restart/reload（4.2）、归档与 canonical Purpose 编辑（4.3）、任何 push/merge/发布。
- 按任务书末节要求**未跑全量 smoke**；全量仍在上一轮被 PM 停止、无 PASS 的状态（见上文"整轮门禁"），不在本切片范围内假装补上。
- 真模型是否按标记约定行事仍未验证；门禁只判"义务已装载 + 示例可发布"。
