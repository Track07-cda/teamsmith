# P126 · `team_model_window` 认不出 `:思考档` 后缀（apply）

- **agent**: dev-bob
- **status**: delivered（本地模式：分支留在 `.worktrees/dev-bob`，不 push；PM 复验后本地合并）
- **phase**: apply
- **change**: `-`（`anchor: none (infra)` —— 只改模型窗口解析，不动派单守卫的语义与阈值逻辑）
- **branch**: `task/P126-09-21`（本地任务分支，基点是 `6b3403ba`；local 模式不 push，PM 复验后本地合并）
- **实现提交**: `280dbd96`（`skills/teamsmith/scripts/lib/common.sh`）、`ec15d3b7`（`skills/teamsmith/tests/config-cli.sh`）
- **报告包**: `docs/team/reports/P126-dev-bob/`（`probe.sh` + `logs/` 原始输出逐份落盘）

## 0. 结论

| brief 条目 | 结果 |
|---|---|
| 1. `team_model_window` 支持 `:思考档`：原样优先，匹配不到再去**一个**闭集后缀；不许砍任意 `:` | ✅ `team_model_window_candidates`（唯一一份去后缀口径）给出「原样 → 去一个闭集后缀」候选；`openai-codex/gpt-6-sol` / `:high` / `:xhigh` 同值 272000；`openai/gpt-6-sol-pro:batch` 按原样取自己的 456789（`gpt-6-sol-pro` 是 111111，没被误取） |
| 2. `TEAM_MODEL_WINDOWS` 同一口径、一条实现 | ✅ 两条来源都消费同一候选序列（先原样、后去后缀；`TEAM_MODEL_WINDOWS` 整体仍优先于 Pi 目录）：`x/y=123` + `x/y:high` → 123；显式项 `…:high=888` 赢过 `…=999`；`…gpt-6-sol=999` + `:batch` → 空（非闭集后缀不砍） |
| 3. 双向证据 + 反例 | ✅ 绿侧 18 条断言（含 `ps` 集成 1 条）；红侧 F-W1（任意 `:` 都砍）→ 3 条 `:batch` 反例红；F-W2（完全不去）→ 10 条（`:high`/`:xhigh`/`:max`/覆盖/ps）红；还原 → 绿（§3） |
| 4. `openspec validate --all --strict` + FAST 全绿 + 一次全量 | ✅ validate 14/14；FAST `== 结果 ==  ✓ 3091  ✗ 0`；全量重跑 `== 结果 ==  ✓ 3757  ✗ 0`（§4） |

**判定：交付完成。** 根因（09-21 那次「不得不写 `TEAM_MODEL_WINDOWS` 才派得动」）已消除：
`reply` 的会话体积守卫（`cmd-agents.sh:343`）对带思考档的模型能拿到真实窗口，不再退回 200k 保守阈值。

## 1. 分支与提交

本 worktree 的分支是 `task/P126-09-21`（基点 `6b3403ba` = 派单时的 main tip；local 模式不 push）：
`280dbd96`（实现）→ `ec15d3b7`（夹具）→ `45e3043f`/`4c54e91e`/`0ff208ef`/`abf0f119`/`84598d43`（重构、报告与证据）。
每一步都带 `Agent: dev-bob` trailer。

```console
$ git log --format='%h %s%n%(trailers:key=Agent)' -7
84598d43 docs(P126): correct the branch name in the report and tighten the write-up
Agent: dev-bob
abf0f119 docs(P126): full-gate rerun green (3757/0), section 51 included
Agent: dev-bob
0ff208ef docs(P126): attribute the full gate's single red to routes.sh's cross-run scan (with repro)
Agent: dev-bob
4c54e91e docs(P126): delivery report, reproducible probe and raw evidence logs
Agent: dev-bob
45e3043f refactor(P126): compute the window candidate list once per lookup
Agent: dev-bob
ec15d3b7 test(P126): pin the window resolver's suffix rule with a fixture section and two flips
Agent: dev-bob
280dbd96 fix(P126): resolve model windows through a closed-set thinking-tier retry, never by stripping any colon
Agent: dev-bob
```

## 2. 修法（`skills/teamsmith/scripts/lib/common.sh`）

原实现：`team_model_window` 直接用 `want` 去匹配 `TEAM_MODEL_WINDOWS` 的每项，再交给
`team_model_window_from_pi` —— 带 `:思考档` 的模型在两条来源上都是**原样**查找，于是一律解析不到。

新实现（一处口径，两条来源共用）：

```bash
_TEAM_MODEL_THINKING_TIERS="off minimal low medium high xhigh max"

team_model_window_candidates() { # <provider/model> → 逐行候选（原样优先）
  printf '%s\n' "$want"                       # ① 原样
  case "$want" in *:*) ;; *) return 0 ;; esac
  tier="${want##*:}"
  case " $_TEAM_MODEL_THINKING_TIERS " in
    *" $tier "*) printf '%s\n' "${want%:*}" ;;  # ② 尾段是闭集档位 → 去掉这一个后缀
  esac
}

team_model_window() {
  # 候选序列外层循环：每个候选先过 TEAM_MODEL_WINDOWS 全部条目，再过 Pi 目录
  # （所以显式覆盖赢过目录，且覆盖内部「原样命中的项」也赢过「去后缀才命中的项」）
}
```

**闭集为什么是七个（含 `off`）**：brief 的括注列了六个（`minimal|low|medium|high|xhigh|max`），
但它同时把闭集来源指给 P102 —— P102 的 `design.md:30` 记的是 Pi 自己的
`parseModelPattern`：先原样匹配，再在**最后一个 `:`** 处切，后缀属于
`off|minimal|low|medium|high|xhigh|max` 才算档位；`openspec/specs/delivery-guard` 也把 Pi 的集合写成
这七个。按「P102 定下的那些档」实现 = 七个；夹具对七个逐个断言（含 `:off`）。这一条列在 §5 请 PM 知悉。

**没动的**：`team_model_window_from_pi` 的目录解析、`TEAM_MODEL_WINDOWS` 的语法、派单守卫的阈值
语义、`team_sessions_*`；`team_model_window` 的三个调用方（`cmd-agents.sh:343` 守卫、
`cmd-status.sh:461` 的 WINDOW 列、`common.sh` 的会话列）传参一字未改。

## 3. 证据（原始输出都在 `logs/`）

### 3.1 brief 的四条（直接探针，`logs/probe.log`，可复跑 `bash docs/team/reports/P126-dev-bob/probe.sh`）

夹具（私有临时目录）里 `TEAM_PI_AGENT_DIR` 指向：
`openai-codex/gpt-6-sol`=272000、`openai/gpt-6-sol-pro:batch`=456789、`openai/gpt-6-sol-pro`=111111。

```console
== 闭集档位（应与基名同值 272000）==
team_model_window openai-codex/gpt-6-sol                     → [272000]
team_model_window openai-codex/gpt-6-sol:high                → [272000]
team_model_window openai-codex/gpt-6-sol:xhigh               → [272000]
team_model_window openai-codex/gpt-6-sol:max                 → [272000]

== 真实 id 的其它后缀（原样匹配，不砍、不回落基名）==
team_model_window openai/gpt-6-sol-pro                       → [111111]
team_model_window openai/gpt-6-sol-pro:batch                 → [456789]
team_model_window openai-codex/gpt-6-sol:batch               → []
team_model_window openai/gpt-6-sol-pro:other                 → []

== TEAM_MODEL_WINDOWS 同一口径 ==
team_model_window x/y:high                                   → [123]
team_model_window openai-codex/gpt-6-sol:high                → [999]
team_model_window openai-codex/gpt-6-sol:high                → [888]
team_model_window openai-codex/gpt-6-sol:batch               → []
team_model_window openai-codex/gpt-6-sol:batch               → [777]
```

（重跑同一探针会各带一次 `TEAM_MODEL_WINDOWS=`；完整命令见 `probe.sh`。）

### 3.2 红/绿双向（`logs/model-window-focus.log`）

夹具本体是 `config-cli.sh` 的两个新段：`model-window`（绿侧 18 条）与 `flip-model-window`
（F-W1/F-W2 两个影子变异）。跑法：

```console
$ bash skills/teamsmith/tests/config-cli.sh model-window flip-model-window
...
  ✓ F-W1 绿侧：scratch 树原状 model-window 段绿（rc=0，红不是因为缺文件）
  ✓ F-W1 mutant：闭集判定换成「任意 : 后缀都砍」
  ✓ F-W1 红侧：砍任意 : 后缀后 :batch 反例红（rc=1）
    --- F-W1 红侧尾部 ---
      ✗ 窗口[反例]：openai-codex/gpt-6-sol:batch（基名在目录里）→ 空，不回落基名（期望 []，实际 [272000]）
      ✗ 窗口[反例]：openai/gpt-6-sol-pro:other → 空，不回落基名（期望 []，实际 [111111]）
      ✗ 窗口[覆盖·反例]：'…gpt-6-sol=999' + :batch → 空（非闭集后缀不砍）（期望 []，实际 [999]）
    == 结果 ==  ✓ 15  ✗ 3  SKIP 0
  ✓ F-W2 mutant：只原样匹配（去后缀整个拿掉）
  ✓ F-W2 红侧：不去前缀后 :high 闭集断言红（rc=1）
    --- F-W2 红侧尾部 ---
      ✗ 窗口[闭集]：openai-codex/gpt-6-sol:xhigh → 与基名同值 272000（期望 [272000]，实际 []）
      ✗ 窗口[闭集]：openai-codex/gpt-6-sol:max → 与基名同值 272000（期望 [272000]，实际 []）
      ✗ 窗口[覆盖]：'x/y=123' + x/y:high → 123（期望 [123]，实际 []）
      ✗ 窗口[覆盖·闭集]：'…gpt-6-sol=999' + :xhigh → 999（覆盖赢过目录的 272000）（期望 [999]，实际 []）
      ✗ 窗口[ps 集成]：模型带 :high 时 WINDOW 列 = 272k（期望 [272k]，实际 [?]）
    == 结果 ==  ✓ 8  ✗ 10  SKIP 0
  ✓ F-W1/F-W2 还原：两处改动都撤销 → model-window 段重新绿（rc=0）
== 结果 ==  ✓ 24  ✗ 0  SKIP 0
```

两处变异都是在 scratch 树（`cp -a` 的脚本副本）里用 python 打的，真树不动；变异打中与还原都有断言
（`P126 F-W1` / `P126 F-W2` 标记 + 还原后重跑绿）。

### 3.3 绿侧断言清单（`logs/model-window-focus.log` 上半）

- `窗口[闭集]`：基名 272000；`off/minimal/low/medium/high/xhigh/max` 七个后缀逐个 = 272000；
- `窗口[原样]`：`openai/gpt-6-sol-pro:batch` = 456789（不是基名 111111）、`gpt-6-sol-pro` = 111111；
- `窗口[反例]`：`gpt-6-sol:batch`（基名在目录里）→ 空、`gpt-6-sol-pro:other` → 空（不回落基名）；
- `窗口[覆盖]`：`x/y=123` + `x/y:high` → 123；`…:high=888` 赢过 `…=999`；`…gpt-6-sol=999` + `:xhigh` → 999；
  `…gpt-6-sol:batch=777` 原样命中；`…gpt-6-sol=999` + `:batch` → 空；
- `窗口[ps 集成]`：`config set TEAM_DEFAULT_MODEL openai-codex/gpt-6-sol:high` 后 `team ps` 的 WINDOW 列 = `272k`
  （证明工具链真的用上了这个解析，不是只有单测）。

## 4. 门禁

| 命令 | 结果 |
|---|---|
| `bash skills/teamsmith/tests/config-cli.sh`（全部段，交付 tip 上重跑） | ✅ `== 结果 ==  ✓ 335  ✗ 0  SKIP 0`，rc=0（`logs/config-cli-tip.log`） |
| `~/.bun/bin/openspec validate --all --strict` | ✅ `Totals: 14 passed, 0 failed (14 items)` |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`（第二次尝试） | ✅ `== 结果 ==  ✓ 3091  ✗ 0`（§4.2） |
| `bash skills/teamsmith/tests/smoke.sh`（全量） | 第一次 1 红（§4.3：routes.sh 自己的跨 run 误判，已最小复现）→ 重跑 ✅ `== 结果 ==  ✓ 3757  ✗ 0`，rc=0 |

### 4.1 第一次 FAST 尝试被 section-guard 判超时（环境，不是本任务的代码）

第一次 FAST 在段落 `#76（id: 25 · 唤醒计数 = digest 的可行动列表 M9.8）`被 liveness 看门狗停跑：
`预算 60s、实际 70s`，当时机器 `loadavg=21.04`（场景文件里的 `machine:` 行）。同机的旁证：场景的 ps 快照里
能看见 dev3 的门禁批（`TEAM_SMOKE_FAST=1 … smoke.sh`，已跑 9 分钟）；verify 的全量 smoke 自 07:16 起一直在跑，
07:44 的 `ps` 复查仍在（§4.3 里 §51 的归因也要用到它）。
场景证据（`/tmp/.teamsmith-smoke-scene.50587/`）已复制进报告包：

- `logs/fast-attempt1-guard-scene-summary.txt`（section/budget/elapsed/loadavg/进程树/ps 快照）
- `logs/fast-attempt1-sections.tsv.partial`（停在第 75 条收口行，§33 还没跑到）

这是看门狗按设计「停跑 exit 2」（不是断言红），且停的段落与本任务无关；等机器安静后重跑见 §4.2。

### 4.2 FAST 重跑（安静窗口）

命令与原始输出（`logs/fast-gate-rerun.log`）：

```console
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null; echo "FAST rc=$?"
...
  ✓ 33 config-cli.sh 全绿（351 条断言）
...
账本自查： 114 段收口 · 增量 ✓3091 ✗0 SKIP34 ｜ 结果行 ✓3091 ✗0 —— 一致
== 结果 ==  ✓ 3091  ✗ 0
FAST rc=0
```

§33 那一段跑的就是**全部** config-cli 段（不带参数），所以本任务新增的 `model-window` /
`flip-model-window` 两个段包含在 351 条断言里。

### 4.3 全量门禁

**第一次全量**（08:31–08:59，`logs/full-gate.log`）：`✓ 3756 ✗ 1`，唯一一条红是

```
  ✗ 51 routes.sh 有失败（rc=1）——用法行/注释承诺与真实解析器不一致
```

**归因：这是 routes.sh 自己的跨 run 误判，与本次 diff 无交集。** 最小复现（两臂；外来根只种在**私有
TMPDIR** 里，不碰共享 `/tmp`）：

| 臂 | 命令 | 结果 |
|---|---|---|
| 控制臂 | `cd <私有 cwd> && TMPDIR=<私有> bash skills/teamsmith/tests/routes.sh`（无外来根） | ✅ `== 结果 ==  ✓ 171  ✗ 0`，rc=0（`logs/routes-standalone-control.log`） |
| 复现臂 | 同上，运行中途在 `$TMPDIR` 放一个 `teamsmith-routes.concur-other-run`（mtime 更新） | ❌ `✗ 翻转收尾：留下 1 个嵌套临时根：/tmp/p126-scan-probe3/teamsmith-routes.concur-other-run` → `✓ 170 ✗ 1`，rc=1（`logs/routes-cross-run-repro.log`） |
| 套件上下文控制臂 | `TMPDIR=<私有> TEAM_SMOKE_NO_LOCK=1 bash smoke.sh --select 51`（**不带** `--keep`） | ✅ `✓ 51 routes.sh 全绿（172 条断言，1 条可见跳过）`，rc=0（`logs/scanprobe2-control.log`） |
| 同类复现（套件上下文） | 同上 + 预先放好外来 `teamsmith-routes.*` | ❌ `✗ 51 routes.sh 有失败（rc=1）`（`logs/scanprobe2-fake.log`，与第一次全量的红同一行） |

机制：flips 段收尾断言 `mr_nested_leftovers`（`skills/teamsmith/tests/routes.sh:746`）的第二个分支是
`find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'teamsmith-routes.*' -newer "$tmp"` —— **没有 run/owner 过滤**，
于是**任何**名字叫 `teamsmith-routes.*`、又比本夹具自己的根更新的目录（别的 run 的嵌套 run，或别人
`--keep` / 失败跑留下的根）都会被算成本套的泄漏 → 假红。

第一次全量那条红的来源只能归到“外来根”，归不到本套：本套自己的嵌套 run 由 ①②③④⑤⑥⑦/⑧ 各自断言把守
（前七条在 smoke 摘录里都是 ✓），而失败现场（`routes.log`）连同 `--keep` 的临时根在几分钟内被同机清扫带走。
时间窗里确实活着另一套全量（verify 的，07:16 起，08:47 的 `ps` 里仍在，09:08 已消失；本套 08:59 结束，
dev 的全量 08:59:48 才拿到锁，不重叠），但也可能只是某个 `--keep` 跑早就留下的孤根 —— 两种形状由上面的
复现臂与套件上下文臂分别表出，都指向同一条无过滤的扫描。

这是**夹具隔离缺陷**（`routes.sh`，不在本任务 brief 的范围，未改；本任务只动 `common.sh` 与
`config-cli.sh` 的测试段）。建议 PM 另开一个任务把它按 owner/run id 过滤（或像翻转⑧那样把嵌套 run 的根
放进私有 TMPDIR）。

**重跑**（安静窗口 09:26:08 起，结束时立即把现场拷进报告包）——`logs/full-gate-rerun.log`：

```console
$ bash skills/teamsmith/tests/smoke.sh </dev/null; echo "full rc=$?"
...
  ✓ 51 routes.sh 全绿（172 条断言，1 条可见跳过）
账本自查： 113 段收口 · 增量 ✓3757 ✗0 SKIP0 ｜ 结果行 ✓3757 ✗0 —— 一致
== 结果 ==  ✓ 3757  ✗ 0
full rc=0
```

这一次 §51 全绿（172 条断言），与上面的归因一致：窗口里没有外来的 `teamsmith-routes.*`。

## 5. 说明与一个待 PM 知悉的口径（不是 BLOCKED）

1. **闭集含 `off`**：brief 括注六个，P102/`delivery-guard` 记的是七个（§2）。我按「P102 定下的那些档」
   实现了七个并逐个断言。若你要的恰好是六个（`off` 不砍），把 `_TEAM_MODEL_THINKING_TIERS` 里的 `off`
   删掉、夹具删一条断言即可 —— 一行改动，请回头说一声。
2. **非闭集后缀解析不到时返回空**（不回落基名），保持「不知道就不猜」的既有契约：调用方退回保守阈值
   （`TEAM_SESSION_WARN_TOKENS`）。`gpt-6-sol:batch` 与基名同时在目录里时，`:batch` 若目录里没有就是空，
   不会拿基名的窗口冒充 —— §3.3 的 `[反例]` 条钉住这一行为。
3. 没改 `team_model_window_from_pi` 的目录解析宽容度、没加缓存；`TEAM_MODEL_WINDOWS` 的语法与优先级
   （显式覆盖 > Pi 目录）保持不变。
